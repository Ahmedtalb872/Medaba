import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

class InvestorsScreen extends StatelessWidget {
  const InvestorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final report = s.profitReport();
    final shareOf = {for (final i in report.investors) i.id: i};
    final totalInvested = s.investors.fold<double>(
      0,
      (sum, i) => sum + i.amount,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'المستثمرون',
          subtitle: 'إجمالي الاستثمار: ${fmt.money(totalInvested)}',
          actionLabel: 'إضافة مستثمر',
          onAction: () => showInvestorForm(context),
        ),
        DataTableCard<Investor>(
          columns: const [
            'الاسم',
            'الهاتف',
            'مبلغ الاستثمار',
            'نسبة الربح',
            'تاريخ الاستثمار',
            'الأرباح المستحقة',
            'المسحوب',
            'الرصيد',
          ],
          items: s.investors,
          emptyMessage: 'لم تتم إضافة مستثمرين بعد',
          cells: (i) {
            final sh = shareOf[i.id];
            return [
              Text(i.name),
              Text(i.phone),
              Text(fmt.money(i.amount)),
              Text(fmt.percent(i.profitPercent)),
              Text(fmt.date(i.investedAt)),
              Text(fmt.money(sh?.amount ?? 0)),
              Text(fmt.money(sh?.withdrawn ?? 0)),
              Text(
                fmt.money(sh?.balance ?? 0),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ];
          },
          onEdit: (i) => showInvestorForm(context, existing: i),
          onDelete: (i) async {
            if (await confirmDelete(context, i.name)) {
              await s.deleteInvestor(i.id);
            }
          },
        ),
      ],
    );
  }
}

Future<void> showInvestorForm(BuildContext context, {Investor? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final amount = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.amount),
  );
  final pct = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.profitPercent),
  );
  final notes = TextEditingController(text: existing?.notes);
  var date = existing?.investedAt ?? DateTime.now();
  final available = 100 - s.investorsPercentTotal(excludeId: existing?.id);

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة مستثمر' : 'تعديل بيانات المستثمر',
    fields: (setState) => [
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'الاسم'),
        validator: requiredText,
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      TextFormField(
        controller: amount,
        decoration: const InputDecoration(labelText: 'مبلغ الاستثمار'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(),
      ),
      TextFormField(
        controller: pct,
        decoration: InputDecoration(
          labelText: 'نسبته من صافي الربح %',
          helperText: 'المتاح: ${fmt.percent(available)}',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(max: available),
      ),
      DateField(
        label: 'تاريخ الاستثمار',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () => s.saveInvestor(
      Investor(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        phone: phone.text.trim(),
        amount: fmt.parseNumber(amount.text)!,
        profitPercent: fmt.parseNumber(pct.text)!,
        investedAt: date,
        notes: notes.text.trim(),
      ),
    ),
  );
}
