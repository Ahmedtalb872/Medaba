import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/debt.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/pdf/invoice_pdf.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState s;
  final d = DateTime(2026, 3, 10);

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
    await s.saveWarehouse(const Warehouse(id: 'w', name: 'Main'));
    await s.saveProduct(
      const Product(id: 'a', name: 'A', costPrice: 10, salePrice: 20),
    );
    await s.saveProduct(
      const Product(id: 'b', name: 'B', costPrice: 5, salePrice: 8),
    );
    await s.saveMove(
      StockMove(
        id: 'open',
        type: MoveType.stockIn,
        productId: 'a',
        warehouseId: 'w',
        qty: 50,
        date: d,
      ),
    );
  });

  Invoice sale(
    String id,
    List<InvoiceLine> lines, {
    double discount = 0,
    double tax = 0,
    String? txId,
  }) => Invoice(
    id: id,
    type: InvoiceType.sale,
    number: s.invoiceById(id)?.number ?? s.nextInvoiceNumber(InvoiceType.sale),
    date: d,
    partyName: 'Client',
    warehouseId: 'w',
    lines: lines,
    discount: discount,
    taxPercent: tax,
    txId: txId ?? s.invoiceById(id)?.txId,
  );

  test('totals apply discount then tax', () {
    final inv = sale(
      'x',
      const [InvoiceLine(productId: 'a', qty: 10, unitPrice: 20)],
      discount: 100,
      tax: 15,
    );
    expect(inv.subtotal, 200);
    expect(inv.afterDiscount, 100);
    expect(inv.tax, 15);
    expect(inv.total, 115);
  });

  test('sale invoice moves stock and records income', () async {
    await s.saveInvoice(
      sale('i1', const [
        InvoiceLine(productId: 'a', qty: 10, unitPrice: 20),
      ], tax: 15),
    );
    final inv = s.invoiceById('i1')!;
    expect(inv.number, 'S-0001');
    expect(s.stockOf('a'), 40);
    expect(s.totalIncome(), 230);
    expect(s.isLinkedTransaction(inv.txId!), isTrue);
    expect(s.nextInvoiceNumber(InvoiceType.sale), 'S-0002');
    expect(s.nextInvoiceNumber(InvoiceType.purchase), 'P-0001');
  });

  test('editing an invoice replaces its moves and transaction', () async {
    await s.saveInvoice(
      sale('i1', const [InvoiceLine(productId: 'a', qty: 40, unitPrice: 20)]),
    );
    // 50 متاح أصلاً؛ تعديل الفاتورة إلى 50 مسموح لأن كميتها القديمة تُستثنى.
    await s.saveInvoice(
      sale('i1', const [InvoiceLine(productId: 'a', qty: 50, unitPrice: 20)]),
    );
    expect(s.stockOf('a'), 0);
    expect(s.invoices.length, 1);
    expect(s.transactions.length, 1);
    expect(s.totalIncome(), 1000);
  });

  test('rejects overselling and empty invoices', () async {
    expect(
      () => s.saveInvoice(
        sale('i1', const [
          InvoiceLine(productId: 'a', qty: 30, unitPrice: 20),
          InvoiceLine(productId: 'a', qty: 30, unitPrice: 20),
        ]),
      ),
      throwsStateError,
    );
    expect(() => s.saveInvoice(sale('i2', const [])), throwsStateError);
    expect(s.invoices, isEmpty);
    expect(s.stockOf('a'), 50);
  });

  test('purchase invoice adds stock; delete reverses it', () async {
    await s.saveInvoice(
      Invoice(
        id: 'p1',
        type: InvoiceType.purchase,
        number: s.nextInvoiceNumber(InvoiceType.purchase),
        date: d,
        warehouseId: 'w',
        lines: const [InvoiceLine(productId: 'b', qty: 100, unitPrice: 5)],
      ),
    );
    expect(s.stockOf('b'), 100);
    expect(s.totalExpenses(), 500);

    await s.deleteInvoice('p1');
    expect(s.stockOf('b'), 0);
    expect(s.totalExpenses(), 0);
    expect(s.moves.where((m) => m.invoiceId != null), isEmpty);
  });

  test('cannot delete a purchase whose stock was already sold', () async {
    await s.saveInvoice(
      Invoice(
        id: 'p1',
        type: InvoiceType.purchase,
        number: 'P-0001',
        date: d,
        warehouseId: 'w',
        lines: const [InvoiceLine(productId: 'b', qty: 10, unitPrice: 5)],
      ),
    );
    await s.saveInvoice(
      sale('s1', const [InvoiceLine(productId: 'b', qty: 6, unitPrice: 8)]),
    );
    expect(() => s.deleteInvoice('p1'), throwsStateError);
    expect(s.stockOf('b'), 4);
  });

  test('invoice debt creates, updates and removes a linked debt', () async {
    const lines = [InvoiceLine(productId: 'a', qty: 5, unitPrice: 20)];
    Invoice withDebt(double debt) =>
        Invoice.fromJson({...sale('i1', lines).toJson(), 'debt': debt});

    await s.saveInvoice(withDebt(60));
    final d = s.debtForInvoice('i1')!;
    expect(d.amount, 60);
    expect(d.direction, DebtDirection.theyOwe);
    expect(d.personName, 'Client');
    expect(d.note, contains(s.invoiceById('i1')!.number));

    // تعديل الفاتورة يحدّث الدين نفسه ويُبقي تسديداته.
    await s.addDebtPayment(d.id, DebtPayment(amount: 10, date: d.date));
    await s.saveInvoice(withDebt(40));
    final updated = s.debtForInvoice('i1')!;
    expect((updated.id, updated.amount, updated.paid), (d.id, 40, 10));

    // لا يقل الدين عمّا سُدِّد، ولا يزيد عن الإجمالي.
    expect(() => s.saveInvoice(withDebt(5)), throwsStateError);
    expect(() => s.saveInvoice(withDebt(101)), throwsStateError);
    // مبلغه لا يُعدَّل ولا يُحذف من شاشة الديون.
    expect(
      () => s.saveDebt(
        Debt(
          id: d.id,
          direction: d.direction,
          personName: 'X',
          amount: 99,
          date: d.date,
          payments: updated.payments,
          invoiceId: 'i1',
        ),
      ),
      throwsStateError,
    );
    expect(() => s.deleteDebt(d.id), throwsStateError);

    // حذف الفاتورة يحذف دينها.
    await s.deleteInvoice('i1');
    expect(s.debtForInvoice('i1'), isNull);
    expect(s.debts, isEmpty);
  });

  test('paying an invoice in full removes its debt', () async {
    const lines = [InvoiceLine(productId: 'a', qty: 1, unitPrice: 20)];
    await s.saveInvoice(
      Invoice.fromJson({...sale('i2', lines).toJson(), 'debt': 20}),
    );
    expect(s.debtForInvoice('i2'), isNotNull);
    await s.saveInvoice(sale('i2', lines));
    expect(s.debtForInvoice('i2'), isNull);
  });

  test('old demo company data is replaced', () {
    final c = CompanyInfo.fromJson({
      'name': 'مؤسسة مدبّر لمواد البناء',
      'phone': '0500000000',
      'address': 'الرياض - المنطقة الصناعية',
      'taxNumber': '300000000000003',
    });
    expect(c.name, 'طيبة للتجارة العامة');
    expect(c.address, 'انواكشوط - تفرغ زينة');
    expect((c.phone, c.taxNumber), ('', ''));
  });

  test('builds an Arabic invoice PDF', () async {
    await s.saveCompany(const CompanyInfo(name: 'شركة', taxNumber: '123'));
    await s.saveInvoice(
      sale('i1', const [
        InvoiceLine(productId: 'a', qty: 3, unitPrice: 20),
      ], tax: 15),
    );
    final bytes = await buildInvoicePdf(
      invoice: s.invoiceById('i1')!,
      company: s.company,
      productOf: s.productById,
      warehouseName: 'Main',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('company info persists', () async {
    await s.saveCompany(const CompanyInfo(name: 'X', defaultTaxPercent: 15));
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.saveCompany(const CompanyInfo(name: 'Y', phone: '1'));
    final b = AppState(storage);
    await b.load();
    expect(b.company.name, 'Y');
    expect(b.company.phone, '1');
  });

  test('company name and address default to the client', () {
    const fresh = CompanyInfo();
    expect(fresh.name, 'طيبة للتجارة العامة');
    expect(fresh.address, 'انواكشوط - تفرغ زينة');
    // البيانات التجريبية القديمة تأخذ اسم المؤسسة وعنوانها.
    final old = CompanyInfo.fromJson({
      'name': 'مؤسسة مدبّر لمواد البناء',
      'address': 'نواكشوط - تفرغ زينة',
    });
    expect(old.name, CompanyInfo.defaultName);
    expect(old.address, CompanyInfo.defaultAddress);
    // ما يكتبه المستخدم بنفسه يبقى كما هو.
    final own = CompanyInfo.fromJson({'name': 'X', 'address': ''});
    expect((own.name, own.address), ('X', ''));
  });

  test('payment accounts default, persist and can be changed', () async {
    // البيانات المحفوظة قبل إضافة الحسابات تأخذ حسابات المدير.
    final old = CompanyInfo.fromJson({'name': 'Z'});
    expect(old.paymentAccounts.map((a) => '${a.name} ${a.number}'), [
      'Click 36933636',
      'Masrvi 36933636',
      'Sedad 36933636',
      'BPM 10020364',
    ]);

    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.saveCompany(
      const CompanyInfo(
        name: 'Y',
        paymentAccounts: [PaymentAccount('Bankily', '22000000')],
      ),
    );
    final b = AppState(storage);
    await b.load();
    expect(b.company.paymentAccounts.single.name, 'Bankily');
    expect(b.company.paymentAccounts.single.number, '22000000');

    // قائمة فارغة تبقى فارغة (لا تعود الافتراضية).
    await b.saveCompany(const CompanyInfo(name: 'Y', paymentAccounts: []));
    final c = AppState(storage);
    await c.load();
    expect(c.company.paymentAccounts, isEmpty);
  });
}
