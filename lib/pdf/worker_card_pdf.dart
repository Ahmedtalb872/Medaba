import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/models.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';
import 'invoice_pdf.dart' show loadPdfTheme;

const _brand = PdfColor.fromInt(0xFF0B4D38);
const _brandDark = PdfColor.fromInt(0xFF07291F);
const _gold = PdfColor.fromInt(0xFFE0A526);
const _ink = PdfColor.fromInt(0xFF111827);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _paper = PdfColor.fromInt(0xFFFFFCF5);

/// مقاس البطاقات البنكية وبطاقات التعريف (ISO 7810 ID-1).
final workerCardFormat = PdfPageFormat(
  85.6 * PdfPageFormat.mm,
  54 * PdfPageFormat.mm,
);

/// بطاقة تعريف العامل: صورته، اسمه، دوره في العمل، ورقمه الوطني.
Future<Uint8List> buildWorkerCardPdf({
  required Worker worker,
  required CompanyInfo company,
}) async {
  final doc = pw.Document(
    title: 'بطاقة ${worker.name}',
    author: company.name,
    theme: await loadPdfTheme(),
  );
  doc.addPage(
    pw.Page(
      pageFormat: workerCardFormat,
      margin: pw.EdgeInsets.zero,
      textDirection: pw.TextDirection.rtl,
      build: (_) => _card(worker, company),
    ),
  );
  return doc.save();
}

pw.Widget _card(Worker w, CompanyInfo c) => pw.Container(
  color: _paper,
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_brand, _brandDark]),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                c.name,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: _gold,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'بطاقة عامل',
                style: pw.TextStyle(
                  color: _brandDark,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _photo(w),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      w.name,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    if (w.jobTitle.isNotEmpty)
                      pw.Text(
                        w.jobTitle,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _brand,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.SizedBox(height: 5),
                    _field(
                      'الرقم الوطني',
                      w.nationalId.isEmpty ? '—' : w.nationalId,
                    ),
                    if (w.phone.isNotEmpty) _field('الهاتف', w.phone),
                    _field('تاريخ التعيين', fmt.date(w.hiredAt)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      pw.Container(
        height: 12,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        color: _gold,
        alignment: pw.Alignment.center,
        child: pw.Text(
          c.address,
          style: pw.TextStyle(fontSize: 6, color: _brandDark),
        ),
      ),
    ],
  ),
);

pw.Widget _photo(Worker w) => pw.Container(
  width: 62,
  height: 76,
  decoration: pw.BoxDecoration(
    color: PdfColors.white,
    border: pw.Border.all(color: _gold, width: 1.5),
    borderRadius: pw.BorderRadius.circular(6),
  ),
  child: pw.ClipRRect(
    horizontalRadius: 5,
    verticalRadius: 5,
    child: w.photo != null
        ? pw.Image(
            pw.MemoryImage(productImageBytes(w.photo!)),
            fit: pw.BoxFit.cover,
          )
        : pw.Center(
            child: pw.Icon(
              const pw.IconData(0xe497), // person_outline
              size: 34,
              color: _muted,
            ),
          ),
  ),
);

/// سطر «العنوان: القيمة»؛ القيمة من اليسار لليمين لأنها أرقام.
pw.Widget _field(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Row(
    children: [
      pw.Text(
        '$label: ',
        style: const pw.TextStyle(fontSize: 7, color: _muted),
      ),
      pw.Text(
        value,
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ],
  ),
);
