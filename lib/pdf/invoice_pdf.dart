import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/inventory.dart';
import '../models/invoice.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';
import 'invoice_strings.dart';

export 'invoice_strings.dart' show InvoiceLanguage;

// ألوان التصميم: رأس أزرق فاتح، رأس جدول أزرق، وبطاقات بيضاء بحواف ناعمة.
const _ink = PdfColor.fromInt(0xFF111827);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _blue = PdfColor.fromInt(0xFF1D4ED8);
const _blueDark = PdfColor.fromInt(0xFF2B5BC9);
const _blueLight = PdfColor.fromInt(0xFF4A7BE3);
const _headTop = PdfColor.fromInt(0xFFEAF0FB);
const _headBottom = PdfColor.fromInt(0xFFF6F8FE);
const _headBorder = PdfColor.fromInt(0xFFD5DFF3);
const _panel = PdfColor.fromInt(0xFFF3F6FC);
const _panelHead = PdfColor.fromInt(0xFFE4EAF5);
const _rowTint = PdfColor.fromInt(0xFFF1F4FA);
const _line = PdfColor.fromInt(0xFFE3E7EF);
const _cardBorder = PdfColor.fromInt(0xFFD9DEE8);

/// لون الشارات والمربعات: نص/إطار وخلفية.
typedef _Tone = ({PdfColor fg, PdfColor bg, PdfColor border});
const _toneBlue = (
  fg: PdfColor.fromInt(0xFF1D4ED8),
  bg: PdfColor.fromInt(0xFFEAF1FE),
  border: PdfColor.fromInt(0xFF9DB7EE),
);
const _toneGreen = (
  fg: PdfColor.fromInt(0xFF15803D),
  bg: PdfColor.fromInt(0xFFEAF7EE),
  border: PdfColor.fromInt(0xFF9FD8B0),
);
const _toneAmber = (
  fg: PdfColor.fromInt(0xFFA16207),
  bg: PdfColor.fromInt(0xFFFFF6D6),
  border: PdfColor.fromInt(0xFFE9C46A),
);
const _toneRed = (
  fg: PdfColor.fromInt(0xFFB91C1C),
  bg: PdfColor.fromInt(0xFFFDECEC),
  border: PdfColor.fromInt(0xFFF1A7A7),
);

/// رموز أيقونات Material الموجودة في assets/fonts/InvoiceIcons.ttf.
abstract final class _Icons {
  static const invoice = pw.IconData(0xf2ef); // receipt_long_outlined
  static const calendar = pw.IconData(0xef11); // calendar_today_outlined
  static const person = pw.IconData(0xe497); // person_outline
  static const phone = pw.IconData(0xf290); // phone_outlined
  static const clock = pw.IconData(0xf339); // schedule_outlined
  static const store = pw.IconData(0xf3ee); // store_outlined
  static const box = pw.IconData(0xf134); // inventory_2_outlined
  static const money = pw.IconData(0xf266); // payments_outlined
  static const check = pw.IconData(0xe159); // check_circle
  static const alert = pw.IconData(0xe238); // error_outline
  static const chart = pw.IconData(0xe0cc); // bar_chart
  static const card = pw.IconData(0xe19f); // credit_card
}

pw.ThemeData? _theme;

