import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/inventory.dart';
import '../models/invoice.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';

// ألوان التصميم: رأس بنفسجي فاتح، جداول برؤوس رمادية، وشارات ملونة بإطار.
const _ink = PdfColor.fromInt(0xFF111827);
const _muted = PdfColor.fromInt(0xFF4B5563);
const _headBg = PdfColor.fromInt(0xFFE8EAF6);
const _headBorder = PdfColor.fromInt(0xFFC5CAE3);
const _gridHead = PdfColor.fromInt(0xFFDCDDE1);
const _gridSub = PdfColor.fromInt(0xFFE9EAED);
const _line = PdfColor.fromInt(0xFFE5E7EB);
const _cardBorder = PdfColor.fromInt(0xFFC9CDD6);
const _rowTint = PdfColor.fromInt(0xFFF3F4FB);
const _blue = PdfColor.fromInt(0xFF1D4ED8);

/// شارة بإطار ملون مثل REPORT / DEBIT / FINAL.
typedef _Tone = ({PdfColor fg, PdfColor bg});
const _indigo = (
  fg: PdfColor.fromInt(0xFF3730A3),
  bg: PdfColor.fromInt(0xFFEEF0FF),
);
const _green = (
  fg: PdfColor.fromInt(0xFF15803D),
  bg: PdfColor.fromInt(0xFFE7F6EC),
);
const _amber = (
  fg: PdfColor.fromInt(0xFFA16207),
  bg: PdfColor.fromInt(0xFFFFF5CC),
);
const _sky = (
  fg: PdfColor.fromInt(0xFF1D4ED8),
  bg: PdfColor.fromInt(0xFFE6F0FF),
);

pw.ThemeData? _theme;

/// يحمّل خط Rubik مرة واحدة؛ الخطوط الافتراضية في PDF لا تدعم العربية.
/// مسافة الكلمات في Rubik ضيقة، فنوسّعها قليلاً لتتضح الكلمات العربية.
Future<pw.ThemeData> _loadTheme() async {
  if (_theme != null) return _theme!;
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/Rubik-Regular.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Rubik-Bold.ttf')),
  );
  return _theme = theme.copyWith(
    defaultTextStyle: theme.defaultTextStyle.copyWith(
      wordSpacing: 1.6,
      color: _ink,
    ),
  );
}

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
  final generated = DateTime.now();
  // حسابات الدفع تخص فواتير البيع فقط (العميل يدفع لنا).
  final accounts = invoice.type == InvoiceType.sale
      ? company.paymentAccounts
      : const <PaymentAccount>[];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 20),
      footer: (ctx) => _footer(ctx, invoice, company),
      build: (_) => [
        _headerCard(invoice, company, warehouseName, generated),
        pw.SizedBox(height: 12),
        _linesCard(invoice, productOf),
        pw.SizedBox(height: 12),
        _summaryCard(invoice),
        if (invoice.notes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _notesCard(invoice.notes),
        ],
        if (accounts.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          // العنوان والبطاقات معاً حتى لا يبقى العنوان وحده آخر الصفحة؛
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('طرق الدفع والحسابات البنكية'),
                pw.SizedBox(height: 10),
                _accountCards(accounts, invoice),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

// ---------- عناصر مشتركة ----------

pw.Widget _badge(String text, _Tone tone) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: pw.BoxDecoration(
    color: tone.bg,
    border: pw.Border.all(color: tone.fg, width: 1.2),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 8,
      color: tone.fg,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

/// بطاقة بحواف مستديرة وإطار رمادي، تقص محتواها على الحواف.
pw.Widget _card(pw.Widget child, {PdfColor border = _cardBorder}) =>
    pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.ClipRRect(horizontalRadius: 9, verticalRadius: 9, child: child),
    );

pw.Widget _sectionTitle(String text) => pw.Text(
  text,
  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
);

/// الأرقام والرموز اللاتينية تُعرض من اليسار لليمين داخل النص العربي.
pw.Widget _ltr(String text, pw.TextStyle style) =>
    pw.Text(text, style: style, textDirection: pw.TextDirection.ltr);

// ---------- الرأس ----------

pw.Widget _headerCard(
  Invoice inv,
  CompanyInfo c,
  String warehouseName,
  DateTime generated,
) {
  pw.Widget kv(String label, String value, {bool ltr = false}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9)),
        ltr
            ? _ltr(
                value,
                pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              )
            : pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
      ],
    ),
  );

  pw.Widget pill(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _cardBorder, width: 1.2),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  final initial = c.name.trim().isEmpty ? 'م' : c.name.trim()[0];
  final details = [
    if (c.address.isNotEmpty) 'المقر: ${c.address}',
    if (c.taxNumber.isNotEmpty) 'الرقم الضريبي ${c.taxNumber}',
  ].join(' • ');

  return _card(
    border: _headBorder,
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _headBg,
          padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 30,
                height: 30,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  color: _blue,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  initial,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.name,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'فاتورة رسمية • ${inv.type.label}',
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                    if (details.isNotEmpty)
                      pw.Text(
                        details,
                        style: const pw.TextStyle(fontSize: 9, color: _muted),
                      ),
                    if (c.phone.isNotEmpty)
                      pw.Row(
                        children: [
                          pw.Text(
                            'هاتف: ',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: _muted,
                            ),
                          ),
                          _ltr(
                            c.phone,
                            const pw.TextStyle(fontSize: 9, color: _muted),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  kv(
                    inv.type.partyLabel,
                    inv.partyName.isEmpty ? '-' : inv.partyName,
                  ),
                  if (inv.partyPhone.isNotEmpty)
                    kv('الهاتف', inv.partyPhone, ltr: true),
                  kv('التاريخ', fmt.date(inv.date), ltr: true),
                  kv(
                    'أُنشئت في',
                    '${fmt.date(generated)} '
                        '${generated.hour.toString().padLeft(2, '0')}:'
                        '${generated.minute.toString().padLeft(2, '0')}',
                    ltr: true,
                  ),
                  kv('المرجع', inv.number, ltr: true),
                ],
              ),
            ],
          ),
        ),
        pw.Container(height: 1.2, color: _headBorder),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تفاصيل ${inv.type.label}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  pill('النوع', inv.type.label),
                  pill('الأصناف', '${inv.lines.length}'),
                  pill('المخزن', warehouseName),
                  pill('الإجمالي المستحق', fmt.money(inv.total)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------- جدول الأصناف ----------

const _headStyle = pw.TextStyle(fontSize: 8.5, color: _ink);

pw.Widget _cell(
  pw.Widget child, {
  pw.Alignment align = pw.Alignment.topRight,
}) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  alignment: align,
  child: child,
);

