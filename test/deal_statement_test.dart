import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/car.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/pdf/deal_statement_pdf.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final d = DateTime(2026, 3, 1);
  late AppState s;

  setUp(() async {
    s = AppState(MemoryStorage());
    await s.load();
    await s.saveCar(
      Car(
        id: 'c',
        make: 'تويوتا',
        model: 'هايلكس',
        purchaseDate: d,
        purchasePrice: 500000,
        costs: [CarCost('الشحن', 60000, DateTime(2026, 3, 5))],
        status: CarStatus.sold,
        buyer: 'محمد',
        salePrice: 700000,
        saleDate: DateTime(2026, 5, 1),
      ),
    );
    for (final (id, name, pct) in [('a', 'سيدي', 40.0), ('b', 'أحمد', 60.0)]) {
      await s.savePartner(
        Partner(
          id: id,
          name: name,
          sharePercent: pct,
          capital: 200000,
          joinedAt: d,
          scope: PartnerScope.car,
          dealId: 'c',
        ),
      );
    }
  });

  Partner partner(String id) => s.partners.firstWhere((p) => p.id == id);

  test('a car deal lists its expenses, sale and partners', () async {
    final deal = s.dealStatement(partner('a'));
    expect(deal.expenses.map((e) => e.amount), [500000, 60000]);
    expect(deal.expensesTotal, 560000);
    expect(deal.income.single.amount, 700000);
    expect(deal.profit, 140000);
    expect(deal.partners.map((p) => p.name), ['سيدي', 'أحمد']);

    await s.addDealExpense(
      partner('a'),
      label: 'إصلاح',
      amount: 10000,
      date: DateTime(2026, 4, 1),
    );
    final after = s.dealStatement(partner('a'));
    expect(after.expensesTotal, 570000);
    // المصروف الجديد يُنقص ربح السيارة.
    expect(after.profit, 130000);
    expect(s.dealShareOf(partner('a')), 52000);

    final pdf = await buildDealStatementPdf(
      deal: after,
      partner: partner('a'),
      withdrawn: 0,
      company: s.company,
    );
    expect(pdf.length, greaterThan(1000));
  });

  test(
    'warehouse and other deals collect their expense transactions',
    () async {
      await s.saveWarehouse(const Warehouse(id: 'w', name: 'مخزن 1'));
      final w = Partner(
        id: 'w1',
        name: 'شريك المخزن',
        sharePercent: 50,
        joinedAt: d,
        scope: PartnerScope.warehouse,
        dealId: 'w',
      );
      await s.savePartner(w);
      await s.payWarehouseRent(s.warehouseById('w')!, 30000, d);
      await s.addDealExpense(w, label: 'كهرباء', amount: 5000, date: d);
      expect(s.dealStatement(w).expensesTotal, 35000);

      final o = Partner(
        id: 'o1',
        name: 'شريك',
        sharePercent: 50,
        joinedAt: d,
        scope: PartnerScope.other,
        dealTitle: 'صفقة أسمنت',
      );
      await s.savePartner(o);
      await s.addDealExpense(o, label: 'نقل', amount: 7000, date: d);
      expect(s.dealStatement(o).expenses.single.amount, 7000);
      expect(s.dealStatement(w).expensesTotal, 35000);
    },
  );

  testWidgets('the statement opens from the partners page', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MedabaApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الشركاء').first);
    await tester.pumpAndSettle();
    final button = find.byTooltip('كشف الصفقة والمصروفات (PDF)').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('سعر شراء السيارة'), findsOneWidget);
    expect(find.text('PDF للشريك'), findsOneWidget);
    expect(find.text('إجمالي المصروفات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
