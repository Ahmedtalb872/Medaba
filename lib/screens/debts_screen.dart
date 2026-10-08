import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

/// الديون: ما لنا عند الزبائن وما علينا للموردين، مع التسديدات.
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  DebtDirection? _direction;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final overdue = s.overdueDebts(now);
    final items = s.debts
        .where((d) => _direction == null || d.direction == _direction)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'الديون',
          subtitle: 'ما لك عند الآخرين وما عليك لهم، مع كل تسديد',
          actionLabel: 'دين جديد',
          onAction: () => showDebtForm(context),
        ),
        StatGrid(
          children: [
            StatCard(
              label: 'لنا عند الآخرين',
              value: fmt.money(s.debtsRemaining(DebtDirection.theyOwe)),
              icon: Icons.call_received,
              colors: AppColors.income,
            ),
            StatCard(
              label: 'علينا للآخرين',
              value: fmt.money(s.debtsRemaining(DebtDirection.weOwe)),
              icon: Icons.call_made,
              colors: AppColors.expense,
            ),
            StatCard(
              label: 'ديون متأخرة',
              value: '$overdue',
              icon: Icons.schedule,
              colors: overdue == 0 ? AppColors.ok : AppColors.loss,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<DebtDirection?>(
          segments: const [
            ButtonSegment(value: null, label: Text('الكل')),
            ButtonSegment(value: DebtDirection.theyOwe, label: Text('لنا')),
            ButtonSegment(value: DebtDirection.weOwe, label: Text('علينا')),
          ],
          selected: {_direction},
          onSelectionChanged: (v) => setState(() => _direction = v.first),
        ),
        const SizedBox(height: 12),
        DataTableCard<Debt>(
          columns: const [
            'الاسم',
            'النوع',
            'الهاتف',
            'المبلغ',
            'المسدَّد',
            'المتبقي',
            'الاستحقاق',
            'الحالة',
          ],
          items: items,
          emptyMessage: 'لا توجد ديون مسجلة',
          cells: (d) => [
            Text(
              d.personName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              d.direction.label,
              style: TextStyle(
                color: d.direction == DebtDirection.theyOwe
                    ? AppColors.income.last
                    : AppColors.expense.last,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(d.phone, textDirection: TextDirection.ltr),
            Text(fmt.money(d.amount)),
            Text(fmt.money(d.paid)),
            Text(
              fmt.money(d.remaining),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(d.dueDate == null ? '-' : fmt.date(d.dueDate!)),
            _DebtStatus(debt: d, now: now),
          ],
          extraActions: (d) => [
            IconButton(
              tooltip: 'تسجيل تسديد',
              icon: const Icon(Icons.payments_outlined),
              color: AppColors.income.last,
              onPressed: d.isSettled
                  ? null
                  : () => showDebtPaymentForm(context, d),
            ),
          ],
          onEdit: (d) => showDebtForm(context, existing: d),
          onDelete: (d) async {
            if (await confirmDelete(context, 'دين ${d.personName}')) {
              try {
                await s.deleteDebt(d.id);
              } on StateError catch (e) {
                if (context.mounted) _snack(context, e.message);
              }
            }
          },
        ),
      ],
    );
  }
}

class _DebtStatus extends StatelessWidget {
  final Debt debt;
  final DateTime now;
  const _DebtStatus({required this.debt, required this.now});

  @override
  Widget build(BuildContext context) {
    final (label, color) = debt.isSettled
        ? ('مسدَّد', AppColors.income.last)
        : debt.isOverdue(now)
        ? ('متأخر', AppColors.expense.last)
        : debt.paid > 0
        ? ('مسدَّد جزئياً', AppColors.profit.last)
        : ('غير مسدَّد', Theme.of(context).colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<void> showDebtForm(BuildContext context, {Debt? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  var direction = existing?.direction ?? DebtDirection.theyOwe;
  final name = TextEditingController(text: existing?.personName);
  final phone = TextEditingController(text: existing?.phone);
  final amount = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.amount),
  );
  final note = TextEditingController(text: existing?.note);
  var date = existing?.date ?? DateTime.now();
  DateTime? due = existing?.dueDate;

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'دين جديد' : 'تعديل الدين',
    fields: (setState) => [
      SegmentedButton<DebtDirection>(
        segments: const [
          ButtonSegment(
            value: DebtDirection.theyOwe,
            label: Text('لنا (شخص يدين لنا)'),
          ),
          ButtonSegment(
            value: DebtDirection.weOwe,
            label: Text('علينا (ندين لشخص)'),
          ),
        ],
        selected: {direction},
        onSelectionChanged: (v) => setState(() => direction = v.first),
      ),
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: 'اسم ${direction.partyLabel}'),
        validator: requiredText,
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      TextFormField(
        controller: amount,
        // مبلغ دين الفاتورة يُعدَّل من الفاتورة نفسها.
        enabled: existing?.invoiceId == null,
        decoration: InputDecoration(
          labelText: 'مبلغ الدين',
          helperText: existing?.invoiceId == null
              ? null
              : 'مرتبط بفاتورة؛ يُعدَّل المبلغ من الفاتورة',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01),
      ),
      DateField(
        label: 'تاريخ الدين',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('له تاريخ استحقاق'),
        value: due != null,
        onChanged: (v) => setState(
          () => due = v ? DateTime(date.year, date.month + 1, date.day) : null,
        ),
      ),
      if (due != null)
        DateField(
          label: 'تاريخ الاستحقاق',
          value: due!,
          onChanged: (d) => setState(() => due = d),
        ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () async {
      try {
        await s.saveDebt(
          Debt(
            id: existing?.id ?? newId(),
            direction: direction,
            personName: name.text.trim(),
            phone: phone.text.trim(),
            amount: fmt.parseNumber(amount.text)!,
            date: date,
            dueDate: due,
            note: note.text.trim(),
            payments: existing?.payments ?? const [],
            invoiceId: existing?.invoiceId,
          ),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

Future<void> showDebtPaymentForm(BuildContext context, Debt debt) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final amount = TextEditingController(text: fmt.number(debt.remaining));
  final note = TextEditingController();
  var date = DateTime.now();
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;

  return showFormDialog(
    context: context,
    formKey: key,
    title: 'تسديد دين ${debt.personName}',
    fields: (setState) => [
      Row(
        children: [
          Expanded(child: Text('المتبقي: ${fmt.money(debt.remaining)}')),
          Text('من ${fmt.money(debt.amount)}', style: TextStyle(color: muted)),
        ],
      ),
      if (debt.payments.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التسديدات السابقة', style: TextStyle(color: muted)),
            for (final p in debt.payments)
              Text(
                '${fmt.date(p.date)}  •  ${fmt.money(p.amount)}'
                '${p.note.isEmpty ? '' : '  •  ${p.note}'}',
              ),
          ],
        ),
      TextFormField(
        controller: amount,
        decoration: const InputDecoration(labelText: 'المبلغ المسدَّد'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01, max: debt.remaining),
      ),
      DateField(
        label: 'تاريخ التسديد',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
      ),
    ],
    onSave: () => s.addDebtPayment(
      debt.id,
      DebtPayment(
        amount: fmt.parseNumber(amount.text)!,
        date: date,
        note: note.text.trim(),
      ),
    ),
  );
}