pw.Widget _headCell(String text, {bool end = false}) => _cell(
  pw.Text(text, style: _headStyle.copyWith(fontWeight: pw.FontWeight.bold)),
  align: end ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
);

pw.Widget _amount(String text, {bool bold = true}) => _cell(
  pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 9.5,
      fontWeight: bold ? pw.FontWeight.bold : null,
    ),
  ),
  align: pw.Alignment.topLeft,
);

pw.Widget _linesCard(Invoice inv, Product? Function(String) productOf) {
  pw.Widget thumb(Product p) => pw.Container(
    margin: const pw.EdgeInsetsDirectional.only(end: 8),
    padding: const pw.EdgeInsets.all(1.5),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _line),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 5,
      verticalRadius: 5,
      child: pw.Image(
        pw.MemoryImage(productImageBytes(p.image!)),
        width: 46,
        height: 46,
        fit: pw.BoxFit.cover,
      ),
    ),
  );

  pw.Widget description(Product? p, InvoiceLine l) => _cell(
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (p?.image != null) thumb(p!),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  if (p != null && p.code.isNotEmpty) ...[
                    _badge(p.code, _sky),
                    pw.SizedBox(width: 4),
                  ],
                  _badge(
                    inv.type == InvoiceType.sale ? 'بيع' : 'شراء',
                    inv.type == InvoiceType.sale ? _green : _amber,
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                p?.name ?? '-',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${fmt.number(l.qty)} ${p?.unit ?? ''} × ${fmt.money(l.unitPrice)}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _gridHead),
      children: [
        _headCell('#'),
        _headCell('الصنف'),
        _headCell('الكمية', end: true),
        _headCell('سعر الوحدة', end: true),
        _headCell('الإجمالي', end: true),
      ],
    ),
    for (final (i, l) in inv.lines.indexed)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isOdd ? _rowTint : PdfColors.white,
          border: const pw.Border(top: pw.BorderSide(color: _line)),
        ),
        children: [
          _cell(
            pw.Text(
              '${i + 1}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          description(productOf(l.productId), l),
          _amount(
            '${fmt.number(l.qty)} ${productOf(l.productId)?.unit ?? ''}',
            bold: false,
          ),
          _amount(fmt.money(l.unitPrice), bold: false),
          _amount(fmt.money(l.total)),
        ],
      ),
  ];

  return _card(
    pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(1.7),
      },
      children: rows,
    ),
  );
}

