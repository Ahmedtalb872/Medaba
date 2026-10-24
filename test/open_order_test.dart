import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/open_order.dart';
import 'package:medaba/state/app_state.dart';

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
}
