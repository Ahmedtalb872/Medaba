import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/models.dart';
import '../state/app_state.dart' show DealStatement, DealLine;
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

/// كشف صفقة يرسله المدير للشريك: مصروفاتها ومداخيلها وربحها ونصيب كل شريك.
Future<Uint8List> buildDealStatementPdf({
  required DealStatement deal,
  required Partner partner,
  required double withdrawn,
  required CompanyInfo company,
}) async {
  final doc = pw.Document(
    title: 'كشف ${deal.title}',
    author: company.name,
    theme: await loadPdfTheme(),
  );
  final profit = deal.profit;
  double? shareOf(Partner p) =>
      profit == null ? null : profit * p.sharePercent / 100;
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
        _header(deal.title, partner.name, company),
        pw.SizedBox(height: 14),
        _title('الشريك'),
        pw.Row(
          children: [
            _box('الاسم', partner.name),
            _box('الهاتف', partner.phone),
            _box('المبلغ المستثمر', fmt.money(partner.capital)),
          ],
        ),
        pw.Row(
          children: [
            _box('النسبة', fmt.percent(partner.sharePercent)),
            _box(
              'نصيبه من الربح',
              shareOf(partner) == null
                  ? 'لم تنتهِ بعد'
                  : fmt.money(shareOf(partner)!),
            ),
            _box('المسحوب', fmt.money(withdrawn)),
          ],
        ),
        pw.SizedBox(height: 12),
        _title('المصروفات'),
        _row('التاريخ', 'البيان', 'المبلغ', head: true),
        for (final e in deal.expenses) _line3(e),
        if (deal.expenses.isEmpty) _row('', 'لا توجد مصروفات مسجلة', ''),
        _row(
          '',
          'إجمالي المصروفات',
          fmt.money(deal.expensesTotal),
          total: true,
        ),
        if (deal.income.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _title('المداخيل'),
          _row('التاريخ', 'البيان', 'المبلغ', head: true),
          for (final e in deal.income) _line3(e),
        ],
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: (profit ?? 0) >= 0
                ? const PdfColor.fromInt(0xFFEAF7EE)
                : const PdfColor.fromInt(0xFFFDECEC),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  profit == null
                      ? 'ربح الصفقة'
                      : profit >= 0
                      ? 'ربح الصفقة'
                      : 'خسارة الصفقة',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              pw.Text(
                profit == null ? 'لم تنتهِ بعد' : fmt.money(profit.abs()),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                  color: (profit ?? 0) >= 0 ? _green : _red,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _title('الشركاء في الصفقة'),
        _row4('الشريك', 'المبلغ', 'النسبة', 'النصيب', head: true),
        for (final p in deal.partners)
          _row4(
            p.name,
            fmt.money(p.capital),
            fmt.percent(p.sharePercent),
            shareOf(p) == null ? '-' : fmt.money(shareOf(p)!),
          ),
      ],
    ),
  );
  return doc.save();
}

final _arabic = RegExp(r'[؀-ۿ]');
pw.TextDirection? _dir(String t) =>
    _arabic.hasMatch(t) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

pw.Widget _header(String title, String partner, CompanyInfo c) => pw.Container(
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
        c.name,
        style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: pw.BoxDecoration(
          color: _gold,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'كشف الصفقة للشريك $partner',
          style: pw.TextStyle(
            color: _brandDark,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
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

pw.Widget _line3(DealLine e) =>
    _row(e.date == null ? '' : fmt.date(e.date!), e.label, fmt.money(e.amount));

pw.BoxDecoration _rowDecoration(bool head, bool total) => pw.BoxDecoration(
  color: head
      ? _brand
      : total
      ? _panel
      : null,
  border: head ? null : const pw.Border(bottom: pw.BorderSide(color: _line)),
);

pw.TextStyle _rowStyle(bool head, bool total) => pw.TextStyle(
  fontSize: head || total ? 10 : 9.5,
  fontWeight: head || total ? pw.FontWeight.bold : null,
  color: head ? PdfColors.white : null,
);

pw.Widget _row(
  String date,
  String label,
  String amount, {
  bool head = false,
  bool total = false,
}) {
  final style = _rowStyle(head, total);
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: _rowDecoration(head, total),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            date,
            style: style,
            textDirection: _dir(date),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Expanded(
          child: pw.Text(label, style: style, textDirection: _dir(label)),
        ),
        pw.Text(amount, style: style, textDirection: _dir(amount)),
      ],
    ),
  );
}

pw.Widget _row4(String a, String b, String c, String d, {bool head = false}) {
  final style = _rowStyle(head, false);
  pw.Widget cell(String t, int flex) => pw.Expanded(
    flex: flex,
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Text(
        t,
        style: style,
        textDirection: _dir(t),
        textAlign: pw.TextAlign.right,
      ),
    ),
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: _rowDecoration(head, false),
    child: pw.Row(children: [cell(a, 3), cell(b, 2), cell(c, 1), cell(d, 2)]),
  );
}
