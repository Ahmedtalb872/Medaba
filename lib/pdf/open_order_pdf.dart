import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/open_order.dart';
import '../state/app_state.dart';
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
const _blue = PdfColor.fromInt(0xFF274C86);

/// كشف الفاتورة المفتوحة: الملخص، ثم لكل مخزن أصنافه (الأصلية والمأخوذ
/// والمتبقي) وسجل ما أُخذ منه، ثم سجل الدفع.
Future<Uint8List> buildOpenOrderPdf({
  required OpenOrder order,
  required AppState s,
}) async {
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

  final pickups = s.pickupsOf(o.id);
  final payments = s.orderPayments(o);
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

  // الباقي من كل صنف في كل مخزن بعد كل أخذ.
  final left = {
    for (final l in o.lines)
      '${l.productId}|${o.whOf(l)}': o.qtyOf(l.productId, at: o.whOf(l)),
  };
  final leftAfter = <String, Map<String, double>>{};
  for (final i in pickups) {
    for (final l in i.lines) {
      final k = '${l.productId}|${i.warehouseId}';
      left[k] = (left[k] ?? 0) - l.qty;
    }
    leftAfter[i.id] = {...left};
  }

  final sections = <pw.Widget>[];
  for (final w in o.warehouseIds) {
    final lines = [
      for (final l in o.lines)
        if (o.whOf(l) == w) l,
    ];
    final from = [
      for (final i in pickups)
        if (i.warehouseId == w) i,
    ];
    final whQty = lines.fold<double>(0, (a, l) => a + l.qty);
    final whTaken = lines.fold<double>(
      0,
      (a, l) => a + l.qty - s.remainingInOrder(o, l.productId, at: w),
    );
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
                whName(w),
                textDirection: _dir(whName(w)),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Text(
              'الأصلية ${q(whQty)} • المأخوذ ${q(whTaken)} • '
              'المتبقي ${q(whQty - whTaken)}',
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
      for (final l in lines)
        _row(
          [
            name(l.productId),
            unit(l.productId),
            fmt.money(l.unitPrice),
            fmt.number(l.qty),
            fmt.number(l.qty - s.remainingInOrder(o, l.productId, at: w)),
            fmt.number(s.remainingInOrder(o, l.productId, at: w)),
            fmt.money(l.total),
          ],
          const [4, 2, 3, 2, 2, 2, 3],
        ),
      pw.SizedBox(height: 8),
      _sub('ما أخذه الزبون من ${whName(w)}'),
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
                fmt.number(leftAfter[i.id]?['${l.productId}|$w'] ?? 0),
                fmt.money(l.total),
              ],
              const [1, 3, 2, 4, 2, 2, 3],
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
          ' • ${fmt.date(DateTime.now())} • ${ctx.pageNumber}/${ctx.pagesCount}',
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
            _box('التاريخ', fmt.date(o.date)),
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
            _box('المتبقي في المخازن', q(o.totalQty - taken), color: _red),
            _box(
              credit > 1e-9 ? 'رصيد مدفوع مقدماً' : 'المخازن',
              credit > 1e-9
                  ? fmt.money(credit)
                  : o.warehouseIds.map(whName).join('، '),
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
