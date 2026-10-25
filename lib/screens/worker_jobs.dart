import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/job_invoice_pdf.dart';
import '../utils/share_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<void> openWorkerJobs(BuildContext context, Worker w) {
  final s = context.read<AppState>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: s,
        child: WorkerJobsPage(workerId: w.id),
      ),
    ),
  );
}

/// أعمال عامل المقاولة: لكل عمل المبلغ المتفق عليه، والمراحل المدفوعة
/// بتواريخها، والباقي حتى يكتمل المبلغ.
class WorkerJobsPage extends StatelessWidget {
  final String workerId;
  const WorkerJobsPage({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final w = s.workers.where((x) => x.id == workerId).firstOrNull;
    if (w == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('العامل محذوف')),
      );
    }
    final agreed = w.jobs.fold<double>(0, (a, j) => a + j.agreed);
    final paid = w.jobs.fold<double>(0, (a, j) => a + s.jobPaid(j.id));
    return Scaffold(
      appBar: AppBar(title: Text('أعمال ${w.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showJobForm(context, w),
        icon: const Icon(Icons.add),
        label: const Text('عمل جديد'),
      ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16, bottom: 120),
        children: [
          StatGrid(
            children: [
              StatCard(
                label: 'المتفق عليه',
                value: fmt.money(agreed),
                icon: Icons.handshake_outlined,
                colors: AppColors.capital,
              ),
              StatCard(
                label: 'المدفوع',
                value: fmt.money(paid),
                icon: Icons.payments_outlined,
                colors: AppColors.income,
              ),
              StatCard(
                label: 'الباقي',
                value: fmt.money(agreed - paid),
                icon: Icons.hourglass_bottom,
                colors: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (w.jobs.isEmpty)
            const Card(
              child: EmptyState(
                message:
                    'لا توجد أعمال بعد. اضغط «عمل جديد» '
                    'واكتب العمل والمبلغ المتفق عليه',
              ),
            ),
          for (final j in w.jobs.reversed) _JobCard(worker: w, job: j),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Worker worker;
  final WorkJob job;
  const _JobCard({required this.worker, required this.job});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final j = job;
    final stages = s.jobPayments(j.id);
    final paid = s.jobPaid(j.id);
    final left = j.agreed - paid;
    final done = left <= 1e-9;
    final place = s.jobPlaceName(j);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    var running = 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    j.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (done)
                  Chip(
                    label: const Text('اكتمل'),
                    backgroundColor: AppColors.ok.first.withValues(alpha: 0.15),
                  ),
                IconButton(
                  tooltip: 'تعديل العمل',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showJobForm(context, worker, existing: j),
                ),
                IconButton(
                  tooltip: 'حذف العمل',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmDelete(context, j.title)) return;
                    try {
                      await s.deleteJob(worker.id, j.id);
                    } on StateError catch (e) {
                      if (context.mounted) _snack(context, e.message);
                    }
                  },
                ),
              ],
            ),
            Text(
              [
                'بدأ ${fmt.date(j.start)}',
                ?place,
                if (j.notes.isNotEmpty) j.notes,
              ].join(' • '),
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _amount('المتفق عليه', j.agreed, AppColors.brand),
                _amount('المدفوع', paid, AppColors.ok.last),
                _amount(
                  'الباقي',
                  left,
                  done ? AppColors.ok.last : AppColors.expense.last,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: j.agreed <= 0 ? 0 : (paid / j.agreed).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Text(
              'المراحل المدفوعة',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (stages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'لم تُدفع أي مرحلة بعد',
                  style: TextStyle(color: muted),
                ),
              ),
            for (final (n, t) in stages.indexed)
              Builder(
                builder: (context) {
                  running += t.amount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.income.last.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            '${n + 1}',
                            style: TextStyle(
                              color: AppColors.income.last,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${fmt.date(t.date)} • ${stageName(t.note, j, worker)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'المدفوع حتى الآن ${fmt.money(running)} • '
                                'الباقي ${fmt.money(j.agreed - running)}',
                                style: TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fmt.money(t.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.income.last,
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف المرحلة',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                if (await confirmDelete(
                                  context,
                                  'مرحلة ${fmt.money(t.amount)}',
                                )) {
                                  await s.deleteJobStage(j, t.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!done)
                  FilledButton.icon(
                    onPressed: () => showStageForm(context, worker, j),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('دفع مرحلة منتهية'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openJobInvoice(context, worker, j),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('فاتورة العمل PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, double v, Color color) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          fmt.money(v),
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    ),
  );
}

/// اسم المرحلة من بيان معاملتها.
String stageName(String note, WorkJob j, Worker w) => note
    .replaceFirst('مرحلة ', '')
    .replaceFirst(' - ${j.title} - ${w.name}', '');

/// يفتح فاتورة العمل الواحدة (PDF) بكل مراحلها.
Future<void> openJobInvoice(BuildContext context, Worker w, WorkJob j) {
  final s = context.read<AppState>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _JobPdfPage(
        worker: w,
        job: j,
        place: s.jobPlaceName(j),
        company: s.company,
        stages: [
          for (final t in s.jobPayments(j.id))
            (date: t.date, stage: stageName(t.note, j, w), amount: t.amount),
        ],
      ),
    ),
  );
}

/// قسم المقاولين في صفحة العمال: كل عمل بمبلغه والمدفوع والباقي،
/// مع دفع مرحلة وفاتورة العمل مباشرة.
class ContractJobsCard extends StatelessWidget {
  /// يفتح نموذج إضافة عامل بنوع «مقاولة».
  final VoidCallback onNewContractor;
  const ContractJobsCard({super.key, required this.onNewContractor});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final jobs = [
      for (final w in s.workers.where((w) => w.contract))
        for (final j in w.jobs.reversed) (w, j),
    ];
    final left = jobs.fold<double>(
      0,
      (a, e) => a + s.jobLeft(e.$2).clamp(0, double.infinity),
    );
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المقاولون وأعمالهم',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'عمل بمبلغ متفق عليه يُدفع على مراحل • '
                      'الباقي لهم ${fmt.money(left)}',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: onNewContractor,
                  icon: const Icon(Icons.construction_outlined),
                  label: const Text('مقاول جديد'),
                ),
              ],
            ),
            if (jobs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'لا يوجد مقاولون بعد. اضغط «مقاول جديد» واكتب العمل '
                  'والمبلغ المتفق عليه.',
                  style: TextStyle(color: muted),
                ),
              ),
            for (final (w, j) in jobs) ...[
              const Divider(height: 24),
              _ContractJobRow(worker: w, job: j),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContractJobRow extends StatelessWidget {
  final Worker worker;
  final WorkJob job;
  const _ContractJobRow({required this.worker, required this.job});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final j = job;
    final paid = s.jobPaid(j.id);
    final left = j.agreed - paid;
    final done = left <= 1e-9;
    final stages = s.jobPayments(j.id).length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openWorkerJobs(context, worker),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${j.title} • ${worker.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (done)
                Chip(
                  label: const Text('اكتمل'),
                  backgroundColor: AppColors.ok.first.withValues(alpha: 0.15),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: j.agreed <= 0 ? 0 : (paid / j.agreed).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            'المتفق عليه ${fmt.money(j.agreed)} • المدفوع ${fmt.money(paid)} '
            '($stages مرحلة) • الباقي ${fmt.money(left)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!done)
                FilledButton.tonalIcon(
                  onPressed: () => showStageForm(context, worker, j),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('دفع مرحلة'),
                ),
              OutlinedButton.icon(
                onPressed: () => openJobInvoice(context, worker, j),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('الفاتورة'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// إضافة عمل لعامل المقاولة أو تعديله: الاسم، المبلغ المتفق عليه، والمكان.
Future<void> showJobForm(BuildContext context, Worker w, {WorkJob? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final title = TextEditingController(text: existing?.title);
  final agreed = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.agreed),
  );
  final notes = TextEditingController(text: existing?.notes);
  var start = existing?.start ?? DateTime.now();
  var place = existing?.place ?? 'other';
  String? ref = existing?.refId;

  List<(String, String)> options() => switch (place) {
    'plot' => [for (final p in s.plots) (p.id, p.name)],
    'car' => [for (final c in s.cars) (c.id, c.title)],
    _ => const [],
  };

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'عمل جديد لـ ${w.name}' : 'تعديل العمل',
    fields: (setState) {
      final opts = options();
      if (!opts.any((o) => o.$1 == ref)) ref = opts.firstOrNull?.$1;
      return [
        TextFormField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'العمل (مثلاً: بناء منزل، تبليط...)',
          ),
          validator: requiredText,
        ),
        TextFormField(
          controller: agreed,
          decoration: const InputDecoration(
            labelText: 'المبلغ الكلي المتفق عليه',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(min: 0.01),
        ),
        DateField(
          label: 'تاريخ البدء',
          value: start,
          onChanged: (d) => setState(() => start = d),
        ),
        const Text('مكان العمل', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (v, label) in const [
              ('plot', 'قطعة أرضية'),
              ('car', 'سيارة'),
              ('other', 'أخرى'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: place == v,
                onSelected: (_) => setState(() {
                  place = v;
                  ref = null;
                }),
              ),
          ],
        ),
        if (place != 'other')
          opts.isEmpty
              ? Text(
                  place == 'plot'
                      ? 'لا توجد قطعة أرضية مسجلة'
                      : 'لا توجد سيارة مسجلة',
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(place),
                  initialValue: ref,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: place == 'plot' ? 'القطعة' : 'السيارة',
                    helperText: 'ما يُدفع للمراحل يُضاف لتكاليفها',
                  ),
                  items: [
                    for (final o in opts)
                      DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => ref = v),
                ),
        TextFormField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
        ),
      ];
    },
    onSave: () async {
      final hasPlace = place != 'other' && ref != null;
      try {
        await s.saveJob(
          w.id,
          WorkJob(
            id: existing?.id ?? newId(),
            title: title.text.trim(),
            agreed: fmt.parseNumber(agreed.text)!,
            start: start,
            place: hasPlace ? place : 'other',
            refId: hasPlace ? ref : null,
            notes: notes.text.trim(),
          ),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

/// دفع مبلغ مرحلة انتهت: اسم المرحلة والمبلغ والتاريخ.
Future<void> showStageForm(BuildContext context, Worker w, WorkJob j) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final stage = TextEditingController();
  final amount = TextEditingController();
  var date = DateTime.now();
  final left = s.jobLeft(j);
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'دفع مرحلة • ${j.title}',
    fields: (setState) => [
      Text('الباقي من المبلغ المتفق عليه: ${fmt.money(left)}'),
      TextFormField(
        controller: stage,
        decoration: const InputDecoration(
          labelText: 'المرحلة المنتهية (مثلاً: الأساس، الجدران، السقف)',
        ),
        validator: requiredText,
      ),
      TextFormField(
        controller: amount,
        decoration: InputDecoration(
          labelText: 'المبلغ المدفوع',
          suffixIcon: TextButton(
            onPressed: () => amount.text = fmt.number(left),
            child: const Text('الكل'),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01, max: left),
      ),
      DateField(
        label: 'تاريخ الانتهاء والدفع',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
    ],
    onSave: () async {
      try {
        await s.payJobStage(
          w,
          j,
          stage: stage.text,
          amount: fmt.parseNumber(amount.text) ?? 0,
          date: date,
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

class _JobPdfPage extends StatefulWidget {
  final Worker worker;
  final WorkJob job;
  final String? place;
  final CompanyInfo company;
  final List<JobStageLine> stages;
  const _JobPdfPage({
    required this.worker,
    required this.job,
    required this.place,
    required this.company,
    required this.stages,
  });

  @override
  State<_JobPdfPage> createState() => _JobPdfPageState();
}

class _JobPdfPageState extends State<_JobPdfPage> {
  /// يُبنى الملف مرة واحدة فيكون جاهزاً للمشاركة مباشرة على الهاتف.
  late final Future<Uint8List> _pdf = buildJobInvoicePdf(
    worker: widget.worker,
    job: widget.job,
    stages: widget.stages,
    company: widget.company,
    place: widget.place,
  );

  String get fileName => 'فاتورة-${widget.job.title}-${widget.worker.name}.pdf';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('فاتورة ${widget.job.title}'),
      actions: [
        IconButton(
          tooltip: 'طباعة',
          icon: const Icon(Icons.print_outlined),
          onPressed: () =>
              Printing.layoutPdf(name: fileName, onLayout: (_) => _pdf),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('إرسال / تنزيل'),
            onPressed: () async => sharePdfFile(await _pdf, fileName),
          ),
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) => _pdf,
      pdfFileName: fileName,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      onError: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'تعذّر عرض المعاينة في هذا المتصفح.\n'
            'استخدم زر «إرسال / تنزيل» أو «طباعة» في الأعلى.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
