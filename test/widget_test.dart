import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/cloud.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/main.dart';
import 'package:medaba/models/car.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/utils/format.dart' as fmt;
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

      expect(find.text('الرئيسية'), findsWidgets);

      for (final label in [
        'الشركاء',
        'العمال',
        'المخزون',
        'الفواتير',
        'الديون',
        'السيارات',
        'حاويات البضاعة',
        'القطع الأرضية',
        'المعاملات',
        'التقارير والأرباح',
        'الإعدادات',
      ]) {
        if (size.width < 900) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('an investor is added to one container deal', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الشركاء').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة شريك'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حاوية'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'رقم الحاوية أو وصفها'),
      'MSCU 123',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم'), 'سالم');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ المستثمر'),
      '300000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نسبته من ربح الصفقة %'),
      '30',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final p = state.partners.single;
    expect(p.scope, PartnerScope.container);
    expect(p.dealTitle, 'MSCU 123');
    expect(p.capital, 300000);
    expect(find.text('حاوية: MSCU 123'), findsOneWidget);
    expect(find.text('لم تنتهِ بعد'), findsOneWidget);
  });

  testWidgets('a stock worker sees only the inventory', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    cloudLogin = const CloudLogin('w', 'p', CloudLogin.stockRole);
    addTearDown(() => cloudLogin = null);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('الحركات'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('الفواتير'), findsNothing);
    expect(find.text('تغيير الاسم'), findsNothing);
  });

  testWidgets('top bar shows the user and finds invoices by party', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text(CompanyInfo.defaultOwnerName), findsOneWidget);
    expect(
      find.text('مرحباً بك ${CompanyInfo.defaultOwnerName}'),
      findsOneWidget,
    );

    final invoice = state.invoices.first;
    await tester.enterText(find.byType(TextField).first, invoice.partyName);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.text('${invoice.type.label} ${invoice.number}'),
      findsOneWidget,
    );
  });

  testWidgets('the inventory section can be renamed', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تغيير الاسم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'المستودع');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.company.inventoryLabel, 'المستودع');
    // في القائمة الجانبية وعنوان الصفحة.
    expect(find.text('المستودع'), findsNWidgets(2));

    // الاسم يبقى بعد حفظ بيانات المنشأة، والاسم الفارغ يعيد الافتراضي.
    final back = CompanyInfo.fromJson(state.company.toJson());
    expect(back.inventoryLabel, 'المستودع');
    await state.renameInventory('  ');
    expect(state.company.inventoryLabel, CompanyInfo.defaultInventoryLabel);
  });

  testWidgets('a new item is stored in the chosen warehouse', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    final branch = state.warehouses.last;
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'الأصناف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة صنف'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم الصنف'),
      'رمل',
    );
    // الوحدة تُختار من الأزرار.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'طن'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'طن'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'سعر الشراء'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'سعر البيع'),
      '150',
    );
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(branch.name).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية الموجودة الآن'),
      '12',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final sand = state.products.singleWhere((p) => p.name == 'رمل');
    expect(sand.unit, 'طن');
    expect(state.stockOf(sand.id, warehouseId: branch.id), 12);
    expect(state.stockOf(sand.id), 12);
  });

  testWidgets('a car opens its expense card', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('السيارات').first);
    await tester.pumpAndSettle();
    final car = state.carsOnTheWay.first;
    await tester.tap(find.text(car.title));
    await tester.pumpAndSettle();

    expect(find.text('بطاقة ${car.title}'), findsOneWidget);
    expect(find.text('المصاريف منذ الشراء'), findsOneWidget);
    expect(find.text('سعر شراء السيارة'), findsOneWidget);
    expect(find.text('إجمالي التكلفة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buy and sell ask which business first', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    // البيع: يظهر الاختيار بين الأنشطة الثلاثة.
    await tester.tap(find.text('بيع جديد'));
    await tester.pumpAndSettle();
    expect(find.text('طيبة للسيارات'), findsOneWidget);
    expect(find.text('طيبة للقطع الأرضية'), findsOneWidget);
    expect(find.text('طيبة للتجارة العامة'), findsOneWidget);

    // بيع سيارة: المعروضة في المعرض تأتي أولاً.
    await tester.tap(find.text('طيبة للسيارات'));
    await tester.pumpAndSettle();
    final car = state.cars.firstWhere((c) => c.status == CarStatus.inStock);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المشتري'),
      'زبون السيارة',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'سعر البيع'),
      fmt.number(car.totalCost + 100000),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('الربح: 100,000'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    final sold = state.carById(car.id)!;
    expect(sold.isSold, isTrue);
    expect(sold.buyer, 'زبون السيارة');
    expect(sold.profit, 100000);

    // الشراء للتجارة العامة يفتح فاتورة شراء.
    await tester.tap(find.text('شراء جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طيبة للتجارة العامة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('فاتورة شراء'), findsWidgets);
  });

  testWidgets('many items are added from one pasted list', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'الأصناف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة عدة أصناف'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'الأصناف (سطر لكل صنف)'),
      '[١٢/١٠، ٢١:١٣] محمد آبا: 0.66 غ\n'
      '[١٢/١٠، ٢١:٢١] محمد آبا: #13\n'
      '[١٢/١٠، ٢١:٢٢] محمد آبا: 24# green',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم يسبق كل صنف (اختياري)'),
      'زنك',
    );
    await tester.pumpAndSettle();
    expect(find.text('سيُضاف 3 صنف'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.products.map((p) => p.name), [
      'زنك 0.66 غ',
      'زنك #13',
      'زنك 24# green',
    ]);
  });

  testWidgets('stock is increased with the person responsible', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.saveWarehouse(const Warehouse(id: 'w', name: 'المخزن'));
    await state.saveProduct(
      const Product(id: 'z', name: 'زنك 0.66 غ', costPrice: 100),
    );
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('زيادة المخزون'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية المضافة'),
      '40',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'العميل / المسؤول عن الزيادة'),
      'سيدي',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.stockOf('z', warehouseId: 'w'), 40);
    final move = state.moves.single;
    expect(move.person, 'سيدي');
    expect(move.type, MoveType.stockIn);
    // «إضافة» لا تُسجّل مصروفاً.
    expect(state.transactions, isEmpty);
  });

  testWidgets('inventory tabs and new stock movement form', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المخزون').first);
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
    // النوع الافتراضي "وارد - شراء" والسعر مملوء تلقائياً من سعر الشراء.
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '5');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(state.moves.length, movesBefore + 1);
    expect(state.stockOf(productId), stockBefore + 5);
  });

  testWidgets('the selling price can be changed for one customer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();
    final product = state.products.first;

    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فاتورة بيع جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'العميل'),
      'عميل خاص',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '1');
    final price = find.widgetWithText(TextFormField, 'سعر الفرد');
    expect(find.text('السعر المسجل'), findsOneWidget);

    // تخفيض للعميل يظهر تحت السعر، وزر الإرجاع يعيد السعر المسجل.
    await tester.enterText(price, fmt.number(product.salePrice - 30));
    await tester.pumpAndSettle();
    expect(
      find.text('تخفيض 30 عن ${fmt.number(product.salePrice)}'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('إرجاع السعر المسجل'));
    await tester.pumpAndSettle();
    expect(find.text('السعر المسجل'), findsOneWidget);

    // أقل من سعر الشراء: تحذير، لكن الحفظ مسموح.
    await tester.enterText(price, fmt.number(product.costPrice - 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('أقل من سعر الشراء'), findsOneWidget);

    await tester.enterText(price, fmt.number(product.salePrice + 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();

    final inv = state.invoices.firstWhere((i) => i.partyName == 'عميل خاص');
    expect(inv.lines.single.unitPrice, product.salePrice + 20);
    // السعر المسجل للصنف لا يتغير.
    expect(state.productById(product.id)!.salePrice, product.salePrice);
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

  testWidgets('sale invoice on debt records the unpaid amount', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(MemoryStorage());
    await state.load();
    await state.seedDemoData();
    await tester.pumpWidget(MedabaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فاتورة بيع جديدة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '2');
    await tester.tap(find.text('دين'));
    await tester.pumpAndSettle();
    // الدين يحتاج اسم العميل.
    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب الاسم لتسجيل الدين'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'العميل'),
      'زبون بالآجل',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'المدفوع الآن (اتركه فارغاً إن لم يُدفع شيء)',
      ),
      '100',
    );
    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final inv = state.invoices.firstWhere((i) => i.partyName == 'زبون بالآجل');
    expect(inv.debt, closeTo(inv.total - 100, 0.001));
    final debt = state.debtForInvoice(inv.id)!;
    expect(debt.personName, 'زبون بالآجل');
    expect(debt.remaining, closeTo(inv.total - 100, 0.001));
  });
}
