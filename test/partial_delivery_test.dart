import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/screens/invoices_screen.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  late AppState s;
  final day = DateTime(2026, 10, 20);

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
        qty: 500,
        date: day,
      ),
    );
  });

  Invoice sale({bool partial = true, List<Delivery> deliveries = const []}) =>
      Invoice(
        id: 'i',
        type: InvoiceType.sale,
        number: 'S-0001',
        date: day,
        partyName: 'سيدي',
        warehouseId: 'w',
        lines: const [InvoiceLine(productId: 'p', qty: 100, unitPrice: 150)],
        partialDelivery: partial,
        deliveries: deliveries,
      );

  Delivery take(String id, double qty, {int dayOffset = 0}) => Delivery(
    id: id,
    date: day.add(Duration(days: dayOffset)),
    items: {'p': qty},
  );

  test('a paid sale is taken in parts with a dated history', () async {
    await s.saveInvoice(sale(deliveries: [take('d1', 30)]));
    var inv = s.invoiceById('i')!;
    expect(inv.qtyOf('p'), 100);
    expect(inv.takenOf('p'), 30);
    expect(inv.leftOf('p'), 70);
    expect(inv.hasLeft, isTrue);
    // البيع يُخصم من المتوفر كله، والمتروك يظهر منفصلاً.
    expect(s.stockOf('p', warehouseId: 'w'), 400);
    expect(s.undeliveredQty('p', warehouseId: 'w'), 70);
    expect(s.invoicesWithLeft, hasLength(1));
    // المبلغ كاملاً في الحسابات.
    expect(s.debtForInvoice('i'), isNull);

    await s.saveInvoice(
      sale(deliveries: [take('d1', 30), take('d2', 70, dayOffset: 3)]),
    );
    inv = s.invoiceById('i')!;
    expect(inv.leftOf('p'), 0);
    expect(inv.hasLeft, isFalse);
    expect(s.undeliveredQty('p'), 0);

    final back = Invoice.fromJson(inv.toJson());
    expect(back.partialDelivery, isTrue);
    expect(back.deliveries.map((d) => d.id), ['d1', 'd2']);
    expect(back.deliveries.last.date, day.add(const Duration(days: 3)));
  });

  test('the quantity cannot drop below what was taken', () async {
    await s.saveInvoice(sale(deliveries: [take('d1', 30)]));
    final smaller = Invoice.fromJson({
      ...sale(deliveries: [take('d1', 30)]).toJson(),
      'lines': [
        const InvoiceLine(productId: 'p', qty: 20, unitPrice: 150).toJson(),
      ],
    });
    expect(() => s.saveInvoice(smaller), throwsStateError);
  });

  test('an ordinary invoice counts everything as taken', () {
    final inv = sale(partial: false);
    expect(inv.takenOf('p'), 100);
    expect(inv.leftOf('p'), 0);
    expect(inv.hasLeft, isFalse);
    expect(inv.toJson().containsKey('partialDelivery'), isFalse);
  });

  testWidgets('a delivery is recorded from the button inside the invoice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveInvoice(sale(partial: false));

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('تعديل').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تعديل').first);
    await tester.pumpAndSettle();

    final button = find.text('الكمية الأصلية / المأخوذ / المتبقي');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('لم يأخذ الزبون شيئاً بعد'), findsOneWidget);

    await tester.ensureVisible(find.text('تسليم دفعة للزبون'));
    await tester.tap(find.text('تسليم دفعة للزبون'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المأخوذ من 0.66 غ'),
      '40',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('لم يأخذ الزبون شيئاً بعد'), findsNothing);

    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();
    final inv = s.invoiceById('i')!;
    expect(inv.partialDelivery, isTrue);
    expect(inv.takenOf('p'), 40);
    expect(inv.leftOf('p'), 60);
    expect(find.textContaining('بقي له'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the panel fits a phone screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await s.saveInvoice(sale(deliveries: [take('d1', 30)]));

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChangeNotifierProvider.value(
            value: s,
            child: InvoiceEditorPage(
              type: InvoiceType.sale,
              existing: s.invoiceById('i'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // الفاتورة التي على دفعات تفتح ولوحة التسليم ظاهرة.
    await tester.scrollUntilVisible(
      find.text('تسليم دفعة للزبون'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('المتبقي'), findsOneWidget);
    expect(find.text('70 قطعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