// ---------- الملخص ----------

pw.Widget _summaryCard(Invoice inv) {
  pw.TableRow row(
    _Tone tone,
    String badge,
    String label,
    String amount, {
    bool last = false,
  }) => pw.TableRow(
    decoration: pw.BoxDecoration(
      color: last ? _gridSub : PdfColors.white,
      border: const pw.Border(top: pw.BorderSide(color: _line)),
    ),
    children: [
      _cell(_badge(badge, tone), align: pw.Alignment.centerRight),
      _cell(
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: last ? pw.FontWeight.bold : null,
          ),
        ),
        align: pw.Alignment.centerRight,
      ),
      _cell(
        pw.Text(
          amount,
          style: pw.TextStyle(
            fontSize: last ? 11 : 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        align: pw.Alignment.centerLeft,
      ),
    ],
  );

  return _card(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _gridHead,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            'الإجماليات / الملخص',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.3),
            1: pw.FlexColumnWidth(3.5),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: _gridSub,
                border: pw.Border(top: pw.BorderSide(color: _cardBorder)),
              ),
              children: [
                _headCell('النوع'),
                _headCell('البيان'),
                _headCell('المبلغ', end: true),
              ],
            ),
            row(
              _indigo,
              'المجموع',
              'مجموع الأصناف (${inv.lines.length})',
              fmt.money(inv.subtotal),
            ),
            if (inv.discount > 0)
              row(_amber, 'خصم', 'الخصم', '- ${fmt.money(inv.discount)}'),
            if (inv.taxPercent > 0)
              row(
                _green,
                'ضريبة',
                'ضريبة القيمة المضافة (${fmt.percent(inv.taxPercent)})',
                fmt.money(inv.tax),
              ),
            row(
              _sky,
              'نهائي',
              'الإجمالي المستحق',
              fmt.money(inv.total),
              last: true,
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _notesCard(String notes) => _card(
  pw.Padding(
    padding: const pw.EdgeInsets.all(12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ملاحظات',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 9.5)),
      ],
    ),
  ),
);

// ---------- حسابات الدفع ----------

pw.Widget _accountCards(List<PaymentAccount> accounts, Invoice inv) {
  final mono = pw.TextStyle(
    font: pw.Font.courierBold(),
    fontSize: 10.5,
    letterSpacing: .5,
  );

  pw.Widget field(String label, pw.Widget value, {bool last = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: last
            ? null
            : const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: _line,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
              ),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 74,
              child: pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8.5, color: _muted),
              ),
            ),
            pw.Expanded(child: value),
          ],
        ),
      );

  pw.Widget card(PaymentAccount a) {
    final code = a.name.replaceAll(' ', '');
    final initials = (code.length > 2 ? code.substring(0, 2) : code)
        .toUpperCase();
    return pw.Container(
      width: 262,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _cardBorder, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 7,
        verticalRadius: 7,
        // الشريط الأزرق على جانب البداية (اليمين في العربية).
        child: pw.Container(
          // الحشوة تُبقي الشريط ظاهراً بجانب رأس البطاقة الملوّن أيضاً.
          padding: const pw.EdgeInsets.only(right: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: _blue, width: 4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                color: _rowTint,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 26,
                      height: 22,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        color: _blue,
                        borderRadius: pw.BorderRadius.all(
                          pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Text(
                        initials,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    _ltr(
                      a.name,
                      pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(height: 1, color: _line),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Column(
                  children: [
                    field('رقم الحساب', _ltr(a.number, mono)),
                    field(
                      'مرجع الدفع',
                      _ltr(inv.number, const pw.TextStyle(fontSize: 9.5)),
                      last: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return pw.Wrap(
    spacing: 14,
    runSpacing: 12,
    children: [for (final a in accounts) card(a)],
  );
}

// ---------- التذييل ----------

pw.Widget _footer(pw.Context ctx, Invoice inv, CompanyInfo c) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 12),
  padding: const pw.EdgeInsets.only(top: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: _line)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        '© ${DateTime.now().year} ${c.name} — شكراً لتعاملكم معنا',
        style: pw.TextStyle(
          fontSize: 8.5,
          color: _muted,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.Row(
        children: [
          _ltr(
            inv.number,
            pw.TextStyle(
              fontSize: 8.5,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '  •  صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
      ),
    ],
  ),
);
