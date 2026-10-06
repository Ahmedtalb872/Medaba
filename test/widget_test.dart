import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/state/app_state.dart';

void main() {
  for (final size in [const Size(1400, 900), const Size(400, 800)]) {
    testWidgets('app renders and navigates with demo data at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = AppState(MemoryStorage());
      await state.load();
      await state.seedDemoData();
      await tester.pumpWidget(MedabaApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('لوحة التحكم'), findsWidgets);

      for (final label in [
        'الشركاء',
        'العمال',
        'المخازن',
        'المعاملات',
        'توزيع الأرباح',
        'الإعدادات',
      ]) {
        if (size.width < 800) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('inventory tabs and new stock movement form', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخازن').first);
    await tester.pumpAndSettle();
    for (final tab in ['الحركات', 'الأصناف', 'المخزون']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    final movesBefore = state.moves.length;
    final productId = state.products.first.id;
    final stockBefore = state.stockOf(productId);
    await tester.tap(find.text('حركة جديدة'));
    await tester.pumpAndSettle();
    // النوع الافتراضي "وارد - شراء" والسعر مملوء تلقائياً من سعر التكلفة.
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '5');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.moves.length, movesBefore + 1);
    expect(state.stockOf(productId), stockBefore + 5);
  });
}
