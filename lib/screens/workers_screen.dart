import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

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
        DataTableCard<Worker>(
          columns: const [
            'الاسم',
            'الوظيفة',
            'الهاتف',
            'الراتب الشهري',
            'تاريخ التعيين',
            'الحالة',
          ],
          items: s.workers,
          emptyMessage: 'لم تتم إضافة عمال بعد',
          cells: (w) => [
            Text(w.name),
            Text(w.jobTitle),
            Text(w.phone, textDirection: TextDirection.ltr),
            Text(fmt.money(w.monthlySalary)),
            Text(fmt.date(w.hiredAt)),
            Chip(
              label: Text(w.active ? 'نشط' : 'متوقف'),
              backgroundColor: w.active
                  ? Colors.green.shade50
                  : Colors.grey.shade200,
              visualDensity: VisualDensity.compact,
            ),
          ],
          extraActions: (w) => [
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
          ],
          onEdit: (w) => showWorkerForm(context, existing: w),
          onDelete: (w) async {
            if (await confirmDelete(context, w.name)) {
              await s.deleteWorker(w.id);
            }
          },
        ),
      ],
    );
  }
}

Future<void> showWorkerForm(BuildContext context, {Worker? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final job = TextEditingController(text: existing?.jobTitle);
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
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'الاسم'),
        validator: requiredText,
      ),
      TextFormField(
        controller: job,
        decoration: const InputDecoration(labelText: 'الوظيفة'),
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
        monthlySalary: fmt.parseNumber(salary.text)!,
        hiredAt: hired,
        active: active,
      ),
    ),
  );
}
