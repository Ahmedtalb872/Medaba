import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:medaba/data/storage.dart';
import 'package:medaba/models/inventory.dart';
import 'package:medaba/models/invoice.dart';
import 'package:medaba/pdf/invoice_pdf.dart';
import 'package:medaba/state/app_state.dart';
import 'package:medaba/utils/product_image.dart';

Uint8List pngOf(int w, int h) => img.encodePng(
  img.Image(width: w, height: h)..clear(img.ColorRgb8(11, 110, 79)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large images are shrunk to JPEG within the max side', () {
    final encoded = encodeProductImage(pngOf(1200, 800))!;
    final decoded = img.decodeJpg(productImageBytes(encoded))!;
    expect(decoded.width, productImageMaxSide);
    expect(decoded.height, lessThan(productImageMaxSide));

    final tall = img.decodeJpg(
      productImageBytes(encodeProductImage(pngOf(300, 900))!),
    )!;
    expect(tall.height, productImageMaxSide);

    final small = img.decodeJpg(
      productImageBytes(encodeProductImage(pngOf(100, 80))!),
    )!;
    expect(small.width, 100);
  });

  test('non-image data is rejected', () {
    expect(encodeProductImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('product image persists and survives edits', () async {
    final storage = MemoryStorage();
    final a = AppState(storage);
    await a.load();
    final image = encodeProductImage(pngOf(50, 50))!;
    await a.saveProduct(const Product(id: 'p', name: 'P'));
    await a.saveProduct(a.productById('p')!.withImage(image));

    final b = AppState(storage);
    await b.load();
    expect(b.productById('p')!.image, image);
    expect(b.productById('p')!.withImage(null).image, isNull);
  });

  test('invoice PDF embeds product images', () async {
    final s = AppState(MemoryStorage());
    await s.load();
    await s.saveWarehouse(const Warehouse(id: 'w', name: 'W'));
    await s.saveProduct(
      Product(
        id: 'p',
        name: 'صنف',
        salePrice: 10,
        image: encodeProductImage(pngOf(200, 200)),
      ),
    );
    await s.saveProduct(const Product(id: 'q', name: 'بدون صورة'));
    final inv = Invoice(
      id: 'i',
      type: InvoiceType.purchase,
      number: 'P-0001',
      date: DateTime(2026, 1, 1),
      warehouseId: 'w',
      lines: const [
        InvoiceLine(productId: 'p', qty: 1, unitPrice: 10),
        InvoiceLine(productId: 'q', qty: 1, unitPrice: 5),
      ],
    );
    Future<int> size() async => (await buildInvoicePdf(
      invoice: inv,
      company: s.company,
      productOf: s.productById,
      warehouseName: 'W',
    )).length;

    final withImage = await size();
    await s.saveProduct(s.productById('p')!.withImage(null));
    final without = await size();
    expect(withImage, greaterThan(without));
  });
}
