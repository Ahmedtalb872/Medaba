import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/worker_card_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/share_pdf.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';
import '../widgets/common.dart';
import '../widgets/data_table_card.dart' show TableAction;
import 'worker_jobs.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final active = s.workers.where((w) => w.active).length;

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'العمال',
          icon: Icons.engineering_outlined,
          subtitle:
              '$active عامل نشط • الرواتب الشهرية: ${fmt.money(s.monthlyPayroll)}'
              ' • المصروف على العمال هذا الشهر: ${fmt.money(s.paidToWorkers(Period.month(DateTime.now())))}',
          actionLabel: 'إضافة عامل',
          onAction: () => showWorkerForm(context),
          secondaryLabel: 'دفع أجرة عمال',
          secondaryIcon: Icons.groups_outlined,
          onSecondary: () => showLaborForm(context),
        ),
        const LaborPaymentsCard(),
        const SizedBox(height: 16),
        if (s.workers.isEmpty)
          const Card(
            child: EmptyState(
              message:
                  'لا يوجد عمال دائمون مسجلون. العمال اليوميون '
                  'يُسجَّل أجرهم من زر «دفع أجرة عمال» دون تسجيلهم',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1100
                  ? 3
                  : c.maxWidth > 680
                  ? 2
                  : 1;
              const gap = 14.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final worker in s.workers)
                    SizedBox(
                      width: w,
                      child: WorkerCard(worker: worker),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// بطاقة العامل: صورته، اسمه، دوره، رقمه الوطني، وأزرار الإجراءات.
class WorkerCard extends StatelessWidget {
  final Worker worker;
  const WorkerCard({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final w = worker;
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    Widget field(
      IconData icon,
      String label,
      String value, {
      bool ltr = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: ',
              style: muted,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brand, Color(0xFF07291F)],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.company.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: w.active ? AppColors.gold : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    w.active ? 'بطاقة عامل' : 'متوقف',
                    style: const TextStyle(
                      color: Color(0xFF07291F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkerPhoto(
                  worker: w,
                  onTap: () => uploadWorkerPhoto(context, w),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (w.jobTitle.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F1EC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            w.jobTitle,
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      field(
                        Icons.badge_outlined,
                        'الرقم الوطني',
                        w.nationalId.isEmpty ? 'غير مسجل' : w.nationalId,
                        ltr: w.nationalId.isNotEmpty,
                      ),
                      if (w.phone.isNotEmpty)
                        field(
                          Icons.phone_outlined,
                          'الهاتف',
                          w.phone,
                          ltr: true,
                        ),
                      if (w.contract)
                        field(
                          Icons.construction_outlined,
                          'باقي المقاولة',
                          fmt.money(s.workerJobsLeft(w)),
                        )
                      else
                        field(
                          Icons.payments_outlined,
                          w.daily ? 'الأجرة اليومية' : 'الراتب الشهري',
                          fmt.money(w.monthlySalary),
                        ),
                      if (w.daily)
                        field(
                          Icons.calendar_month_outlined,
                          'أيام العمل هذا الشهر',
                          '${s.workDays(w.id, Period.month(DateTime.now()))}',
                        ),
                      field(
                        Icons.event_outlined,
                        'تاريخ التعيين',
                        fmt.date(w.hiredAt),
                      ),
                      field(
                        Icons.account_balance_wallet_outlined,
                        'مصروف الشهر',
                        fmt.money(
                          s.paidToWorker(w.id, Period.month(DateTime.now())),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (w.contract)
                  TableAction(
                    tooltip: 'الأعمال والمراحل',
                    icon: Icons.construction_outlined,
                    color: AppColors.income.last,
                    onTap: () => openWorkerJobs(context, w),
                  )
                else
                  TableAction(
                    tooltip: w.daily ? 'صرف يومية اليوم' : 'صرف راتب هذا الشهر',
                    icon: Icons.payments_outlined,
                    color: AppColors.income.last,
                    onTap: !w.active
                        ? null
                        : () async {
                            await s.paySalary(w, DateTime.now());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تسجيل ${w.daily ? 'يومية' : 'راتب'} ${w.name}: ${fmt.money(w.monthlySalary)}',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                TableAction(
                  tooltip: 'المصاريف',
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.expense.last,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerExpensesPage(workerId: w.id),
                    ),
                  ),
                ),
                TableAction(
                  tooltip: 'طباعة البطاقة',
                  icon: Icons.badge_outlined,
                  color: AppColors.gold,
                  onTap: () => openWorkerCard(context, w),
                ),
                TableAction(
                  tooltip: 'تعديل',
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF1D4ED8),
                  onTap: () => showWorkerForm(context, existing: w),
                ),
                TableAction(
                  tooltip: 'حذف',
                  icon: Icons.delete_outline,
                  color: AppColors.expense.last,
                  onTap: () async {
                    if (await confirmDelete(context, w.name)) {
                      await s.deleteWorker(w.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صورة العامل بمقاس صورة البطاقة؛ عند تمرير [onTap] يمكن رفعها أو تغييرها.
class WorkerPhoto extends StatelessWidget {
  final Worker? worker;
  final String? photo;
  final VoidCallback? onTap;
  final double width;
  const WorkerPhoto({
    super.key,
    this.worker,
    this.photo,
    this.onTap,
    this.width = 88,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = photo ?? worker?.photo;
    final box = Container(
      width: width,
      height: width * 1.22,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: image != null
          ? Image.memory(
              productImageBytes(image),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Icon(
              onTap == null ? Icons.person_outline : Icons.add_a_photo_outlined,
              size: width * 0.42,
              color: cs.onSurfaceVariant,
            ),
    );
    if (onTap == null) return box;
    return Tooltip(
      message: image == null ? 'رفع صورة العامل' : 'تغيير الصورة',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

/// يختار صورة من الجهاز ويحفظها مع العامل.
Future<void> uploadWorkerPhoto(BuildContext context, Worker worker) async {
  final s = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final photo = await pickProductImage();
    if (photo == null) return;
    await s.saveWorker(worker.withPhoto(photo));
    messenger.showSnackBar(
      SnackBar(content: Text('تم حفظ صورة ${worker.name}')),
    );
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> openWorkerCard(BuildContext context, Worker worker) {
  final company = context.read<AppState>().company;
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => WorkerCardPage(worker: worker, company: company),
    ),
  );
}

/// معاينة بطاقة العامل PDF مع الطباعة والتنزيل.
class WorkerCardPage extends StatelessWidget {
  final Worker worker;
  final CompanyInfo company;
  const WorkerCardPage({
    super.key,
    required this.worker,
    required this.company,
  });

  String get fileName => 'بطاقة-${worker.name}.pdf';

  /// الملف يُبنى مرة واحدة، فيكون جاهزاً عند الضغط على «تنزيل» وتفتح
  /// المشاركة مباشرة على الهاتف.
  static final _pdf = Expando<Future<Uint8List>>();

  Future<Uint8List> _build() =>
      _pdf[this] ??= buildWorkerCardPdf(worker: worker, company: company);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('بطاقة ${worker.name}'),
      actions: [
        IconButton(
          tooltip: 'طباعة',
          icon: const Icon(Icons.print_outlined),
          onPressed: () => Printing.layoutPdf(
            name: fileName,
            format: workerCardFormat,
            onLayout: (_) => _build(),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('تنزيل PDF'),
            onPressed: () async => sharePdfFile(await _build(), fileName),
          ),
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) => _build(),
      pdfFileName: fileName,
      initialPageFormat: workerCardFormat,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      maxPageWidth: 640,
      onError: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'تعذّر عرض المعاينة في هذا المتصفح.\n'
            'استخدم زر «تنزيل PDF» أو «طباعة» في الأعلى.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

Future<void> showWorkerForm(BuildContext context, {Worker? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final job = TextEditingController(text: existing?.jobTitle);
  final nationalId = TextEditingController(text: existing?.nationalId);
  var photo = existing?.photo;
  final salary = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.monthlySalary),
  );
  var hired = existing?.hiredAt ?? DateTime.now();
  var active = existing?.active ?? true;
  // 0 راتب شهري، 1 يومية، 2 مقاولة.
  var kind = existing == null
      ? 0
      : existing.contract
      ? 2
      : existing.daily
      ? 1
      : 0;
  final jobTitle = TextEditingController();
  final jobAmount = TextEditingController();

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة عامل' : 'تعديل بيانات العامل',
    fields: (setState) => [
      Row(
        children: [
          WorkerPhoto(
            photo: photo,
            width: 76,
            onTap: () async {
              try {
                final picked = await pickProductImage();
                if (picked != null) setState(() => photo = picked);
              } on FormatException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('صورة العامل'),
                const Text(
                  'اضغط على المربع لاختيار صورة',
                  style: TextStyle(fontSize: 12),
                ),
                if (photo != null)
                  TextButton.icon(
                    onPressed: () => setState(() => photo = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف الصورة'),
                  ),
              ],
            ),
          ),
        ],
      ),
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'الاسم'),
        validator: requiredText,
      ),
      TextFormField(
        controller: job,
        decoration: const InputDecoration(labelText: 'الدور في العمل'),
        validator: requiredText,
      ),
      TextFormField(
        controller: nationalId,
        decoration: const InputDecoration(labelText: 'الرقم الوطني'),
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        validator: (v) {
          final t = v?.trim() ?? '';
          // عامل اليومية قد لا يُعرف رقمه الوطني.
          if (t.isEmpty) return kind != 0 ? null : 'الرقم الوطني مطلوب';
          if (!RegExp(r'^[0-9]+$').hasMatch(t)) return 'أرقام فقط';
          return null;
        },
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('راتب شهري')),
          ButtonSegment(value: 1, label: Text('يومية')),
          ButtonSegment(value: 2, label: Text('مقاولة')),
        ],
        selected: {kind},
        onSelectionChanged: (v) => setState(() => kind = v.first),
      ),
      if (kind != 2)
        TextFormField(
          controller: salary,
          decoration: InputDecoration(
            labelText: kind == 1 ? 'الأجرة اليومية' : 'الراتب الشهري',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(),
        )
      else if (existing == null || existing.jobs.isEmpty) ...[
        const Text(
          'عامل بالمقاولة: يُتفق معه على مبلغ كلي للعمل، ويُدفع له على '
          'مراحل كلما انتهت مرحلة. يمكن إضافة أعمال أخرى لاحقاً من بطاقته.',
          style: TextStyle(fontSize: 12),
        ),
        TextFormField(
          controller: jobTitle,
          decoration: const InputDecoration(
            labelText: 'العمل (مثلاً: بناء منزل)',
          ),
        ),
        TextFormField(
          controller: jobAmount,
          decoration: const InputDecoration(
            labelText: 'المبلغ الكلي المتفق عليه',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => jobTitle.text.trim().isEmpty
              ? null
              : numberValidator(min: 0.01)(v),
        ),
      ] else
        Text(
          'أعماله: ${existing.jobs.length} • تُدار من زر «الأعمال والمراحل» '
          'في بطاقته',
        ),
      DateField(
        label: 'تاريخ التعيين',
        value: hired,
        onChanged: (d) => setState(() => hired = d),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('عامل نشط'),
        value: active,
        onChanged: (v) => setState(() => active = v),
      ),
    ],
    onSave: () => s.saveWorker(
      Worker(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        phone: phone.text.trim(),
        jobTitle: job.text.trim(),
        nationalId: nationalId.text.trim(),
        photo: photo,
        monthlySalary: kind == 2 ? 0 : fmt.parseNumber(salary.text)!,
        hiredAt: hired,
        active: active,
        daily: kind == 1,
        contract: kind == 2,
        jobs: [
          ...?existing?.jobs,
          if (kind == 2 && jobTitle.text.trim().isNotEmpty)
            WorkJob(
              id: newId(),
              title: jobTitle.text.trim(),
              agreed: fmt.parseNumber(jobAmount.text) ?? 0,
              start: DateTime.now(),
            ),
        ],
      ),
    ),
  );
}

/// أجرة عمال يوميين غير مسجلين: المبلغ، من دفعه، والمكان الذي عملوا فيه
/// (مخزن، حاوية، سيارة، قطعة أرضية).
Future<void> showLaborForm(
  BuildContext context, {
  LaborPlace place = LaborPlace.warehouse,
  String? refId,
}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final amount = TextEditingController();
  final workers = TextEditingController();
  final payer = TextEditingController(text: s.company.ownerName);
  final note = TextEditingController();
  var date = DateTime.now();
  var task = AppState.workTasks.first;
  var where = place;
  String? ref = refId;

  List<(String, String)> options() => switch (where) {
    LaborPlace.warehouse => [for (final w in s.warehouses) (w.id, w.name)],
    LaborPlace.container => [
      for (final x in s.shipments)
        (
          x.id,
          [
            if (x.containerNumber.isNotEmpty) x.containerNumber,
            x.contents,
          ].join(' - '),
        ),
    ],
    LaborPlace.car => [for (final c in s.cars) (c.id, c.title)],
    LaborPlace.plot => [for (final p in s.plots) (p.id, p.name)],
    LaborPlace.other => const [],
  };

  return showFormDialog(
    context: context,
    formKey: key,
    title: 'دفع أجرة عمال',
    fields: (setState) {
      final opts = options();
      if (!opts.any((o) => o.$1 == ref)) ref = opts.firstOrNull?.$1;
      return [
        TextFormField(
          controller: amount,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'المبلغ المدفوع للعمال'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(min: 0.01),
        ),
        TextFormField(
          controller: workers,
          decoration: const InputDecoration(labelText: 'عدد العمال (اختياري)'),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          controller: payer,
          decoration: const InputDecoration(labelText: 'المسؤول عن الدفع'),
          validator: requiredText,
        ),
        const Text('العمل', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in AppState.workTasks)
              ChoiceChip(
                label: Text(t),
                selected: task == t,
                onSelected: (_) => setState(() => task = t),
              ),
          ],
        ),
        const Text('أين عملوا', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in LaborPlace.values)
              ChoiceChip(
                label: Text(p.label),
                selected: where == p,
                onSelected: (_) => setState(() {
                  where = p;
                  ref = null;
                }),
              ),
          ],
        ),
        if (where != LaborPlace.other)
          opts.isEmpty
              ? Text('لا يوجد ${where.label} مسجل')
              : DropdownButtonFormField<String>(
                  key: ValueKey(where),
                  initialValue: ref,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: where.label),
                  items: [
                    for (final o in opts)
                      DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => ref = v),
                ),
        DateField(
          label: 'التاريخ',
          value: date,
          onChanged: (d) => setState(() => date = d),
        ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
        ),
      ];
    },
    onSave: () async {
      await s.recordLabor(
        date: date,
        amount: fmt.parseNumber(amount.text)!,
        task: task,
        place: where,
        refId: where == LaborPlace.other ? null : ref,
        workers: fmt.parseNumber(workers.text)?.round() ?? 0,
        payer: payer.text,
        note: note.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تسجيل أجرة العمال: ${amount.text}')),
        );
      }
    },
  );
}

/// قائمة أجور العمال اليوميين هذا الشهر في صفحة العمال.
class LaborPaymentsCard extends StatelessWidget {
  const LaborPaymentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.laborPayments(Period.month(DateTime.now()));
    final total = items.fold<double>(0, (a, t) => a + t.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'أجور العمال اليوميين هذا الشهر: ${fmt.money(total)}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('لم تُسجَّل أجور هذا الشهر'),
              ),
            for (final x in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined),
                title: Text(x.note),
                subtitle: Text(fmt.date(x.date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmt.money(x.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDelete(context, x.note)) {
                          await s.deleteTransaction(x.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// مصاريف العامل: الرواتب واليوميات والسلف وغيرها، مع إضافة مصروف.
class WorkerExpensesPage extends StatelessWidget {
  final String workerId;
  const WorkerExpensesPage({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final w = s.workers.where((x) => x.id == workerId).firstOrNull;
    if (w == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('حُذف العامل')),
      );
    }
    final month = Period.month(DateTime.now());
    final items = s.workerExpenses(w.id);
    return Scaffold(
      appBar: AppBar(title: Text('مصاريف ${w.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWorkerExpenseForm(context, w),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16, bottom: 96),
        children: [
          StatGrid(
            children: [
              StatCard(
                label: 'هذا الشهر',
                value: fmt.money(s.paidToWorker(w.id, month)),
                icon: Icons.calendar_month_outlined,
                colors: AppColors.expense,
              ),
              StatCard(
                label: 'الكل',
                value: fmt.money(s.paidToWorker(w.id)),
                icon: Icons.account_balance_wallet_outlined,
                colors: AppColors.workers,
              ),
              StatCard(
                label: w.contract ? 'الباقي من المقاولة' : w.wageLabel,
                value: fmt.money(
                  w.contract ? s.workerJobsLeft(w) : w.monthlySalary,
                ),
                icon: Icons.payments_outlined,
                colors: AppColors.payroll,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(child: EmptyState(message: 'لا توجد مصاريف بعد')),
          for (final x in items)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.expense.first.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(
                    x.category == TxCategory.salary
                        ? Icons.payments_outlined
                        : Icons.receipt_long_outlined,
                    color: AppColors.expense.last,
                  ),
                ),
                title: Text(x.note.isEmpty ? x.category.label : x.note),
                subtitle: Text('${fmt.date(x.date)} • ${x.category.label}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmt.money(x.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!s.isLinkedTransaction(x.id))
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDelete(context, x.note)) {
                            await s.deleteTransaction(x.id);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// إضافة مصروف على عامل: سلفة، أكل، نقل، علاج، مكافأة...
Future<void> showWorkerExpenseForm(BuildContext context, Worker w) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();
  var kind = AppState.workerExpenseKinds.first;
  var date = DateTime.now();
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'مصروف على ${w.name}',
    fields: (setState) => [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in AppState.workerExpenseKinds)
            ChoiceChip(
              label: Text(k),
              selected: kind == k,
              onSelected: (_) => setState(() => kind = k),
            ),
        ],
      ),
      TextFormField(
        controller: amount,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'المبلغ'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01),
      ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
      ),
    ],
    onSave: () => s.addWorkerExpense(
      w,
      kind: kind,
      amount: fmt.parseNumber(amount.text)!,
      date: date,
      note: note.text,
    ),
  );
}
