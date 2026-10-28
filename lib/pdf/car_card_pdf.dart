import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/car.dart';
import '../models/invoice.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';
import 'invoice_pdf.dart' show loadPdfTheme;

const _brand = PdfColor.fromInt(0xFF0B4D38);
const _brandDark = PdfColor.fromInt(0xFF07291F);
const _gold = PdfColor.fromInt(0xFFE0A526);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE3E7EF);
const _panel = PdfColor.fromInt(0xFFF3F6F4);
const _green = PdfColor.fromInt(0xFF15803D);
const _red = PdfColor.fromInt(0xFFB91C1C);

/// بطاقة مصاريف السيارة: معلوماتها وشحنها وكل ما دُفع فيها منذ الشراء.
Future<Uint8List> buildCarCardPdf({
  required Car car,
  required CompanyInfo company,
}) async {
  final doc = pw.Document(
    title: 'بطاقة ${car.title}',
    author: company.name,
    theme: await loadPdfTheme(),
  );
  final costs = [...car.costs]..sort((a, b) => a.date.compareTo(b.date));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${company.name} • ${company.address} • ${company.phone}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (_) => [
        _header(car, company),
        pw.SizedBox(height: 14),
        _section('معلومات السيارة', [
          ('الماركة', car.make, false),
          ('الموديل', car.model, false),
          ('سنة الصنع', car.year?.toString() ?? '', true),
          ('اللون', car.color, false),
          ('رقم الشاسيه', car.vin, true),
          ('رقم اللوحة', car.plate, true),
        ]),
        pw.SizedBox(height: 10),
        _section('الشحن', [
          ('شُحنت من', car.origin, false),
          ('شركة الشحن', car.shippingCompany, false),
          ('الحاوية / البوليصة', car.container, true),
          ('تاريخ الشحن', _d(car.shippedDate), true),
          ('تاريخ الوصول', _d(car.arrivalDate), true),
          ('المرحلة', car.status.label, false),
        ]),
        pw.SizedBox(height: 10),
        _title('المصاريف منذ الشراء'),
        _row('التاريخ', 'البيان', 'المبلغ', head: true),
        _row(
          fmt.date(car.purchaseDate),
          'سعر شراء السيارة',
          fmt.money(car.purchasePrice),
        ),
        for (final c in costs)
          _row(fmt.date(c.date), c.label, fmt.money(c.amount)),
        _row('', 'إجمالي التكلفة', fmt.money(car.totalCost), total: true),
        if (car.isSold) ...[
          pw.SizedBox(height: 10),
          _section('البيع', [
            ('المشتري', car.buyer, false),
            ('هاتف المشتري', car.buyerPhone, true),
            ('تاريخ البيع', _d(car.saleDate), true),
            ('سعر البيع', fmt.money(car.salePrice), false),
          ]),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: car.profit! >= 0
                  ? const PdfColor.fromInt(0xFFEAF7EE)
                  : const PdfColor.fromInt(0xFFFDECEC),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    car.profit! >= 0 ? 'الربح' : 'الخسارة',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                pw.Text(
                  fmt.money(car.profit!.abs()),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: car.profit! >= 0 ? _green : _red,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (car.note.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _title('ملاحظات'),
          pw.Text(car.note),
        ],
      ],
    ),
  );
  return doc.save();
}

String _d(DateTime? d) => d == null ? '' : fmt.date(d);

final _arabic = RegExp(r'[؀-ۿ]');
pw.TextDirection? _dir(String t) =>
    _arabic.hasMatch(t) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

pw.Widget _header(Car car, CompanyInfo c) => pw.Container(
  padding: const pw.EdgeInsets.all(14),
  decoration: pw.BoxDecoration(
    gradient: const pw.LinearGradient(colors: [_brand, _brandDark]),
    borderRadius: pw.BorderRadius.circular(10),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              c.name,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              car.title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: _gold,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'بطاقة مصاريف السيارة',
                style: pw.TextStyle(
                  color: _brandDark,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      if (car.photo != null)
        pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Image(
            pw.MemoryImage(productImageBytes(car.photo!)),
            width: 150,
            height: 100,
            fit: pw.BoxFit.cover,
          ),
        ),
    ],
  ),
);

pw.Widget _title(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(
    t,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _brand,
    ),
  ),
);

/// مربعات «عنوان: قيمة» في صفوف من ثلاثة.
pw.Widget _section(String title, List<(String, String, bool)> fields) {
  pw.Widget cell((String, String, bool) f) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.all(3),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: _panel,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(f.$1, style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Text(
            f.$2.isEmpty ? '-' : f.$2,
            textDirection: f.$3 ? pw.TextDirection.ltr : _dir(f.$2),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _title(title),
      for (var i = 0; i < fields.length; i += 3)
        pw.Row(
          children: [
            for (final f in fields.skip(i).take(3)) cell(f),
            for (var k = fields.skip(i).take(3).length; k < 3; k++)
              pw.Expanded(child: pw.SizedBox()),
          ],
        ),
    ],
  );
}

pw.Widget _row(
  String date,
  String label,
  String amount, {
  bool head = false,
  bool total = false,
}) {
  final style = pw.TextStyle(
    fontSize: head || total ? 10 : 9.5,
    fontWeight: head || total ? pw.FontWeight.bold : null,
    color: head ? PdfColors.white : null,
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: head
          ? _brand
          : total
          ? _panel
          : null,
      border: head
          ? null
          : const pw.Border(bottom: pw.BorderSide(color: _line)),
    ),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(date, style: style, textDirection: _dir(date)),
        ),
        pw.Expanded(
          child: pw.Text(label, style: style, textDirection: _dir(label)),
        ),
        pw.Text(amount, style: style, textDirection: _dir(amount)),
      ],
    ),
  );
}