/// يحمّل خط Readex Pro وخط الأيقونات مرة واحدة؛ خطوط PDF الافتراضية لا تدعم العربية.
/// نوسّع مسافة الكلمات قليلاً لتتضح الكلمات العربية.
Future<pw.ThemeData> _loadTheme() async {
  if (_theme != null) return _theme!;
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(
      await rootBundle.load('assets/fonts/ReadexPro-Regular.ttf'),
    ),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/ReadexPro-Bold.ttf')),
    icons: pw.Font.ttf(await rootBundle.load('assets/fonts/InvoiceIcons.ttf')),
  );
  return _theme = theme.copyWith(
    defaultTextStyle: theme.defaultTextStyle.copyWith(
      wordSpacing: 1.3,
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

  /// الدين المتبقي الآن (بعد أي تسديدات)؛ افتراضياً دين الفاتورة عند إصدارها.
  double? remainingDebt,

  /// لغة نصوص الفاتورة؛ العربية افتراضياً.
  InvoiceLanguage language = InvoiceLanguage.ar,
}) async {
  final t = language.strings;
  final rtl = language.rtl;
  final debt = remainingDebt ?? invoice.debt;
  final doc = pw.Document(
    title: '${t.title(invoice.type)} ${invoice.number}',
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
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 18),
      footer: (ctx) => _footer(ctx, t, invoice, company),
      build: (_) => [
        _headerCard(t, invoice, company, generated),
        pw.SizedBox(height: 8),
        _statsCard(t, rtl, invoice, warehouseName, debt),
        pw.SizedBox(height: 8),
        _linesCard(t, rtl, invoice, productOf),
        pw.SizedBox(height: 8),
        pw.Inseparable(child: _summaryCard(t, invoice, debt)),
        if (invoice.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Inseparable(child: _notesCard(t, invoice.notes)),
        ],
        if (accounts.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          // العنوان والبطاقات معاً حتى لا يبقى العنوان وحده آخر الصفحة.
          pw.Inseparable(child: _accountsCard(t, accounts, invoice)),
        ],
      ],
    ),
  );
  return doc.save();
}

// ---------- عناصر مشتركة ----------

/// الأرقام والرموز اللاتينية تُعرض من اليسار لليمين داخل النص العربي.
final _arabic = RegExp(r'[\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF]');

/// بيانات المستخدم (الأسماء، الأصناف، الوحدات) قد تكون عربية حتى في فاتورة
/// فرنسية أو إنجليزية؛ مكتبة pdf لا تصل الحروف العربية إلا في اتجاه RTL.
pw.TextDirection? _dir(String text) =>
    _arabic.hasMatch(text) ? pw.TextDirection.rtl : null;

pw.Widget _ltr(String text, pw.TextStyle style) =>
    pw.Text(text, style: style, textDirection: pw.TextDirection.ltr);

pw.Widget _icon(
  pw.IconData icon, {
  double size = 14,
  PdfColor color = _muted,
}) => pw.Icon(icon, size: size, color: color);

/// بطاقة بيضاء بحواف مستديرة.
pw.Widget _card(
  pw.Widget child, {
  PdfColor color = PdfColors.white,
  PdfColor border = _cardBorder,
  pw.EdgeInsets padding = const pw.EdgeInsets.all(10),
}) => pw.Container(
  padding: padding,
  decoration: pw.BoxDecoration(
    color: color,
    border: pw.Border.all(color: border),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
  ),
  child: child,
);

/// عنوان قسم بمربع أيقونة أزرق كما في التصميم.
pw.Widget _sectionTitle(pw.IconData icon, String text) => pw.Row(
  children: [
    pw.Container(
      width: 24,
      height: 24,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: _blue,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: _icon(icon, size: 14, color: PdfColors.white),
    ),
    pw.SizedBox(width: 8),
    pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  ],
);

