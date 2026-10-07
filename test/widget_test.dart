import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/utils/product_image.dart';

import 'product_image_test.dart' show pngOf;

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
        'الفواتير',
        'الديون',
        'الشحنات البحرية',
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

  testWidgets('create a sale invoice through the editor', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    // صورة للصنف الأول تظهر في سطر الفاتورة.
    await state.saveProduct(
      state.products.first.withImage(encodeProductImage(pngOf(60, 60))),
    );
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();
    final before = state.invoices.length;
    final productId = state.products.first.id;
    final stockBefore = state.stockOf(productId);

    await tester.tap(find.text('فاتورة بيع جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'العميل'),
      'عميل تجريبي',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '2');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    expect(
      find.text('اضغط على صورة الصنف لرفعها أو تغييرها قبل حفظ الفاتورة'),
      findsOneWidget,
    );
    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.invoices.length, before + 1);
    final inv = state.invoices.firstWhere((i) => i.partyName == 'عميل تجريبي');
    expect(inv.type, InvoiceType.sale);
    expect(state.stockOf(productId), stockBefore - 2);
    // عاد إلى قائمة الفواتير مع رسالة تأكيد.
    expect(find.text('عرض PDF'), findsOneWidget);
  });
}
