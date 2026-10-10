import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TxType? _type;
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final period = _month == null ? null : Period.month(_month!);
    final items = s.transactions
        .where((t) => _type == null || t.type == _type)
        .where((t) => period == null || period.contains(t.date))
        .toList();

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'المعاملات المالية',
          icon: Icons.receipt_long_outlined,
          subtitle:
              'الإيرادات: ${fmt.money(s.totalIncome(period))} • '
              'المصروفات: ${fmt.money(s.totalExpenses(period))}',
          actionLabel: 'معاملة جديدة',
          onAction: () => showTransactionForm(context),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TxType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('الكل')),
                ButtonSegment(value: TxType.income, label: Text('إيرادات')),
                ButtonSegment(value: TxType.expense, label: Text('مصروفات')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 18),
              label: Text(_month == null ? 'كل الأشهر' : fmt.month(_month!)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _month ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'اختر أي يوم من الشهر',
                );
                if (d != null) setState(() => _month = d);
              },
            ),
            if (_month != null)
              IconButton(
                tooltip: 'إزالة فلتر الشهر',
                onPressed: () => setState(() => _month = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DataTableCard<Transaction>(
          columns: const [
            'التاريخ',
            'النوع',
            'التصنيف',
            'المبلغ',
            'مرتبط بـ',
            'ملاحظات',
          ],
          items: items,
          emptyMessage: 'لا توجد معاملات',
          cells: (t) => [
            Text(fmt.date(t.date)),
            Text(
              t.type.label,
              style: TextStyle(
                color: t.type == TxType.income
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            Text(t.category.label),
            Text(
              fmt.money(t.amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(s.personName(t.personId) ?? '-'),
            Text(t.note),
          ],
          onEdit: (t) => s.isLinkedTransaction(t.id)
              ? _stockTxNotice(context)
              : showTransactionForm(context, existing: t),
          onDelete: (t) async {
            if (s.isLinkedTransaction(t.id)) return _stockTxNotice(context);
            if (await confirmDelete(
              context,
              '${t.category.label} ${fmt.money(t.amount)}',
            )) {
              await s.deleteTransaction(t.id);
            }
          },
        ),
      ],
    );
  }
}

/// معاملات الشراء والبيع المرتبطة بالمخزون أو الفواتير تُعدَّل من شاشتها
/// حتى لا تختلف الكميات عن المبالغ.
void _stockTxNotice(
  BuildContext context,
) => ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text(
      'هذه المعاملة مرتبطة بفاتورة أو حركة مخزون؛ عدّلها أو احذفها من شاشتها',
    ),
  ),
);

Future<void> showTransactionForm(
  BuildContext context, {
  Transaction? existing,
}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  var type = existing?.type ?? TxType.income;
  var category = existing?.category ?? TxCategory.sales;
  String? personId = existing?.personId;
  var date = existing?.date ?? DateTime.now();
  final amount = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.amount),
  );
  final note = TextEditingController(text: existing?.note);

  /// الأشخاص الذين يمكن ربطهم بالمعاملة حسب تصنيفها.
  List<DropdownMenuItem<String?>> people() {
    final list = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('بدون')),
    ];
    if (category == TxCategory.salary) {
      list.addAll(
        s.workers.map(
          (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
        ),
      );
    } else if (category == TxCategory.withdrawal) {
      list.addAll(
        s.partners.map(
          (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
        ),
      );
    }
    return list;
  }

  bool linkable() =>
      category == TxCategory.salary || category == TxCategory.withdrawal;

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'معاملة جديدة' : 'تعديل المعاملة',
    fields: (setState) => [
      SegmentedButton<TxType>(
        segments: [
          for (final t in TxType.values)
            ButtonSegment(value: t, label: Text(t.label)),
        ],
        selected: {type},
        onSelectionChanged: (v) => setState(() {
          type = v.first;
          category = TxCategory.forType(type).first;
          personId = null;
        }),
      ),
      DropdownButtonFormField<TxCategory>(
        key: ValueKey(type),
        initialValue: category,
        decoration: const InputDecoration(labelText: 'التصنيف'),
        items: [
          for (final c in TxCategory.forType(type))
            DropdownMenuItem(value: c, child: Text(c.label)),
        ],
        onChanged: (c) => setState(() {
          category = c!;
          personId = null;
        }),
      ),
      TextFormField(
        controller: amount,
        decoration: const InputDecoration(labelText: 'المبلغ'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01),
      ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      if (linkable())
        DropdownButtonFormField<String?>(
          key: ValueKey(category),
          initialValue: personId,
          decoration: InputDecoration(
            labelText: category == TxCategory.salary ? 'العامل' : 'الشريك',
          ),
          items: people(),
          validator: (v) => category == TxCategory.withdrawal && v == null
              ? 'اختر الشخص الذي قام بالسحب'
              : null,
          onChanged: (v) => setState(() => personId = v),
        ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () => s.saveTransaction(
      Transaction(
        id: existing?.id ?? newId(),
        category: category,
        amount: fmt.parseNumber(amount.text)!,
        date: date,
        note: note.text.trim(),
        personId: linkable() ? personId : null,
      ),
    ),
  );
}
