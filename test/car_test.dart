import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/car.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/pdf/car_card_pdf.dart';
import 'package:medaba/state/app_state.dart';
import 'package:medaba/utils/product_image.dart';

import 'product_image_test.dart' show pngOf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bought = DateTime(2026, 3, 1);

  Car car({CarStatus status = CarStatus.atSea, double sale = 0}) => Car(
    id: 'c',
    make: 'تويوتا',
    model: 'هايلكس',
    year: 2019,
    vin: 'MR0FA3CD200123456',
    purchaseDate: bought,
    purchasePrice: 500000,
    shippingCompany: 'الأطلسي',
    shippedDate: DateTime(2026, 3, 5),
    arrivalDate: DateTime(2026, 3, 25),
    costs: [CarCost('الشحن', 60000, DateTime(2026, 3, 5))],
    status: status,
    salePrice: sale,
    saleDate: status == CarStatus.sold ? DateTime(2026, 5, 1) : null,
  );

  test('title, cost card and profit', () {
    expect(car().title, 'تويوتا هايلكس 2019');
    expect(car().totalCost, 560000);
    expect(car().profit, isNull);
    expect(car(status: CarStatus.sold, sale: 700000).profit, 140000);
  });

  test('late at sea and days to arrival', () {
    final now = DateTime(2026, 3, 30);
    expect(car().isLate(now), isTrue);
    expect(car().daysToArrival(now), -5);
    expect(car(status: CarStatus.inStock).isLate(now), isFalse);
  });

  test('cars survive saving, costs and stage changes', () async {
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.load();
    await a.saveCar(car());
    await a.addCarCost('c', CarCost('الجمارك', 90000, DateTime(2026, 3, 27)));
    await a.setCarStatus('c', CarStatus.inStock);

    final b = AppState(storage);
    await b.load();
    final x = b.carById('c')!;
    expect(x.costs.map((c) => c.label), ['الشحن', 'الجمارك']);
    expect(x.totalCost, 650000);
    expect(x.status, CarStatus.inStock);
    expect(b.carsOnTheWay, isEmpty);
    expect(AppState.storageKeys, contains('cars'));
  });

  test('impossible dates are refused', () async {
    final a = AppState(MemoryStorage());
    await a.load();
    final arrivesBeforeShipping = Car.fromJson({
      ...car().toJson(),
      'arrivalDate': DateTime(2026, 3, 1).toIso8601String(),
    });
    expect(() => a.saveCar(arrivesBeforeShipping), throwsStateError);
  });

  test('the expense card PDF builds with and without a photo', () async {
    final photo = encodeProductImage(pngOf(300, 200))!;
    for (final c in [
      car(status: CarStatus.sold, sale: 700000),
      car().copyWith(photo: photo),
    ]) {
      final bytes = await buildCarCardPdf(car: c, company: const CompanyInfo());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });
}
