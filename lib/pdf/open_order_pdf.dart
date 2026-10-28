import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/open_order.dart';
import '../state/app_state.dart';
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
const _blue = PdfColor.fromInt(0xFF274C86);

/// كشف الفاتورة المفتوحة: الملخص، ثم لكل مخزن أصنافه (الأصلية والمأخوذ
/// والمتبقي) وسجل ما أُخذ منه، ثم سجل الدفع.
Future<Uint8List> buildOpenOrderPdf({
  required OpenOrder order,
  required AppState s,
  bool showWarehouses = false,
  DateTime? issued,
}) async {
  final printedOn = issued ?? DateTime.now();
  final o = order;
  final company = s.company;
  final doc = pw.Document(
    title: 'فاتورة مفتوحة ${o.number}',
    author: company.name,
    theme: await loadPdfTheme(),
  );
  String name(String id) => s.productById(id)?.name ?? 'صنف محذوف';
  String unit(String id) => s.productById(id)?.unit ?? '';
  String whName(String id) => s.warehouseById(id)?.name ?? '-';

  // صورة كل صنف تُحمَّل مرة واحدة في الملف وإن تكررت.
  final images = <String, pw.MemoryImage?>{};
  pw.Widget? thumb(String pid, double size) {
    final img = images.putIfAbsent(pid, () {
      final data = s.productById(pid)?.image;
      if (data == null) return null;
      try {
        return pw.MemoryImage(productImageBytes(data));
      } catch (_) {
        return null;
      }
    });
    if (img == null) return null;
    return pw.Container(
      padding: const pw.EdgeInsets.all(1),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Image(img, width: size, height: size, fit: pw.BoxFit.cover),
      ),
    );
  }

  final pickups = s.pickupsOf(o.id);
  // نسخة الزبون لا تذكر المخازن حتى في وصف ما دُفع عنه.
  final payments = s.orderPayments(o, withWarehouse: showWarehouses);
  final paid = s.orderPaid(o);
  final credit = s.orderCredit(o.id);
  final taken = o.lines.fold<double>(
    0,
    (a, l) => a + l.qty - s.remainingInOrder(o, l.productId, at: o.whOf(l)),
  );
  final takenValue = s.orderTakenValue(o);
  final units = {for (final l in o.lines) unit(l.productId)};
  String q(double v) => units.length == 1
      ? '${fmt.number(v)} ${units.first}'.trim()
      : fmt.number(v);

  // نسخة الزبون بلا مخازن: مجموعة واحدة لكل الأصناف (المخزن null).
  final groups = showWarehouses
      ? <String?>[...o.warehouseIds]
      : <String?>[null];
  String keyOf(String pid, String? w) => showWarehouses ? '$pid|$w' : pid;

  // الباقي من كل صنف (في كل مخزن للمدير) بعد كل أخذ.
  final left = <String, double>{};
  for (final l in o.lines) {
    final k = keyOf(l.productId, o.whOf(l));
    left[k] = (left[k] ?? 0) + l.qty;
  }
  final leftAfter = <String, Map<String, double>>{};
  for (final i in pickups) {
    for (final l in i.lines) {
      final k = keyOf(l.productId, i.warehouseId);
      left[k] = (left[k] ?? 0) - l.qty;
    }
    leftAfter[i.id] = {...left};
  }

  final sections = <pw.Widget>[];
  for (final w in groups) {
    // الأصناف: للزبون يُجمع الصنف الواحد من كل المخازن في سطر.
    final rows = <String, ({String pid, double qty, double price})>{};
    for (final l in o.lines) {
      if (w != null && o.whOf(l) != w) continue;
      final k = '${l.productId}|${l.unitPrice}';
      final prev = rows[k];
      rows[k] = (
        pid: l.productId,
        qty: (prev?.qty ?? 0) + l.qty,
        price: l.unitPrice,
      );
    }
    double remaining(String pid) => s.remainingInOrder(o, pid, at: w);
    final from = [
      for (final i in pickups)
        if (w == null || i.warehouseId == w) i,
    ];
    final grpQty = rows.values.fold<double>(0, (a, r) => a + r.qty);
    final grpLeft = {for (final r in rows.values) r.pid}
        .fold<double>(0, (a, pid) => a + remaining(pid));
    sections.addAll([
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: _blue,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                w == null ? 'الأصناف' : whName(w),
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Text(
              'الأصلية ${q(grpQty)} • المأخوذ ${q(grpQty - grpLeft)} • '
              'المتبقي ${q(grpLeft)}',
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      _row(
        ['الصنف', 'الوحدة', 'السعر', 'الأصلية', 'المأخوذ', 'المتبقي', 'القيمة'],
        const [4, 2, 3, 2, 2, 2, 3],
        head: true,
      ),
      for (final r in rows.values)
        () {
          // المتبقي لسطر بسعر واحد: لا يتجاوز كميته.
          final rem = remaining(r.pid).clamp(0.0, r.qty);
          return _row(
            [
              name(r.pid),
              unit(r.pid),
              fmt.money(r.price),
              fmt.number(r.qty),
              fmt.number(r.qty - rem),
              fmt.number(rem),
              fmt.money(r.qty * r.price),
            ],
            const [4, 2, 3, 2, 2, 2, 3],
            lead: {0: thumb(r.pid, 30)},
          );
        }(),
      pw.SizedBox(height: 8),
      _sub(w == null ? 'ما أخذه الزبون' : 'ما أخذه الزبون من ${whName(w)}'),
      if (from.isEmpty)
        pw.Text(
          'لم يأخذ شيئاً بعد',
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        )
      else ...[
        _row(
          ['#', 'التاريخ', 'الفاتورة', 'الصنف', 'أخذ', 'بقي بعدها', 'القيمة'],
          const [1, 3, 2, 4, 2, 2, 3],
          head: true,
          light: true,
        ),
        for (final (n, i) in from.indexed)
          for (final (k, l) in i.lines.indexed)
            _row(
              [
                k == 0 ? '${n + 1}' : '',
                k == 0 ? fmt.date(i.date) : '',
                k == 0 ? i.number : '',
                name(l.productId),
                '${fmt.number(l.qty)} ${unit(l.productId)}',
                fmt.number(
                  leftAfter[i.id]?[keyOf(l.productId, i.warehouseId)] ?? 0,
                ),
                fmt.money(l.total),
              ],
              const [1, 3, 2, 4, 2, 2, 3],
              lead: {3: thumb(l.productId, 16)},
            ),
      ],
    ]);
  }

  var running = 0.0;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(26),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${company.name} • ${company.address} • ${company.phone}'
          ' • ${fmt.date(printedOn)} • ${ctx.pageNumber}/${ctx.pagesCount}',
          textDirection: pw.TextDirection.rtl,
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
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.name,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
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
                        'فاتورة مفتوحة',
                        textDirection: pw.TextDirection.rtl,
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
              pw.Text(
                o.number,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _box('الزبون', o.partyName),
            _box('الهاتف', o.partyPhone),
            _box('تاريخ الفاتورة', fmt.date(o.date)),
            _box('تاريخ الكشف', fmt.date(printedOn)),
            _box('الحالة', s.isOrderComplete(o) ? 'مكتملة' : 'جارية'),
          ],
        ),
        pw.Row(
          children: [
            _box('المبلغ الكلي', fmt.money(o.total), color: _blue),
            _box('المدفوع', fmt.money(paid), color: _green),
            _box('الباقي من المبلغ', fmt.money(o.total - paid), color: _red),
            _box('قيمة ما أخذه', fmt.money(takenValue)),
          ],
        ),
        pw.Row(
          children: [
            _box('الكمية الكلية', q(o.totalQty), color: _blue),
            _box('المأخوذ', q(taken), color: _green),
            _box(
              showWarehouses ? 'المتبقي في المخازن' : 'المتبقي له',
              q(o.totalQty - taken),
              color: _red,
            ),
            if (credit > 1e-9)
              _box('رصيد مدفوع مقدماً', fmt.money(credit), color: _green)
            else if (showWarehouses)
              _box('المخازن', o.warehouseIds.map(whName).join('، '))
            else
              _box(
                'عدد الأصناف',
                '${{for (final l in o.lines) l.productId}.length}',
              ),
          ],
        ),
        ...sections,
        pw.SizedBox(height: 14),
        _title('سجل الدفع'),
        if (payments.isEmpty)
          pw.Text(
            'لم يدفع الزبون شيئاً بعد',
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          )
        else ...[
          _row(
            [
              '#',
              'التاريخ',
              'البيان وعن أي بضاعة',
              'المبلغ',
              'المدفوع حتى الآن',
              'الباقي',
            ],
            const [1, 3, 8, 3, 3, 3],
            head: true,
          ),
          for (final (n, p) in payments.indexed) ...[
            () {
              running += p.amount;
              return _row(
                [
                  '${n + 1}',
                  fmt.date(p.date),
                  p.source,
                  fmt.money(p.amount),
                  fmt.money(running),
                  fmt.money(o.total - running),
                ],
                const [1, 3, 8, 3, 3, 3],
              );
            }(),
            // كل بضاعة دُفع عنها في سطر مستقل: الفاتورة، البضاعة، المبلغ.
            for (final g in p.goods)
              _row(
                [
                  '',
                  g.ref,
                  g.what,
                  g.amount == null ? '' : fmt.money(g.amount!),
                  '',
                  '',
                ],
                const [1, 3, 8, 3, 3, 3],
                sub: true,
              ),
          ],
        ],
        if (company.paymentAccounts.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _title('حسابات الدفع'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in company.paymentAccounts)
                pw.Container(
                  width: 128,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: _panel,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: _line),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        a.name,
                        textDirection: _dir(a.name),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _blue,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'رقم الحساب',
                        textDirection: pw.TextDirection.rtl,
                        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                      ),
                      pw.Text(
                        a.number,
                        textDirection: pw.TextDirection.ltr,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'مرجع الدفع: ${o.number}',
                        textDirection: pw.TextDirection.rtl,
                        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (o.notes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _title('ملاحظات'),
          pw.Text(o.notes, textDirection: _dir(o.notes)),
        ],
        pw.SizedBox(height: 36),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _sign('توقيع الزبون'),
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
    textDirection: pw.TextDirection.rtl,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _brand,
    ),
  ),
);

