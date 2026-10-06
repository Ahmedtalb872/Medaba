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
        'المستثمرون',
        'العمال',
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
}
