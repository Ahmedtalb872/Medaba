import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/models.dart';
import '../utils/format.dart' as fmt;
import 'invoice_pdf.dart' show loadPdfTheme;

const _brand = PdfColor.fromInt(0xFF0B4D38);
const _brandDark = PdfColor.fromInt(0xFF07291F);
const _gold = PdfColor.fromInt(0xFFE0A526);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE3E7EF);
const _panel = PdfColor.fromInt(0xFFF3F6F4);
const _green = PdfColor.fromInt(0xFF15803D);
const _red = PdfColor.fromInt(0xFFB91C1C);

/// مرحلة مدفوعة كما تظهر في فاتورة العمل.
typedef JobStageLine = ({DateTime date, String stage, double amount});

/// فاتورة واحدة لعمل المقاولة: المبلغ المتفق عليه وكل المراحل المدفوعة
/// بتواريخها، والمدفوع والباقي بعد كل مرحلة.
Future<Uint8List> buildJobInvoicePdf({
  required Worker worker,
  required WorkJob job,
  required List<JobStageLine> stages,
  required CompanyInfo company,
  String? place,
}) async {
  final doc = pw.Document(
    title: 'فاتورة ${job.title} - ${worker.name}',
    author: company.name,
    theme: await loadPdfTheme(),
  );
  final paid = stages.fold<double>(0, (a, s) => a + s.amount);
  final left = job.agreed - paid;
  var running = 0.0;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${company.name} • ${company.address} • ${company.phone}'
          ' • ${fmt.date(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (_) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(colors: [_brand, _brandDark]),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company.name,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                job.title,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
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
                  'فاتورة عمل بالمقاولة',
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
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _box('العامل', worker.name),
            _box('الهاتف', worker.phone),
            _box('الرقم الوطني', worker.nationalId),
          ],
        ),
        pw.Row(
          children: [
            _box('تاريخ البدء', fmt.date(job.start)),
            _box('مكان العمل', place ?? ''),
            _box('الحالة', left <= 1e-9 ? 'اكتمل' : 'جارٍ'),
          ],
        ),
        pw.SizedBox(height: 12),
        _title('المراحل المدفوعة'),
        _row([
          '#',
          'التاريخ',
          'المرحلة',
          'المبلغ',
          'المدفوع حتى الآن',
          'الباقي',
        ], head: true),
        for (final (n, s) in stages.indexed)
          () {
            running += s.amount;
            return _row([
              '${n + 1}',
              fmt.date(s.date),
              s.stage,
              fmt.money(s.amount),
              fmt.money(running),
              fmt.money(job.agreed - running),
            ]);
          }(),
        if (stages.isEmpty) _row(['', '', 'لم تُدفع أي مرحلة بعد', '', '', '']),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _panel,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _total('المبلغ الكلي المتفق عليه', job.agreed, null),
              _total('المدفوع', paid, _green),
              _total('الباقي', left, left > 1e-9 ? _red : _green, big: true),
            ],
          ),
        ),
        if (job.notes.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _title('ملاحظات'),
          pw.Text(job.notes),
        ],
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _sign('توقيع العامل'),
            _sign('توقيع ${company.ownerRole}'),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

final _arabic = RegExp(r'[؀-ۿ]');
pw.TextDirection _dir(String t) =>
    _arabic.hasMatch(t) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

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

pw.Widget _box(String label, String value) => pw.Expanded(
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
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Text(
          value.isEmpty ? '-' : value,
          textDirection: _dir(value),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  ),
);

const _flex = [1, 3, 5, 3, 4, 3];

pw.Widget _row(List<String> cells, {bool head = false}) {
  final style = pw.TextStyle(
    fontSize: head ? 9.5 : 9,
    fontWeight: head ? pw.FontWeight.bold : null,
    color: head ? PdfColors.white : null,
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: pw.BoxDecoration(
      color: head ? _brand : null,
      border: head
          ? null
          : const pw.Border(bottom: pw.BorderSide(color: _line)),
    ),
    child: pw.Row(
      children: [
        for (final (i, c) in cells.indexed)
          pw.Expanded(
            flex: _flex[i],
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Text(
                c,
                style: style,
                textDirection: _dir(c),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _total(String label, double v, PdfColor? color, {bool big = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: big ? 13 : 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            fmt.money(v),
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              fontSize: big ? 13 : 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

pw.Widget _sign(String label) => pw.Column(
  children: [
    pw.Container(width: 150, height: 1, color: _muted),
    pw.SizedBox(height: 4),
    pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
  ],
);