pw.Widget _sub(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Text(
    t,
    textDirection: pw.TextDirection.rtl,
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: _blue,
    ),
  ),
);

pw.Widget _box(String label, String value, {PdfColor? color}) => pw.Expanded(
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
        pw.Text(
          label,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.Text(
          value.isEmpty ? '-' : value,
          textDirection: _dir(value),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  ),
);

pw.Widget _row(
  List<String> cells,
  List<int> flex, {
  bool head = false,
  bool light = false,
  bool sub = false,
  Map<int, pw.Widget?> lead = const {},
}) {
  final style = pw.TextStyle(
    fontSize: head ? 9 : (sub ? 7.5 : 8.5),
    fontWeight: head ? pw.FontWeight.bold : null,
    color: head && !light
        ? PdfColors.white
        : (head ? _brand : (sub ? _blue : null)),
  );
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: sub ? 2 : 5),
    decoration: pw.BoxDecoration(
      color: head ? (light ? _panel : _brand) : null,
      border: head || sub
          ? null
          : const pw.Border(bottom: pw.BorderSide(color: _line)),
    ),
    child: pw.Row(
      children: [
        for (final (i, c) in cells.indexed)
          pw.Expanded(
            flex: flex[i],
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: lead[i] == null
                  ? pw.Text(
                      c,
                      style: style,
                      textDirection: _dir(c),
                      textAlign: pw.TextAlign.right,
                    )
                  // صورة الصنف بجانب اسمه.
                  : pw.Row(
                      children: [
                        lead[i]!,
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: pw.Text(
                            c,
                            style: style,
                            textDirection: _dir(c),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _sign(String label) => pw.Column(
  children: [
    pw.Container(width: 150, height: 1, color: _muted),
    pw.SizedBox(height: 4),
    pw.Text(
      label,
      textDirection: pw.TextDirection.rtl,
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  ],
);
