import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/debt.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/open_order.dart';
import 'package:medaba/pdf/open_order_pdf.dart';
import 'package:medaba/screens/open_orders.dart';
import 'package:medaba/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  late AppState s;
  final day = DateTime(2026, 10, 16);

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
    await s.saveWarehouse(const Warehouse(id: 'w', name: 'مخزن 1'));
    await s.saveProduct(
      const Product(id: 'p', name: '0.66 غ', costPrice: 100, salePrice: 150),
    );
    await s.saveMove(
      StockMove(
        id: 'in',
        type: MoveType.stockIn,
        productId: 'p',
        warehouseId: 'w',
        qty: 1200,
        date: day,
      ),
    );
  });

  OpenOrder order({double qty = 1000}) => OpenOrder(
    id: 'o',
    number: s.nextOrderNumber(),
    date: day,
    partyName: 'سيدي',
    warehouseId: 'w',
    lines: [InvoiceLine(productId: 'p', qty: qty, unitPrice: 140)],
  );

  test(
    'a customer takes an open invoice in parts until it is complete',
    () async {
      await s.saveOpenOrder(order());
      expect(s.openOrders.single.number, 'O-0001');
      // البضاعة تبقى في المخزن لكنها محجوزة للزبون.
      expect(s.stockOf('p', warehouseId: 'w'), 1200);
      expect(s.reservedQty('p', warehouseId: 'w'), 1000);

      final first = await s.pickupFromOrder(
        'o',
        quantities: {'p': 200},
        paid: 28000,
        date: day,
      );
      expect(first.total, 28000);
      expect(first.openOrderId, 'o');
      expect(s.stockOf('p', warehouseId: 'w'), 1000);
      expect(s.remainingInOrder(s.orderById('o')!, 'p'), 800);
      expect(s.reservedQty('p', warehouseId: 'w'), 800);

      // دفع جزئي: الباقي يصبح ديناً على الزبون.
      final second = await s.pickupFromOrder(
        'o',
        quantities: {'p': 100},
        paid: 10000,
        date: day,
      );
      expect(s.debtForInvoice(second.id)!.remaining, 4000);
      expect(s.orderPaid(s.orderById('o')!), 38000);
      expect(s.orderTakenValue(s.orderById('o')!), 42000);

      // لا يأخذ أكثر من الباقي له.
      expect(
        () => s.pickupFromOrder('o', quantities: {'p': 701}, paid: 0),
        throwsStateError,
      );
      await s.pickupFromOrder('o', quantities: {'p': 700}, paid: 98000);
      expect(s.isOrderComplete(s.orderById('o')!), isTrue);
      expect(s.reservedQty('p', warehouseId: 'w'), 0);
      expect(await s.deleteOpenOrder('o'), isFalse);
    },
  );

  test('reserved goods are not sold to other customers', () async {
    await s.saveOpenOrder(order());
    // في المخزن 1200، منها 1000 محجوزة: يمكن بيع 200 فقط لغيره.
    Invoice sale(double qty) => Invoice(
      id: 'x',
      type: InvoiceType.sale,
      number: 'S-0009',
      date: day,
      warehouseId: 'w',
      lines: [InvoiceLine(productId: 'p', qty: qty, unitPrice: 150)],
    );
    expect(() => s.saveInvoice(sale(201)), throwsStateError);
    await s.saveInvoice(sale(200));
    // ولا تُحجز كمية غير متوفرة.
    expect(
      () => s.saveOpenOrder(
        OpenOrder(
          id: 'o2',
          number: 'O-0002',
          date: day,
          partyName: 'آخر',
          warehouseId: 'w',
          lines: const [InvoiceLine(productId: 'p', qty: 1, unitPrice: 140)],
        ),
      ),
      throwsStateError,
    );
  });

  test('the quantity cannot drop below what was taken', () async {
    await s.saveOpenOrder(order());
    await s.pickupFromOrder('o', quantities: {'p': 300}, paid: 42000);
    expect(() => s.saveOpenOrder(order(qty: 299)), throwsStateError);
    await s.saveOpenOrder(order(qty: 300));
    expect(s.isOrderComplete(s.orderById('o')!), isTrue);
    expect(OpenOrder.fromJson(s.orderById('o')!.toJson()).totalQty, 300);
  });

  testWidgets('an open invoice is created and a part is taken from the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('فاتورة مفتوحة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الزبون'),
      'سيدي',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية'),
      '1000',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final o = s.openOrders.single;
    expect(o.totalQty, 1000);
    expect(find.textContaining('O-0001 • سيدي'), findsOneWidget);

    await tester.tap(find.text('أخذ دفعة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية المأخوذة: 0.66 غ'),
      '200',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(s.pickupsOf(o.id), hasLength(1));
    expect(s.remainingInOrder(o, 'p'), 800);
    expect(s.debtForInvoice(s.pickupsOf(o.id).single.id), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the open invoice page lists every payment and every pickup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveOpenOrder(order());
    // أخذ 200 ودفع ثمنها كاملاً، ثم أخذ 300 ودفع نصفها وسدّد الباقي لاحقاً.
    await s.pickupFromOrder(
      'o',
      quantities: {'p': 200},
      paid: 28000,
      date: day,
    );
    final second = await s.pickupFromOrder(
      'o',
      quantities: {'p': 300},
      paid: 20000,
      date: day.add(const Duration(days: 2)),
    );
    await s.addDebtPayment(
      s.debtForInvoice(second.id)!.id,
      DebtPayment(amount: 22000, date: day.add(const Duration(days: 5))),
    );

    final pays = s.orderPayments(s.orderById('o')!);
    expect(pays.map((p) => p.amount), [28000, 20000, 22000]);
    expect(s.orderPaid(s.orderById('o')!), 70000);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: s,
          child: const OpenOrderPage(orderId: 'o'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('المبلغ الكلي'), findsOneWidget);
    expect(find.text('الكمية الكلية'), findsOneWidget);
    expect(find.text('سجل الدفع'), findsOneWidget);
    expect(find.textContaining('المدفوع حتى الآن 70,000'), findsOneWidget);
    expect(
      find.textContaining('أخذ 200 قطعة من 1,000 ← بقي 800'),
      findsOneWidget,
    );
    expect(
      find.textContaining('أخذ 300 قطعة من 1,000 ← بقي 500'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('an advance payment is used up by later pickups', () async {
    await s.saveOpenOrder(order()); // 1000 × 140 = 140000
    await s.addOrderAdvance('o', amount: 50000, date: day);
    var o = s.orderById('o')!;
    expect(s.orderPaid(o), 50000);
    expect(s.orderCredit('o'), 50000);
    // المبلغ المقدم دخل الحسابات يوم دُفع.
    expect(s.transactions.where((t) => t.refId == 'o').single.amount, 50000);

    // أخذ 200 (28000): تُخصم كلها من المقدم، ولا يدفع شيئاً.
    final a = await s.pickupFromOrder('o', quantities: {'p': 200}, paid: 0);
    expect(a.prepaid, 28000);
    expect(s.debtForInvoice(a.id), isNull);
    expect(s.transactions.firstWhere((t) => t.id == a.txId).amount, 0);
    expect(s.orderCredit('o'), 22000);

    // أخذ 300 (42000): 22000 من المقدم، دفع 10000، والباقي 10000 دين.
    final b = await s.pickupFromOrder('o', quantities: {'p': 300}, paid: 10000);
    expect(b.prepaid, 22000);
    expect(s.debtForInvoice(b.id)!.amount, 10000);
    expect(s.orderCredit('o'), 0);
    o = s.orderById('o')!;
    expect(s.orderPaid(o), 60000);
    expect(s.orderPayments(o).map((p) => p.amount), [50000, 10000]);

    // المقدم المستعمل لا يُحذف، ولا الفاتورة المفتوحة.
    final adv = s.orderAdvances('o').single;
    expect(() => s.deleteOrderAdvance('o', adv.id), throwsStateError);
    expect(await s.deleteOpenOrder('o'), isFalse);
    // ولا يُدفع أكثر من الباقي من المبلغ.
    expect(
      () => s.addOrderAdvance('o', amount: 90000, date: day),
      throwsStateError,
    );
  });

  testWidgets('a payment is recorded from the open invoice page on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveOpenOrder(order());

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: s,
          child: const OpenOrderPage(orderId: 'o'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.text('تسجيل دفعة مالية');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المدفوع'),
      '30000',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(s.orderCredit('o'), 30000);
    expect(find.textContaining('رصيد مدفوع مقدماً'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open invoice row has open and edit buttons', (tester) async {
    tester.view.physicalSize = const Size(1180, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveOpenOrder(order());

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('تعديل').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('تعديل الفاتورة المفتوحة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الفاتورة'));
    await tester.pumpAndSettle();
    expect(find.text('سجل الدفع'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second open invoice is created and both are listed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // الأولى تحجز 1000 من 1200، وأخذ الزبون منها 1000 فاكتملت.
    await s.saveOpenOrder(order());
    await s.pickupFromOrder('o', quantities: {'p': 1000}, paid: 140000);

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('فاتورة مفتوحة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الزبون'),
      'كريس',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '500');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    // المتوفر 200 فقط: يبقى النموذج مفتوحاً ويظهر السبب.
    expect(find.text('المتوفر 200 فقط'), findsOneWidget);
    expect(s.openOrders, hasLength(1));

    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '150');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(s.openOrders, hasLength(2));
    expect(find.textContaining('O-0002 • كريس'), findsOneWidget);
    expect(find.textContaining('O-0001 • سيدي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('an open invoice across several warehouses', () {
    setUp(() async {
      await s.saveWarehouse(const Warehouse(id: 'w2', name: 'مخزن 2'));
      await s.saveMove(
        StockMove(
          id: 'in2',
          type: MoveType.stockIn,
          productId: 'p',
          warehouseId: 'w2',
          qty: 500,
          date: day,
        ),
      );
    });

    OpenOrder split() => OpenOrder(
      id: 'o',
      number: s.nextOrderNumber(),
      date: day,
      partyName: 'كريس',
      warehouseId: 'w',
      lines: const [
        InvoiceLine(productId: 'p', qty: 1000, unitPrice: 140),
        InvoiceLine(
          productId: 'p',
          qty: 400,
          unitPrice: 140,
          warehouseId: 'w2',
        ),
      ],
    );

    test('each warehouse reserves its part and pickups use it', () async {
      await s.saveOpenOrder(split());
      var o = s.orderById('o')!;
      expect(o.warehouseIds, ['w', 'w2']);
      expect(o.qtyOf('p'), 1400);
      expect(s.reservedQty('p', warehouseId: 'w'), 1000);
      expect(s.reservedQty('p', warehouseId: 'w2'), 400);

      final a = await s.pickupFromOrder(
        'o',
        quantities: {'p': 300},
        paid: 42000,
        warehouseId: 'w2',
      );
      expect(a.warehouseId, 'w2');
      expect(s.stockOf('p', warehouseId: 'w2'), 200);
      expect(s.remainingInOrder(o, 'p', at: 'w2'), 100);
      expect(s.remainingInOrder(o, 'p', at: 'w'), 1000);
      expect(s.remainingInOrder(o, 'p'), 1100);
      expect(s.reservedQty('p', warehouseId: 'w2'), 100);

      // لا يأخذ من مخزن أكثر من الباقي له فيه.
      expect(
        () => s.pickupFromOrder(
          'o',
          quantities: {'p': 200},
          paid: 0,
          warehouseId: 'w2',
        ),
        throwsStateError,
      );
      // ولا من مخزن ليس في الفاتورة.
      await s.saveWarehouse(const Warehouse(id: 'w3', name: 'مخزن 3'));
      expect(
        () => s.pickupFromOrder(
          'o',
          quantities: {'p': 1},
          paid: 0,
          warehouseId: 'w3',
        ),
        throwsStateError,
      );

      await s.pickupFromOrder(
        'o',
        quantities: {'p': 100},
        paid: 14000,
        warehouseId: 'w2',
      );
      await s.pickupFromOrder(
        'o',
        quantities: {'p': 1000},
        paid: 140000,
        warehouseId: 'w',
      );
      o = s.orderById('o')!;
      expect(s.isOrderComplete(o), isTrue);
      expect(OpenOrder.fromJson(o.toJson()).warehouseIds, ['w', 'w2']);
    });

    test('a warehouse taken from cannot be dropped from the order', () async {
      await s.saveOpenOrder(split());
      await s.pickupFromOrder(
        'o',
        quantities: {'p': 50},
        paid: 7000,
        warehouseId: 'w2',
      );
      final moved = OpenOrder(
        id: 'o',
        number: 'O-0001',
        date: day,
        partyName: 'كريس',
        warehouseId: 'w',
        lines: const [InvoiceLine(productId: 'p', qty: 1100, unitPrice: 140)],
      );
      expect(() => s.saveOpenOrder(moved), throwsStateError);
      // ولا تتجاوز الكمية المتوفر في مخزنها.
      final tooMuch = OpenOrder(
        id: 'o2',
        number: 'O-0002',
        date: day,
        partyName: 'أحمد',
        warehouseId: 'w2',
        lines: const [
          InvoiceLine(
            productId: 'p',
            qty: 200,
            unitPrice: 140,
            warehouseId: 'w2',
          ),
        ],
      );
      expect(() => s.saveOpenOrder(tooMuch), throwsStateError);
    });
  });

  testWidgets('tapping paid and taken opens their daily reports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveOpenOrder(order());
    await s.addOrderAdvance('o', amount: 30000, date: day);
    await s.pickupFromOrder('o', quantities: {'p': 200}, paid: 0, date: day);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: s,
          child: const OpenOrderPage(orderId: 'o'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المدفوع'));
    await tester.pumpAndSettle();
    expect(find.text('كل المدفوع'), findsOneWidget);
    expect(find.textContaining('دفعة مقدمة O-0001'), findsOneWidget);
    expect(find.textContaining('المدفوع حتى الآن 30,000'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المأخوذ'));
    await tester.pumpAndSettle();
    expect(find.text('كل المأخوذ'), findsOneWidget);
    expect(find.textContaining('أخذ 200'), findsWidgets);
    expect(find.textContaining('← بقي 800'), findsOneWidget);
    // تصفية: اليوم لا يحوي شيئاً (تاريخ الأخذ قديم).
    await tester.tap(find.text('اليوم'));
    await tester.pumpAndSettle();
    expect(find.text('لم يأخذ الزبون شيئاً في هذه الفترة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the open invoice PDF builds with several warehouses', () async {
    await s.saveWarehouse(const Warehouse(id: 'w2', name: 'مخزن 2'));
    await s.saveMove(
      StockMove(
        id: 'in2',
        type: MoveType.stockIn,
        productId: 'p',
        warehouseId: 'w2',
        qty: 100,
        date: day,
      ),
    );
    await s.saveOpenOrder(
      OpenOrder(
        id: 'o',
        number: 'O-0001',
        date: day,
        partyName: 'كريس',
        warehouseId: 'w',
        lines: const [
          InvoiceLine(productId: 'p', qty: 500, unitPrice: 140),
          InvoiceLine(
            productId: 'p',
            qty: 50,
            unitPrice: 140,
            warehouseId: 'w2',
          ),
        ],
      ),
    );
    await s.pickupFromOrder(
      'o',
      quantities: {'p': 20},
      paid: 2800,
      warehouseId: 'w2',
    );
    for (final manager in [false, true]) {
      final pdf = await buildOpenOrderPdf(
        order: s.orderById('o')!,
        s: s,
        showWarehouses: manager,
        issued: day,
      );
      expect(pdf.length, greaterThan(2000));
    }
    // وصف ما دُفع عنه في نسخة الزبون بلا مخزن.
    expect(
      s
          .orderPayments(s.orderById('o')!, withWarehouse: false)
          .first
          .goods
          .single
          .what,
      '20 قطعة 0.66 غ',
    );
  });

  test('each payment says which goods it paid for', () async {
    await s.saveOpenOrder(order()); // 140 للوحدة
    await s.addOrderAdvance('o', amount: 50000, date: day);
    // 200 = 28000 من المقدم، ثم 300 = 22000 من المقدم و20000 نقداً.
    await s.pickupFromOrder('o', quantities: {'p': 200}, paid: 0);
    await s.pickupFromOrder('o', quantities: {'p': 300}, paid: 20000);
    final pays = s.orderPayments(s.orderById('o')!);
    final first = pays.first.goods.map(paidForText).join('\n');
    expect(first, contains('S-0001 • 200 قطعة 0.66 غ من مخزن 1 • 28,000'));
    expect(first, contains('S-0002 • 300 قطعة'));
    expect(first, isNot(contains('رصيد')));
    expect(pays.last.goods.single.what, '300 قطعة 0.66 غ من مخزن 1');

    // مبلغ مقدم لم يُستعمل بعد.
    await s.addOrderAdvance('o', amount: 10000, date: day);
    expect(
      s
          .orderPayments(s.orderById('o')!)
          .where((p) => p.advanceId != null)
          .last
          .goods
          .map(paidForText)
          .join(),
      contains('رصيد لم يأخذ به بضاعة بعد • 10,000'),
    );
  });
}
