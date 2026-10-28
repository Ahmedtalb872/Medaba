import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/models.dart';
import '../utils/format.dart' as fmt;
import 'invoice_pdf.dart' show loadPdfTheme;
import 'invoice_strings.dart' show InvoiceLanguage;

/// نصوص فاتورة العمل بكل لغة. ما يكتبه المدير (العمل، المراحل، الأسماء،
/// الملاحظات) يبقى كما كُتب.
class _T {
  final String badge, worker, phone, nationalId, start, place, status, done;
  final String running, stages, date, stage, amount, paidSoFar, left;
  final String noStages, agreed, paid, remaining, notes, workerSign;
  final String managerSign, currency;
  const _T({
    required this.badge,
    required this.worker,
    required this.phone,
    required this.nationalId,
    required this.start,
    required this.place,
    required this.status,
    required this.done,
    required this.running,
    required this.stages,
    required this.date,
    required this.stage,
    required this.amount,
    required this.paidSoFar,
    required this.left,
    required this.noStages,
    required this.agreed,
    required this.paid,
    required this.remaining,
    required this.notes,
    required this.workerSign,
    required this.managerSign,
    required this.currency,
  });

  String money(num v) => '${fmt.number(v)} $currency';

  static const ar = _T(
    badge: 'فاتورة عمل بالمقاولة',
    worker: 'العامل',
    phone: 'الهاتف',
    nationalId: 'الرقم الوطني',
    start: 'تاريخ البدء',
    place: 'مكان العمل',
    status: 'الحالة',
    done: 'اكتمل',
    running: 'جارٍ',
    stages: 'المراحل المدفوعة',
    date: 'التاريخ',
    stage: 'المرحلة',
    amount: 'المبلغ',
    paidSoFar: 'المدفوع حتى الآن',
    left: 'الباقي',
    noStages: 'لم تُدفع أي مرحلة بعد',
    agreed: 'المبلغ الكلي المتفق عليه',
    paid: 'المدفوع',
    remaining: 'الباقي',
    notes: 'ملاحظات',
    workerSign: 'توقيع العامل',
    managerSign: 'توقيع المدير',
    currency: fmt.currencySymbol,
  );

  static const fr = _T(
    badge: 'Facture de travaux à forfait',
    worker: 'Ouvrier',
    phone: 'Téléphone',
    nationalId: 'N° national (NNI)',
    start: 'Date de début',
    place: 'Lieu des travaux',
    status: 'État',
    done: 'Terminé',
    running: 'En cours',
    stages: 'Étapes payées',
    date: 'Date',
    stage: 'Étape',
    amount: 'Montant',
    paidSoFar: 'Payé à ce jour',
    left: 'Reste',
    noStages: 'Aucune étape payée',
    agreed: 'Montant total convenu',
    paid: 'Payé',
    remaining: 'Reste à payer',
    notes: 'Remarques',
    workerSign: "Signature de l'ouvrier",
    managerSign: 'Signature du responsable',
    currency: 'MRU',
  );

  static const en = _T(
    badge: 'Contract work invoice',
    worker: 'Worker',
    phone: 'Phone',
    nationalId: 'National ID',
    start: 'Start date',
    place: 'Work site',
    status: 'Status',
    done: 'Completed',
    running: 'In progress',
    stages: 'Paid stages',
    date: 'Date',
    stage: 'Stage',
    amount: 'Amount',
    paidSoFar: 'Paid so far',
    left: 'Remaining',
    noStages: 'No stage paid yet',
    agreed: 'Total agreed amount',
    paid: 'Paid',
    remaining: 'Balance due',
    notes: 'Notes',
    workerSign: "Worker's signature",
    managerSign: "Manager's signature",
    currency: 'MRU',
  );
}

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
  InvoiceLanguage language = InvoiceLanguage.ar,
}) async {
  final t = switch (language) {
    InvoiceLanguage.ar => _T.ar,
    InvoiceLanguage.fr => _T.fr,
    InvoiceLanguage.en => _T.en,
  };
  final rtl = language.rtl;
  _align = rtl ? pw.TextAlign.right : pw.TextAlign.left;
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
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${company.name} • ${company.address} • ${company.phone}'
          ' • ${fmt.date(DateTime.now())}',
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
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company.name,
                textDirection: _dir(company.name),
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                job.title,
                textDirection: _dir(job.title),
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
                  t.badge,
                  textDirection: _dir(t.badge),
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
            _box(t.worker, worker.name),
            _box(t.phone, worker.phone),
            _box(t.nationalId, worker.nationalId),
          ],
        ),
        pw.Row(
          children: [
            _box(t.start, fmt.date(job.start)),
            _box(t.place, place ?? ''),
            _box(t.status, left <= 1e-9 ? t.done : t.running),
          ],
        ),
        pw.SizedBox(height: 12),
        _title(t.stages),
        _row(['#', t.date, t.stage, t.amount, t.paidSoFar, t.left], head: true),
        for (final (n, s) in stages.indexed)
          () {
            running += s.amount;
            return _row([
              '${n + 1}',
              fmt.date(s.date),
              s.stage,
              t.money(s.amount),
              t.money(running),
              t.money(job.agreed - running),
            ]);
          }(),
        if (stages.isEmpty) _row(['', '', t.noStages, '', '', '']),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _panel,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _total(t, t.agreed, job.agreed, null),
              _total(t, t.paid, paid, _green),
              _total(
                t,
                t.remaining,
                left,
                left > 1e-9 ? _red : _green,
                big: true,
              ),
            ],
          ),
        ),
        if (job.notes.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _title(t.notes),
          pw.Text(job.notes, textDirection: _dir(job.notes)),
        ],
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _sign(t.workerSign),
            _sign(rtl ? 'توقيع ${company.ownerRole}' : t.managerSign),
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
    textDirection: _dir(t),
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
        pw.Text(
          label,
          textDirection: _dir(label),
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
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
                textAlign: _align,
              ),
            ),
          ),
      ],
    ),
  );
}

/// محاذاة نص الجدول: يمين للعربية، يسار للفرنسية والإنجليزية.
var _align = pw.TextAlign.right;

pw.Widget _total(
  _T t,
  String label,
  double v,
  PdfColor? color, {
  bool big = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          label,
          textDirection: _dir(label),
          style: pw.TextStyle(
            fontSize: big ? 13 : 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Text(
        t.money(v),
        textDirection: _dir(t.money(v)),
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
    pw.Text(
      label,
      textDirection: _dir(label),
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  ],
);
