import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/worker_card_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
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
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'العمال',
          icon: Icons.engineering_outlined,
          subtitle:
              '$active عامل نشط • الرواتب الشهرية: ${fmt.money(s.monthlyPayroll)}',
          actionLabel: 'إضافة عامل',
          onAction: () => showWorkerForm(context),
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
                        'الراتب',
                        fmt.money(w.monthlySalary),
                      ),
                      field(
                        Icons.event_outlined,
                        'تاريخ التعيين',
                        fmt.date(w.hiredAt),
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
                  tooltip: 'صرف راتب هذا الشهر',
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
                                  'تم تسجيل راتب ${w.name}: ${fmt.money(w.monthlySalary)}',
                                ),
                              ),
                            );
                          }
                        },
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

  Future<Uint8List> _build() =>
      buildWorkerCardPdf(worker: worker, company: company);

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
            onPressed: () async =>
                Printing.sharePdf(bytes: await _build(), filename: fileName),
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
          if (t.isEmpty) return 'الرقم الوطني مطلوب';
          if (!RegExp(r'^[0-9]+$').hasMatch(t)) return 'أرقام فقط';
          return null;
        },
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      TextFormField(
        controller: salary,
        decoration: const InputDecoration(labelText: 'الراتب الشهري'),
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
      ),
    ),
  );
}
