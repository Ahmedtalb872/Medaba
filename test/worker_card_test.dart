import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/pdf/worker_card_pdf.dart';
import 'package:medaba/utils/product_image.dart';

import 'product_image_test.dart' show pngOf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final worker = Worker(
    id: 'w1',
    name: 'سالم يوسف',
    jobTitle: 'أمين مخزن',
    nationalId: '1234567890',
    phone: '22 33 44 55',
    monthlySalary: 20000,
    hiredAt: DateTime(2025, 1, 5),
  );

  test('national id and photo survive a save and load', () {
    final photo = encodeProductImage(pngOf(600, 800))!;
    final back = Worker.fromJson(worker.withPhoto(photo).toJson());
    expect(back.nationalId, '1234567890');
    expect(back.jobTitle, 'أمين مخزن');
    expect(back.photo, photo);
    expect(back.withPhoto(null).photo, isNull);
    expect(back.withPhoto(null).nationalId, '1234567890');
  });

  test('workers saved before the card fields load with empty values', () {
    final old = Worker.fromJson({
      'id': 'w',
      'name': 'W',
      'monthlySalary': 1000,
      'hiredAt': '2025-01-01T00:00:00.000',
    });
    expect(old.nationalId, '');
    expect(old.photo, isNull);
  });

  test('worker card PDF builds with and without a photo', () async {
    final photo = encodeProductImage(pngOf(300, 400))!;
    for (final w in [worker, worker.withPhoto(photo)]) {
      final bytes = await buildWorkerCardPdf(
        worker: w,
        company: const CompanyInfo(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });
}
