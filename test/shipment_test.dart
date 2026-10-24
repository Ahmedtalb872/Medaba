import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/models/shipment.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  Shipment ship(
    String id, {
    String company = 'A',
    ShipmentStatus status = ShipmentStatus.atSea,
    DateTime? arrival,
  }) => Shipment(
    id: id,
    company: company,
    contents: 'C$id',
    departureDate: DateTime(2026, 3, 1),
    expectedArrival: arrival ?? DateTime(2026, 3, 20),
    status: status,
    goodsValue: 1000,
    freightCost: 200,
    customsCost: 50,
  );

  test('cost, delay and days to arrival', () {
    final x = ship('a');
    expect(x.totalCost, 1250);
    expect(x.daysToArrival(DateTime(2026, 3, 15, 18)), 5);
    expect(x.isDelayed(DateTime(2026, 3, 20, 23)), isFalse);
    expect(x.isDelayed(DateTime(2026, 3, 21)), isTrue);
    // في الميناء لم تعد متأخرة في البحر.
    expect(
      ship('b', status: ShipmentStatus.atPort).isDelayed(DateTime(2026, 4)),
      isFalse,
    );
    expect(ShipmentStatus.atSea.next, ShipmentStatus.atPort);
    expect(ShipmentStatus.received.next, isNull);
  });

  test('save, status changes, companies and persistence', () async {
    final storage = MemoryStorage();
    final s = AppState(storage);
    await s.load();
    await s.saveShipment(ship('a', company: 'B'));
    await s.saveShipment(
      ship('b', company: 'A', arrival: DateTime(2026, 3, 5)),
    );
    expect(s.shippingCompanies, ['A', 'B']);
    // الأقرب وصولاً أولاً.
    expect(s.shipments.first.id, 'b');

    expect(
      () => s.saveShipment(ship('c', arrival: DateTime(2026, 2, 1))),
      throwsStateError,
    );

    await s.setShipmentStatus(
      'b',
      ShipmentStatus.received,
      on: DateTime(2026, 3, 8),
    );
    expect(s.shipmentById('b')!.receivedDate, DateTime(2026, 3, 8));
    expect(s.activeShipments.map((x) => x.id), ['a']);
    expect(s.shipments.last.id, 'b');
    expect(s.delayedShipments(DateTime(2026, 4)), 1);

    // الرجوع عن الاستلام يمسح تاريخه.
    await s.setShipmentStatus('b', ShipmentStatus.customs);
    expect(s.shipmentById('b')!.receivedDate, isNull);

    final reloaded = AppState(storage);
    await reloaded.load();
    expect(reloaded.shipmentById('b')!.status, ShipmentStatus.customs);
    expect(reloaded.shipmentById('a')!.totalCost, 1250);

    await reloaded.deleteShipment('a');
    expect(reloaded.shipments.length, 1);
  });

  testWidgets('add a shipment and filter by company', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حاويات البضاعة').first);
    await tester.pumpAndSettle();
    final before = state.shipments.length;

    await tester.tap(find.text('حاوية جديدة'));
    await tester.pumpAndSettle();
    // اختيار شركة موجودة من الاقتراحات.
    await tester.tap(find.widgetWithText(ActionChip, 'شركة المتوسط للملاحة'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'البضاعة'),
      'رخام',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.shipments.length, before + 1);
    final added = state.shipments.firstWhere((x) => x.contents == 'رخام');
    expect(added.company, 'شركة المتوسط للملاحة');
    expect(added.status, ShipmentStatus.atSea);

    // الضغط على بطاقة الشركة يعرض شحناتها فقط.
    await tester.tap(find.text('شركة الأطلسي للشحن البحري').first);
    await tester.pumpAndSettle();
    expect(find.text('رخام'), findsNothing);
    expect(find.text('حديد تسليح 12 مم - 25 طن'), findsOneWidget);
  });

  test('extra costs add to the total and survive saving', () {
    final x = Shipment(
      id: 'x',
      company: 'C',
      contents: 'حديد',
      departureDate: DateTime(2026, 1, 1),
      expectedArrival: DateTime(2026, 1, 20),
      goodsValue: 1000,
      freightCost: 200,
      customsCost: 100,
      extraCosts: const [
        ShipmentExtraCost('تفريغ', 50),
        ShipmentExtraCost('تخزين في الميناء', 25),
      ],
    );
    expect(x.extraCostTotal, 75);
    expect(x.totalCost, 1375);
    final back = Shipment.fromJson(x.toJson());
    expect(back.extraCosts.map((c) => c.label), ['تفريغ', 'تخزين في الميناء']);
    expect(back.totalCost, 1375);
    // الشحنات المحفوظة قبل هذه الميزة تُقرأ بدون تكاليف إضافية.
    final old = Shipment.fromJson(x.toJson()..remove('extraCosts'));
    expect(old.extraCosts, isEmpty);
  });

  test('labor without registered workers is charged to its place', () async {
    final s = AppState(MemoryStorage());
    await s.load();
    final day = DateTime(2026, 10, 16);
    await s.saveShipment(
      Shipment(
        id: 'sh',
        company: 'الأطلسي',
        containerNumber: 'MSCU 1',
        contents: 'زنك',
        departureDate: DateTime(2026, 10, 1),
        expectedArrival: day,
      ),
    );
    await s.saveWarehouse(const Warehouse(id: 'w', name: 'مخزن 1'));

    await s.recordLabor(
      date: day,
      amount: 15000,
      task: 'تنزيل البضاعة',
      place: LaborPlace.container,
      refId: 'sh',
      workers: 5,
      payer: 'أحمد',
    );
    await s.recordLabor(
      date: day,
      amount: 4000,
      task: 'رفع البضاعة',
      place: LaborPlace.warehouse,
      refId: 'w',
    );

    expect(s.totalExpenses(), 19000);
    expect(s.laborCost('sh'), 15000);
    expect(s.laborCost('w'), 4000);
    expect(s.shipmentById('sh')!.extraCosts.single.amount, 15000);
    expect(
      s.laborPayments().map((t) => t.note),
      containsAll([
        'أجرة عمال (5) - تنزيل البضاعة - حاوية MSCU 1 - دفعها: أحمد',
        'أجرة عمال - رفع البضاعة - مخزن 1',
      ]),
    );
  });

  testWidgets('labor is paid from the container row', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حاويات البضاعة').first);
    await tester.pumpAndSettle();

    final ship = state.shipments.first;
    final costsBefore = ship.extraCosts.length;
    final button = find.byTooltip('دفع أجرة عمال').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المدفوع للعمال'),
      '12000',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.laborCost(ship.id), 12000);
    expect(state.shipmentById(ship.id)!.extraCosts, hasLength(costsBefore + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a partner is added to a container with amount and share', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حاويات البضاعة').first);
    await tester.pumpAndSettle();

    final ship = state.shipments.first;
    final button = find.byTooltip('إضافة شريك في الحاوية').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم'), 'سالم');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المستثمر'),
      '5000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نسبته من ربح الصفقة %'),
      '25',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final p = state.investorsIn(PartnerScope.container, ship.id).single;
    expect(p.name, 'سالم');
    expect(p.capital, 5000000);
    expect(p.sharePercent, 25);
    expect(find.textContaining('سالم (25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