/// شارة بإطار ملون وعرض ثابت حتى تصطف الشارات تحت بعضها.
pw.Widget _badge(String text, _Tone tone, {double? width}) => pw.Container(
  width: width,
  height: 20,
  alignment: pw.Alignment.center,
  padding: const pw.EdgeInsets.symmetric(horizontal: 10),
  decoration: pw.BoxDecoration(
    color: tone.bg,
    border: pw.Border.all(color: tone.fg),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 9,
      color: tone.fg,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

// ---------- الرأس ----------

pw.Widget _headerCard(
  InvoiceStrings t,
  Invoice inv,
  CompanyInfo c,
  DateTime generated,
) {
  const label = pw.TextStyle(fontSize: 10, color: _muted);
  final value = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

  // سطر في مربع بيانات الفاتورة: أيقونة، عنوان، ثم القيمة في الطرف الآخر.
  pw.Widget detail(
    pw.IconData icon,
    String k,
    String v, {
    bool ltr = false,
    bool last = false,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    decoration: last
        ? null
        : const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
    child: pw.Row(
      children: [
        _icon(icon, size: 13),
        pw.SizedBox(width: 6),
        pw.Text(k, style: label),
        pw.Spacer(),
        ltr ? _ltr(v, value) : pw.Text(v, style: value, textDirection: _dir(v)),
      ],
    ),
  );

  final initial = c.name.trim().isEmpty ? 'م' : c.name.trim()[0];
  final time =
      '${generated.hour.toString().padLeft(2, '0')}:'
      '${generated.minute.toString().padLeft(2, '0')}';
  final title = t.title(inv.type);

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(
        colors: [_headTop, _headBottom],
        begin: pw.Alignment.topCenter,
        end: pw.Alignment.bottomCenter,
      ),
      border: pw.Border.all(color: _headBorder),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 56,
          height: 56,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Text(
            initial,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                c.name,
                textDirection: _dir(c.name),
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 15,
                  color: _blue,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (c.address.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text(
                      '${t.address} : ',
                      style: const pw.TextStyle(fontSize: 11, color: _muted),
                    ),
                    pw.Text(
                      c.address,
                      textDirection: _dir(c.address),
                      style: const pw.TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              if (c.phone.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text(
                      '${t.phone} : ',
                      style: const pw.TextStyle(fontSize: 11, color: _muted),
                    ),
                    _ltr(
                      c.phone,
                      const pw.TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(
            children: [
              detail(_Icons.invoice, t.invoiceNumber, inv.number, ltr: true),
              detail(_Icons.calendar, t.date, fmt.date(inv.date), ltr: true),
              detail(
                _Icons.person,
                t.party(inv.type),
                inv.partyName.isEmpty ? '-' : inv.partyName,
              ),
              if (inv.partyPhone.isNotEmpty)
                detail(_Icons.phone, t.phone, inv.partyPhone, ltr: true),
              detail(
                _Icons.clock,
                t.createdAt,
                '${fmt.date(generated)}  $time',
                ltr: true,
                last: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------- مربعات الملخص السريع ----------

pw.Widget _statsCard(
  InvoiceStrings t,
  bool rtl,
  Invoice inv,
  String warehouseName,
  double debt,
) {
  pw.Widget tile(
    pw.IconData icon,
    String label,
    String value, {
    _Tone? tone,
    bool filledIcon = false,
  }) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color: tone?.bg ?? PdfColors.white,
        border: pw.Border.all(color: tone?.border ?? _cardBorder),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 30,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: filledIcon ? tone?.fg ?? _blue : PdfColors.white,
              border: filledIcon
                  ? null
                  : pw.Border.all(color: tone?.border ?? _cardBorder),
            ),
            child: _icon(
              icon,
              size: filledIcon ? 17 : 15,
              color: filledIcon ? PdfColors.white : tone?.fg ?? _ink,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 9.5, color: tone?.fg ?? _muted),
                ),
                pw.SizedBox(height: 2),
                // القيمة في سطر واحد، تُصغَّر إن طالت.
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: rtl
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
                  child: pw.Text(
                    value,
                    maxLines: 1,
                    textDirection: _dir(value),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: tone?.fg ?? _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  final hasDebt = debt > 0.0001;
  return _card(
    pw.Row(
      children: [
        tile(_Icons.store, t.warehouse, warehouseName),
        pw.SizedBox(width: 8),
        tile(_Icons.box, t.itemCount, '${inv.lines.length}'),
        pw.SizedBox(width: 8),
        tile(
          _Icons.money,
          t.total,
          t.money(inv.total),
          tone: _toneBlue,
          filledIcon: true,
        ),
        pw.SizedBox(width: 8),
        tile(
          hasDebt ? _Icons.alert : _Icons.check,
          t.debt,
          t.money(debt),
          tone: hasDebt ? _toneRed : _toneGreen,
          filledIcon: true,
        ),
      ],
    ),
  );
}

// ---------- جدول الأصناف ----------

pw.Widget _linesCard(
  InvoiceStrings t,
  bool rtl,
  Invoice inv,
  Product? Function(String) productOf,
) {
  const headStyle = pw.TextStyle(fontSize: 10.5, color: PdfColors.white);
  // الأعمدة بترتيب القراءة: الصنف، الكمية، سعر الفرد، الإجمالي، الرقم.
  List<T> inOrder<T>(List<T> cells) => rtl ? cells.reversed.toList() : cells;
  const sep = pw.BorderSide(color: _line);

  pw.Widget head(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: pw.Center(
      child: pw.Text(
        t,
        style: headStyle.copyWith(fontWeight: pw.FontWeight.bold),
      ),
    ),
  );

  pw.Widget value(String t, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: pw.Center(
      child: pw.Text(
        t,
        textDirection: _dir(t),
        style: pw.TextStyle(
          fontSize: bold ? 11.5 : 10.5,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    ),
  );

  pw.Widget thumb(Product p) => pw.Container(
    margin: const pw.EdgeInsetsDirectional.only(end: 10),
    padding: const pw.EdgeInsets.all(2),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _line),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 6,
      verticalRadius: 6,
      child: pw.Image(
        pw.MemoryImage(productImageBytes(p.image!)),
        width: 48,
        height: 48,
        fit: pw.BoxFit.cover,
      ),
    ),
  );

  pw.Widget description(Product? p, InvoiceLine l) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: pw.Row(
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
                    _badge(p.code, _toneBlue),
                    pw.SizedBox(width: 6),
                  ],
                  _badge(
                    t.kind(inv.type),
                    inv.type == InvoiceType.sale ? _toneGreen : _toneAmber,
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                p?.name ?? '-',
                textDirection: _dir(p?.name ?? ''),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Row(
                children: [
                  pw.Text(
                    '${fmt.number(l.qty)} ${p?.unit ?? ''}',
                    textDirection: _dir(p?.unit ?? ''),
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                  pw.Text(
                    ' × ${t.money(l.unitPrice)}',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _cardBorder),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 11,
      verticalRadius: 11,
      child: pw.Table(
        border: const pw.TableBorder(
          verticalInside: sep,
          horizontalInside: sep,
        ),
        // جدول pdf لا يدعم الاتجاه من اليمين لليسار؛ الأعمدة تُرتَّب دائماً من
        // اليسار، فنعكسها في العربية ليظهر الصنف يميناً والرقم يساراً.
        columnWidths: {
          for (final (i, w) in inOrder(const [4.2, 1.3, 1.5, 1.8, 0.5]).indexed)
            i: pw.FlexColumnWidth(w),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [_blueLight, _blueDark]),
            ),
            children: inOrder([
              head(t.item),
              head(t.quantity),
              head(t.unitPrice),
              head(t.lineTotal),
              head('#'),
            ]),
          ),
          for (final (i, l) in inv.lines.indexed)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: i.isOdd ? _rowTint : PdfColors.white,
              ),
              children: inOrder([
                description(productOf(l.productId), l),
                value(
                  '${fmt.number(l.qty)} ${productOf(l.productId)?.unit ?? ''}',
                ),
                value(t.money(l.unitPrice)),
                value(t.money(l.total), bold: true),
                value('${i + 1}', bold: true),
              ]),
            ),
        ],
      ),
    ),
  );
}

// ---------- الملخص ----------

pw.Widget _summaryCard(InvoiceStrings t, Invoice inv, double debt) {
  // ثلاثة أعمدة: النوع (شارة)، البيان، المبلغ.
  pw.Widget line(
    pw.Widget type,
    pw.Widget label,
    pw.Widget amount, {
    PdfColor color = PdfColors.white,
  }) => pw.Container(
    color: color,
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 100, child: pw.Row(children: [type])),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 3, child: label),
        pw.Expanded(
          flex: 2,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [amount],
          ),
        ),
      ],
    ),
  );

  pw.Widget row(
    _Tone tone,
    String badge,
    String label,
    String amount, {
    bool strong = false,
    PdfColor? color,
  }) => line(
    _badge(badge, tone, width: 96),
    pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: strong ? 12 : 11,
        fontWeight: strong ? pw.FontWeight.bold : null,
      ),
    ),
    pw.Text(
      amount,
      style: pw.TextStyle(
        fontSize: strong ? 13 : 11.5,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    ),
    color: strong ? _rowTint : PdfColors.white,
  );

  pw.Widget head(String t) => pw.Text(
    t,
    style: pw.TextStyle(
      fontSize: 10,
      color: _muted,
      fontWeight: pw.FontWeight.bold,
    ),
  );

  final hasDebt = debt > 0.0001;
  final debtTone = hasDebt ? _toneRed : _toneGreen;
  return _card(
    color: _panel,
    border: _headBorder,
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(_Icons.chart, t.summary),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: _line),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 7,
            verticalRadius: 7,
            child: pw.Column(
              children: [
                line(
                  head(t.type),
                  head(t.description),
                  head(t.amount),
                  color: _panelHead,
                ),
                row(
                  _toneBlue,
                  t.subtotalBadge,
                  t.subtotalLabel(inv.lines.length),
                  t.money(inv.subtotal),
                ),
                if (inv.discount > 0)
                  row(
                    _toneAmber,
                    t.discountBadge,
                    t.discount,
                    '- ${t.money(inv.discount)}',
                  ),
                row(
                  _toneBlue,
                  t.totalBadge,
                  t.totalDue,
                  t.money(inv.total),
                  strong: true,
                ),
                row(_toneGreen, t.paidBadge, t.paid, t.money(inv.total - debt)),
                row(
                  debtTone,
                  t.debtBadge,
                  hasDebt ? t.remainingDebt : t.noDebt,
                  t.money(debt),
                  strong: true,
                  color: debtTone.fg,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _notesCard(InvoiceStrings t, String notes) => _card(
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        t.notes,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        notes,
        textDirection: _dir(notes),
        style: const pw.TextStyle(fontSize: 10),
      ),
    ],
  ),
  padding: const pw.EdgeInsets.all(12),
);

// ---------- حسابات الدفع ----------

pw.Widget _accountsCard(
  InvoiceStrings t,
  List<PaymentAccount> accounts,
  Invoice inv,
) {
  final mono = pw.TextStyle(font: pw.Font.courier(), fontSize: 11);
  const label = pw.TextStyle(fontSize: 9.5, color: _muted);

  pw.Widget field(String k, pw.Widget v, {bool last = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: last
        ? null
        : const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _line, style: pw.BorderStyle.dashed),
            ),
          ),
    child: pw.Row(
      children: [
        pw.Text(k, style: label),
        pw.Spacer(),
        v,
      ],
    ),
  );

  pw.Widget card(PaymentAccount a) {
    final code = a.name.replaceAll(' ', '');
    final initials = (code.length > 2 ? code.substring(0, 2) : code)
        .toUpperCase();
    return pw.Container(
      width: 256,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _cardBorder),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 30,
                height: 26,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  color: _blue,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  initials,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              _ltr(
                a.name,
                pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 1, color: _line),
          field(t.accountNumber, _ltr(a.number, mono)),
          field(
            t.paymentReference,
            _ltr(inv.number, const pw.TextStyle(fontSize: 10.5)),
            last: true,
          ),
        ],
      ),
    );
  }

  return _card(
    padding: const pw.EdgeInsets.all(10),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(_Icons.card, t.paymentMethods),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final a in accounts) card(a)],
        ),
      ],
    ),
  );
}

// ---------- التذييل ----------

pw.Widget _footer(
  pw.Context ctx,
  InvoiceStrings t,
  Invoice inv,
  CompanyInfo c,
) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 10),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(
        children: [
          pw.Text(
            '© ${DateTime.now().year} ',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.Text(
            c.name,
            textDirection: _dir(c.name),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.Text(
            ' - ${t.thanks}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
      pw.Row(
        children: [
          _ltr(
            inv.number,
            pw.TextStyle(
              fontSize: 9,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '  •  ${t.page(ctx.pageNumber, ctx.pagesCount)}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    ],
  ),
);
