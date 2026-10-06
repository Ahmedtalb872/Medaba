import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final total = s.partnersShareTotal();
    final report = s.profitReport();
    final shareOf = {for (final p in report.partners) p.id: p};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'الشركاء',
          subtitle:
              'مجموع النسب: ${fmt.percent(total)}'
              '${total < 100 && s.partners.isNotEmpty ? ' (غير مكتمل)' : ''}',
          actionLabel: 'إضافة شريك',
          onAction: () => showPartnerForm(context),
        ),
        DataTableCard<Partner>(
          columns: const [
            'الاسم',
            'الهاتف',
            'النسبة',
            'رأس المال',
            'الأرباح المستحقة',
            'المسحوب',
            'الرصيد',
          ],
          items: s.partners,
          emptyMessage: 'لم تتم إضافة شركاء بعد',
          cells: (p) {
            final sh = shareOf[p.id];
            return [
              Text(p.name),
              Text(p.phone),
              Text(fmt.percent(p.sharePercent)),
              Text(fmt.money(p.capital)),
              Text(fmt.money(sh?.amount ?? 0)),
              Text(fmt.money(sh?.withdrawn ?? 0)),
              Text(
                fmt.money(sh?.balance ?? 0),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ];
          },
          onEdit: (p) => showPartnerForm(context, existing: p),
          onDelete: (p) async {
            if (await confirmDelete(context, p.name)) {
              await s.deletePartner(p.id);
            }
          },
        ),
      ],
    );
  }
}

Future<void> showPartnerForm(BuildContext context, {Partner? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final share = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.sharePercent),
  );
  final capital = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.capital),
  );
  final notes = TextEditingController(text: existing?.notes);
  var joined = existing?.joinedAt ?? DateTime.now();
  final available = 100 - s.partnersShareTotal(excludeId: existing?.id);

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة شريك' : 'تعديل بيانات الشريك',
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
        controller: share,
        decoration: InputDecoration(
          labelText: 'نسبة الشراكة %',
          helperText: 'المتاح: ${fmt.percent(available)}',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0, max: available),
      ),
      TextFormField(
        controller: capital,
        decoration: const InputDecoration(labelText: 'رأس المال المدفوع'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(required: false),
      ),
      DateField(
        label: 'تاريخ الانضمام',
        value: joined,
        onChanged: (d) => setState(() => joined = d),
      ),
      TextFormField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () => s.savePartner(
      Partner(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        phone: phone.text.trim(),
        sharePercent: fmt.parseNumber(share.text)!,
        capital: fmt.parseNumber(capital.text) ?? 0,
        joinedAt: joined,
        notes: notes.text.trim(),
      ),
    ),
  );
}
