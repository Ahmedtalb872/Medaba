import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/inventory.dart';
import '../models/invoice.dart';
import '../utils/format.dart' as fmt;

const _primary = PdfColor.fromInt(0xFF312E81);
const _accent = PdfColor.fromInt(0xFF4F46E5);
const _soft = PdfColor.fromInt(0xFFEEF2FF);
const _border = PdfColor.fromInt(0xFFD4D4E8);
const _muted = PdfColor.fromInt(0xFF6B7280);

pw.ThemeData? _theme;

/// يحمّل خط القاهرة مرة واحدة؛ الخطوط الافتراضية في PDF لا تدعم العربية.
Future<pw.ThemeData> _loadTheme() async => _theme ??= pw.ThemeData.withFont(
  base: pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf')),
  bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf')),
);

/// يبني ملف PDF للفاتورة بتصميم عربي من اليمين لليسار.
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required CompanyInfo company,
  required Product? Function(String id) productOf,
  required String warehouseName,
}) async {
  final doc = pw.Document(
    title: '${invoice.type.label} ${invoice.number}',
    author: company.name,
    theme: await _loadTheme(),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header(invoice, company),
      footer: (ctx) => _footer(ctx, company),
      build: (_) => [
        pw.SizedBox(height: 16),
        _partyBox(invoice, warehouseName),
        pw.SizedBox(height: 16),
        _linesTable(invoice, productOf),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _notes(invoice)),
            pw.SizedBox(width: 24),
            pw.SizedBox(width: 230, child: _totals(invoice)),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _header(Invoice inv, CompanyInfo c) => pw.Container(
  padding: const pw.EdgeInsets.all(18),
  decoration: const pw.BoxDecoration(
    gradient: pw.LinearGradient(colors: [_primary, _accent]),
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              c.name,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            for (final line in [
              c.address,
              if (c.phone.isNotEmpty) 'هاتف: ${c.phone}',
              if (c.taxNumber.isNotEmpty) 'الرقم الضريبي: ${c.taxNumber}',
            ])
              if (line.isNotEmpty)
                pw.Text(
                  line,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            inv.type.label,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'رقم: ${inv.number}',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
          ),
          pw.Text(
            'التاريخ: ${fmt.date(inv.date)}',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
          ),
        ],
      ),
    ],
  ),
);

pw.Widget _partyBox(Invoice inv, String warehouseName) {
  pw.Widget field(String label, String value) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 9)),
        pw.Text(
          value.isEmpty ? '-' : value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: pw.BoxDecoration(
      color: _soft,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border.all(color: _border),
    ),
    child: pw.Row(
      children: [
        field(inv.type.partyLabel, inv.partyName),
        field('الهاتف', inv.partyPhone),
        field('المخزن', warehouseName),
      ],
    ),
  );
}

pw.Widget _linesTable(Invoice inv, Product? Function(String) productOf) {
  const headers = [
    '#',
    'الصنف',
    'الكود',
    'الكمية',
    'الوحدة',
    'سعر الوحدة',
    'الإجمالي',
  ];
  final rows = [
    for (final (i, l) in inv.lines.indexed)
      () {
        final p = productOf(l.productId);
        return [
          '${i + 1}',
          p?.name ?? '-',
          p?.code ?? '',
          fmt.number(l.qty),
          p?.unit ?? '',
          fmt.money(l.unitPrice),
          fmt.money(l.total),
        ];
      }(),
  ];
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: null,
    headerDecoration: const pw.BoxDecoration(color: _primary),
    headerStyle: pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    ),
    cellStyle: const pw.TextStyle(fontSize: 10),
    oddRowDecoration: const pw.BoxDecoration(color: _soft),
    rowDecoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _border, width: .5)),
    ),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    headerAlignment: pw.Alignment.center,
    cellAlignment: pw.Alignment.center,
    cellAlignments: {1: pw.Alignment.centerRight},
    columnWidths: {
      0: const pw.FixedColumnWidth(24),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(1),
      4: const pw.FlexColumnWidth(1),
      5: const pw.FlexColumnWidth(1.6),
      6: const pw.FlexColumnWidth(1.8),
    },
  );
}

pw.Widget _totals(Invoice inv) {
  pw.Widget row(String label, String value, {bool strong = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: strong
            ? const pw.BoxDecoration(
                color: _primary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              )
            : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: strong ? 12 : 10,
                color: strong ? PdfColors.white : _muted,
                fontWeight: strong ? pw.FontWeight.bold : null,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: strong ? 13 : 10,
                color: strong ? PdfColors.white : null,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      children: [
        row('المجموع', fmt.money(inv.subtotal)),
        if (inv.discount > 0) row('الخصم', '- ${fmt.money(inv.discount)}'),
        if (inv.taxPercent > 0) ...[
          row('الصافي قبل الضريبة', fmt.money(inv.afterDiscount)),
          row(
            'ضريبة القيمة المضافة (${fmt.percent(inv.taxPercent)})',
            fmt.money(inv.tax),
          ),
        ],
        pw.SizedBox(height: 4),
        row('الإجمالي المستحق', fmt.money(inv.total), strong: true),
      ],
    ),
  );
}

pw.Widget _notes(Invoice inv) => inv.notes.isEmpty
    ? pw.SizedBox()
    : pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ملاحظات',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(inv.notes, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

pw.Widget _footer(pw.Context ctx, CompanyInfo c) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 12),
  padding: const pw.EdgeInsets.only(top: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: _border)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'شكراً لتعاملكم مع ${c.name}',
        style: const pw.TextStyle(color: _muted, fontSize: 9),
      ),
      pw.Text(
        'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
        style: const pw.TextStyle(color: _muted, fontSize: 9),
      ),
    ],
  ),
);
