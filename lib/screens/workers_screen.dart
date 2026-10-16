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
              ' • المصروف على العمال هذا الشهر: ${fmt.money(s.paidToWorkers(Period.month(DateTime.now())))}'
              ' • عمال اليومية: ${s.workers.where((w) => w.active && w.daily).length}',
          actionLabel: 'إضافة عامل',
          onAction: () => showWorkerForm(context),
          secondaryLabel: 'تسجيل يوم عمل',
          secondaryIcon: Icons.event_available_outlined,
          onSecondary: () => showWorkDayForm(context),
        ),
        if (s.workers.isEmpty)
          const Card(child: EmptyState(message: 'لم تتم إضافة عمال بعد'))
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
          Text('$label: ', style: muted),
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
  var daily = existing?.daily ?? false;

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
          if (t.isEmpty) return daily ? null : 'الرقم الوطني مطلوب';
          if (!RegExp(r'^[0-9]+$').hasMatch(t)) return 'أرقام فقط';
          return null;
        },
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('راتب شهري')),
          ButtonSegment(value: true, label: Text('يومية (حسب الأيام)')),
        ],
        selected: {daily},
        onSelectionChanged: (v) => setState(() => daily = v.first),
      ),
      TextFormField(
        controller: salary,
        decoration: InputDecoration(
          labelText: daily ? 'الأجرة اليومية' : 'الراتب الشهري',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(),
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
        monthlySalary: fmt.parseNumber(salary.text)!,
        hiredAt: hired,
        active: active,
        daily: daily,
      ),
    ),
  );
}

/// يوم عمل لعمال اليومية: تنزيل أو رفع البضاعة في حاوية أو مخزن، من حضر
/// وأجرة كل واحد. مع الحاوية يُضاف مجموع الأجور إلى تكاليفها.
Future<void> showWorkDayForm(
  BuildContext context, {
  String? shipmentId,
  String? warehouseId,
}) {
  final s = context.read<AppState>();
  final workers = s.workers.where((w) => w.active && w.daily).toList();
  if (workers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'لا يوجد عمال باليومية. أضف عاملاً واختر «يومية» في نوع الأجر',
        ),
      ),
    );
    return Future.value();
  }
  final key = GlobalKey<FormState>();
  var date = DateTime.now();
  String? ship = shipmentId;
  String? wh = warehouseId;
  // أين كان العمل: حاوية أو مخزن.
  var atWarehouse = warehouseId != null;
  var task = AppState.workTasks.first;
  final present = <String>{};
  final wage = {
    for (final w in workers)
      w.id: TextEditingController(text: fmt.number(w.monthlySalary)),
  };
  double total() =>
      [for (final id in present) fmt.parseNumber(wage[id]!.text) ?? 0]
          .fold(0, (a, b) => a + b);

  return showFormDialog(
    context: context,
    formKey: key,
    title: 'تسجيل يوم عمل',
    fields: (setState) => [
      DateField(
        label: 'اليوم',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      const Text('العمل', style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(
        spacing: 8,
        children: [
          for (final t in AppState.workTasks)
            ChoiceChip(
              label: Text(t),
              selected: task == t,
              onSelected: (_) => setState(() => task = t),
            ),
        ],
      ),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.directions_boat_outlined),
            label: Text('حاوية'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.warehouse_outlined),
            label: Text('مخزن'),
          ),
        ],
        selected: {atWarehouse},
        onSelectionChanged: (v) => setState(() => atWarehouse = v.first),
      ),
      if (!atWarehouse)
        DropdownButtonFormField<String?>(
          key: const ValueKey('ship'),
          initialValue: ship,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الحاوية'),
          items: [
            const DropdownMenuItem(value: null, child: Text('بدون حاوية')),
            for (final x in s.shipments)
              DropdownMenuItem(
                value: x.id,
                child: Text(
                  [
                    if (x.containerNumber.isNotEmpty) x.containerNumber,
                    x.contents,
                  ].join(' - '),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() => ship = v),
        )
      else
        DropdownButtonFormField<String?>(
          key: const ValueKey('wh'),
          initialValue: wh,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'المخزن'),
          items: [
            const DropdownMenuItem(value: null, child: Text('بدون مخزن')),
            for (final w in s.warehouses)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          onChanged: (v) => setState(() => wh = v),
        ),
      const Text(
        'العمال الحاضرون',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final w in workers)
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(w.name),
                subtitle: w.jobTitle.isEmpty ? null : Text(w.jobTitle),
                value: present.contains(w.id),
                onChanged: (v) => setState(
                  () => v == true ? present.add(w.id) : present.remove(w.id),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: wage[w.id],
                enabled: present.contains(w.id),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'الأجرة'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: present.contains(w.id)
                    ? numberValidator(min: 0.01)
                    : null,
              ),
            ),
          ],
        ),
      Text(
        present.isEmpty
            ? 'اختر العمال الذين حضروا'
            : '${present.length} عامل • المجموع ${fmt.money(total())}'
                  '${!atWarehouse && ship != null ? ' • يُضاف إلى تكاليف الحاوية' : ''}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
    onSave: () async {
      if (present.isEmpty) return;
      await s.recordWorkDay(
        date: date,
        task: task,
        shipmentId: atWarehouse ? null : ship,
        warehouseId: atWarehouse ? wh : null,
        wages: {
          for (final id in present) id: fmt.parseNumber(wage[id]!.text) ?? 0,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل يومية ${present.length} عامل: ${fmt.money(total())}',
            ),
          ),
        );
      }
    },
  );
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
                label: w.wageLabel,
                value: fmt.money(w.monthlySalary),
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
