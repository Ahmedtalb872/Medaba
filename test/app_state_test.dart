import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/debt.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  late AppState s;
  final d = DateTime(2026, 3, 10);

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
  });

  Future<void> tx(TxCategory c, double amount, {String? person}) =>
      s.saveTransaction(
        Transaction(
          id: newId(),
          category: c,
          amount: amount,
          date: d,
          personId: person,
        ),
      );

  test('net profit is split between partners by share', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 60, joinedAt: d),
    );
    await s.savePartner(
      Partner(id: 'b', name: 'B', sharePercent: 40, joinedAt: d),
    );
    await tx(TxCategory.sales, 10000);
    await tx(TxCategory.rent, 2000);
    // المسحوبات لا تؤثر على الربح.
    await tx(TxCategory.withdrawal, 500, person: 'a');

    final r = s.profitReport(Period.month(d));
    expect(r.netProfit, 8000);
    expect(r.partners.firstWhere((p) => p.id == 'a').amount, 4800);
    expect(r.partners.firstWhere((p) => p.id == 'a').balance, 4300);
    expect(r.partners.firstWhere((p) => p.id == 'b').amount, 3200);
  });

  test('partners carry a loss by share', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 100, joinedAt: d),
    );
    await tx(TxCategory.sales, 1000);
    await tx(TxCategory.rent, 3000);

    expect(s.profitReport(Period.month(d)).partners.single.amount, -2000);
  });

  test('period filter excludes other months', () async {
    await tx(TxCategory.sales, 100);
    expect(s.totalIncome(Period.month(DateTime(2026, 4))), 0);
    expect(s.totalIncome(Period.month(d)), 100);
  });

  test('data persists through storage', () async {
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.load();
    await a.saveWorker(
      Worker(id: 'w', name: 'W', monthlySalary: 3000, hiredAt: d),
    );
    await a.paySalary(a.workers.single, d);

    final b = AppState(storage);
    await b.load();
    expect(b.workers.single.name, 'W');
    expect(b.totalExpenses(), 3000);
    expect(b.personName(b.transactions.single.personId), 'W');
  });

  test('partner share total excludes edited partner', () async {
    await s.savePartner(
      Partner(id: 'a', name: 'A', sharePercent: 70, joinedAt: d),
    );
    expect(s.partnersShareTotal(), 70);
    expect(s.partnersShareTotal(excludeId: 'a'), 0);
  });

  group('inventory', () {
    const w1 = Warehouse(id: 'w1', name: 'Main');
    const w2 = Warehouse(id: 'w2', name: 'Branch');
    const p = Product(
      id: 'p',
      name: 'Cement',
      costPrice: 10,
      salePrice: 15,
      minQty: 20,
    );

    StockMove move(
      MoveType type,
      double qty, {
      String id = '',
      String wh = 'w1',
      String? to,
      double price = 0,
    }) => StockMove(
      id: id.isEmpty ? newId() : id,
      type: type,
      productId: 'p',
      warehouseId: wh,
      toWarehouseId: to,
      qty: qty,
      unitPrice: price,
      date: d,
    );

    setUp(() async {
      await s.saveWarehouse(w1);
      await s.saveWarehouse(w2);
      await s.saveProduct(p);
    });

    test('stock per warehouse follows in, out and transfer', () async {
      await s.saveMove(move(MoveType.stockIn, 100));
      await s.saveMove(move(MoveType.transfer, 30, to: 'w2'));
      await s.saveMove(move(MoveType.stockOut, 5, wh: 'w2'));

      expect(s.stockOf('p', warehouseId: 'w1'), 70);
      expect(s.stockOf('p', warehouseId: 'w2'), 25);
      expect(s.stockOf('p'), 95);
      expect(s.stockValue(), 950);
    });

    test('original quantity, issued and available', () async {
      await s.saveMove(move(MoveType.stockIn, 100));
      await s.saveMove(move(MoveType.transfer, 30, to: 'w2'));
      await s.saveMove(move(MoveType.stockOut, 5, wh: 'w2'));

      // المخزن الأول: دخل 100 وخرج 30 بالتحويل.
      final a = s.stockFlow('p', warehouseId: 'w1');
      expect((a.received, a.issued), (100, 30));
      // المخزن الثاني: دخله 30 بالتحويل وخرج 5.
      final b = s.stockFlow('p', warehouseId: 'w2');
      expect((b.received, b.issued), (30, 5));
      // كل المخازن: التحويل الداخلي لا يُحسب.
      final all = s.stockFlow('p');
      expect((all.received, all.issued), (100, 5));
      expect(all.received - all.issued, s.stockOf('p'));
    });

    test('purchase and sale create linked transactions', () async {
      await s.saveMove(move(MoveType.purchase, 10, id: 'm1', price: 10));
      await s.saveMove(move(MoveType.sale, 4, id: 'm2', price: 15));

      expect(s.totalExpenses(), 100);
      expect(s.totalIncome(), 60);
      final saleTx = s.transactions.firstWhere(
        (t) => t.category == TxCategory.sales,
      );
      expect(s.isLinkedTransaction(saleTx.id), isTrue);

      // تعديل الكمية يحدّث المبلغ، والحذف يحذف المعاملة.
      await s.saveMove(
        move(MoveType.sale, 2, id: 'm2', price: 15).copyWith(txId: saleTx.id),
      );
      expect(s.totalIncome(), 30);
      expect(s.transactions.length, 2);
      await s.deleteMove('m2');
      expect(s.totalIncome(), 0);
      expect(s.transactions.length, 1);
    });

    test('cannot issue more than available', () async {
      await s.saveMove(move(MoveType.stockIn, 10, id: 'in'));
      expect(
        () => s.saveMove(move(MoveType.sale, 11, price: 15)),
        throwsStateError,
      );
      expect(
        () => s.saveMove(move(MoveType.transfer, 1, wh: 'w2', to: 'w1')),
        throwsStateError,
      );
      // تعديل حركة صادرة لا يحسبها مرتين.
      await s.saveMove(move(MoveType.stockOut, 10, id: 'out'));
      await s.saveMove(move(MoveType.stockOut, 10, id: 'out'));
      expect(s.stockOf('p'), 0);
    });

    test('low stock and delete guards', () async {
      await s.saveMove(move(MoveType.stockIn, 20));
      expect(s.lowStockProducts.single.id, 'p');
      expect(await s.deleteWarehouse('w1'), isFalse);
      expect(await s.deleteWarehouse('w2'), isTrue);
    });

    test('deleting a product removes its manual moves', () async {
      await s.saveMove(move(MoveType.purchase, 5, price: 10));
      await s.saveMove(move(MoveType.stockIn, 3));
      expect(s.manualMovesOf('p'), 2);
      expect(s.transactions, hasLength(1));
      expect(s.invoicesUsingProduct('p'), isEmpty);
      expect(await s.deleteProduct('p'), isTrue);
      expect(s.products, isEmpty);
      expect(s.moves, isEmpty);
      expect(s.transactions, isEmpty);
    });
  });

  test('a product used in invoices cannot be deleted', () async {
    await s.seedDemoData();
    final used = s.products.firstWhere(
      (p) => s.invoicesUsingProduct(p.id).isNotEmpty,
    );
    expect(await s.deleteProduct(used.id), isFalse);
    expect(s.products.any((p) => p.id == used.id), isTrue);

    final invoices = s.invoicesUsingProduct(used.id);
    expect(await s.deleteProduct(used.id, withInvoices: true), isTrue);
    expect(s.products.any((p) => p.id == used.id), isFalse);
    expect(s.invoices.where((i) => invoices.contains(i.number)), isEmpty);
    expect(s.moves.any((m) => m.productId == used.id), isFalse);
  });

  test('removing demo data keeps the real records', () async {
    await s.seedDemoData();
    final wh = s.warehouses.first.id;
    await s.saveProduct(const Product(id: 'real', name: '0.66 غ'));
    await s.saveMove(
      StockMove(
        id: 'rm',
        type: MoveType.stockIn,
        productId: 'real',
        warehouseId: wh,
        qty: 10,
        date: DateTime(2026),
      ),
    );
    expect(await s.removeDemoData(), greaterThan(0));
    expect(s.products.map((p) => p.id), ['real']);
    expect(s.moves.map((m) => m.id), ['rm']);
    expect(s.invoices, isEmpty);
    expect(s.partners, isEmpty);
    expect(s.workers, isEmpty);
    expect(s.transactions, isEmpty);
    expect(s.debts, isEmpty);
    expect(s.cars, isEmpty);
    expect(s.plots, isEmpty);
    expect(s.shipments, isEmpty);
    expect(s.warehouses.map((w) => w.id), [wh]);
    expect(await s.removeDemoData(), 0);
  });

  test('the four default warehouses are added once', () async {
    await s.saveWarehouse(const Warehouse(id: 'x', name: 'مخزن 2'));
    await s.ensureDefaultWarehouses();
    expect(s.warehouses.map((w) => w.name).toSet(), {
      'مخزن 1',
      'مخزن 2',
      'مخزن 3',
      'مخزن 4',
    });
    expect(s.company.warehousesSet, isTrue);
    await s.deleteWarehouse(s.warehouses.firstWhere((w) => w.id != 'x').id);
    await s.ensureDefaultWarehouses();
    expect(s.warehouses, hasLength(3));
  });

  test('the goods list is added once without duplicates', () async {
    await s.saveProduct(const Product(id: 'x', name: '0.66غ'));
    await s.ensureDefaultProducts();
    expect(s.products, hasLength(AppState.defaultProducts.length));
    expect(s.company.productsSet, isTrue);
    await s.ensureDefaultProducts();
    expect(s.products, hasLength(AppState.defaultProducts.length));
  });

  test('profit is sale minus the purchase price at the time of sale', () async {
    await s.saveWarehouse(const Warehouse(id: 'w', name: 'مخزن 1'));
    await s.saveProduct(
      const Product(id: 'p', name: '0.66 غ', costPrice: 100, salePrice: 130),
    );
    await s.saveMove(
      StockMove(
        id: 'in',
        type: MoveType.stockIn,
        productId: 'p',
        warehouseId: 'w',
        qty: 50,
        date: DateTime(2026, 10, 1),
      ),
    );
    await s.saveInvoice(
      Invoice(
        id: 'i',
        type: InvoiceType.sale,
        number: 'S-0001',
        date: DateTime(2026, 10, 14),
        partyName: 'سيدي',
        warehouseId: 'w',
        lines: const [InvoiceLine(productId: 'p', qty: 10, unitPrice: 130)],
        debt: 500,
      ),
    );
    var e = s.profitEntries().single;
    expect(e.sale, 1300);
    expect(e.cost, 1000);
    expect(e.missingCost, isFalse);

    // تغيير سعر الشراء لاحقاً لا يغيّر ربح فاتورة قديمة.
    await s.saveProduct(
      const Product(id: 'p', name: '0.66 غ', costPrice: 120, salePrice: 130),
    );
    e = s.profitEntries().single;
    expect(e.cost, 1000);
    expect(s.profitEntries(Period.month(DateTime(2026, 9))), isEmpty);

    final events = s.debtEvents();
    expect(events.single.debt.personName, 'سيدي');
    expect(events.single.payment, isNull);
    expect(s.debtsRemaining(DebtDirection.theyOwe), 500);
  });

  test('each warehouse has its own capital, profit and rent', () async {
    await s.saveWarehouse(
      const Warehouse(
        id: 'w1',
        name: 'مخزن 1',
        capital: 50000,
        monthlyRent: 8000,
      ),
    );
    await s.saveWarehouse(const Warehouse(id: 'w2', name: 'مخزن 2'));
    await s.saveProduct(
      const Product(id: 'p', name: '0.66 غ', costPrice: 100, salePrice: 150),
    );
    for (final w in ['w1', 'w2']) {
      await s.saveMove(
        StockMove(
          id: 'in$w',
          type: MoveType.stockIn,
          productId: 'p',
          warehouseId: w,
          qty: 100,
          date: DateTime(2026, 10, 1),
        ),
      );
    }
    await s.saveInvoice(
      Invoice(
        id: 'i',
        type: InvoiceType.sale,
        number: 'S-0001',
        date: DateTime(2026, 10, 10),
        warehouseId: 'w1',
        lines: const [InvoiceLine(productId: 'p', qty: 20, unitPrice: 150)],
      ),
    );
    final oct = Period.month(DateTime(2026, 10));
    expect(s.stockValue(warehouseId: 'w1'), 8000);
    expect(s.warehouseProfit('w1', oct), 1000);
    expect(s.warehouseProfit('w2', oct), 0);

    final w1 = s.warehouseById('w1')!;
    await s.payWarehouseRent(w1, 8000, DateTime(2026, 10, 5));
    expect(s.rentPaid('w1', oct), 8000);
    expect(s.rentPaid('w2', oct), 0);
    expect(s.transactions.any((t) => t.note == 'إيجار مخزن 1'), isTrue);
    expect(Warehouse.fromJson(w1.toJson()).capital, 50000);

    // شريك في المخزن: نسبته من ربح مبيعات هذا المخزن.
    final partner = Partner(
      id: 'pw',
      name: 'سالم',
      sharePercent: 40,
      capital: 20000,
      joinedAt: DateTime(2026, 10),
      scope: PartnerScope.warehouse,
      dealId: 'w1',
    );
    await s.savePartner(partner);
    expect(s.investorsIn(PartnerScope.warehouse, 'w1').single.id, 'pw');
    expect(s.dealLabel(partner), 'مخزن: مخزن 1');
    expect(s.dealShareOf(partner), 400);
    expect(s.partnersShareTotal(), 0);
  });

  test('demo data seeds without errors', () async {
    await s.seedDemoData();
    expect(s.warehouses, isNotEmpty);
    expect(s.lowStockProducts, isNotEmpty);
    for (final p in s.products) {
      for (final w in s.warehouses) {
        expect(s.stockOf(p.id, warehouseId: w.id), greaterThanOrEqualTo(0));
      }
    }
  });
}
