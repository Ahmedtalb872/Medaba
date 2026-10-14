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
    final company = s.companyPartners;
    final deals = s.dealPartners;

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'الشركاء',
          icon: Icons.handshake_outlined,
          subtitle:
              'شركاء الشركة: ${fmt.percent(total)}'
              '${total < 100 && company.isNotEmpty ? ' (غير مكتمل)' : ''}'
              ' • مستثمرون في صفقات: ${deals.length}',
          actionLabel: 'إضافة شريك',
          onAction: () => showPartnerForm(context),
        ),
        const _SectionTitle(
          'شركاء في الشركة كلها',
          'نسبتهم من صافي ربح الشركة',
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
          items: company,
          emptyMessage: 'لا يوجد شركاء في الشركة كلها',
          cells: (p) {
            final sh = shareOf[p.id];
            return [
              Text(p.name),
              Text(p.phone, textDirection: TextDirection.ltr),
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
          onDelete: (p) => _delete(context, s, p),
        ),
        const SizedBox(height: 16),
        const _SectionTitle(
          'مستثمرون في صفقة محددة',
          'سيارة أو قطعة أرضية أو حاوية: نسبتهم من ربح تلك الصفقة فقط',
        ),
        DataTableCard<Partner>(
          columns: const [
            'الاسم',
            'الهاتف',
            'الصفقة',
            'المبلغ المستثمر',
            'النسبة',
            'ربح الصفقة',
            'نصيبه',
            'المسحوب',
          ],
          items: deals,
          emptyMessage:
              'لا يوجد مستثمرون في صفقات. اضغط «إضافة شريك» واختر نوع الصفقة',
          cells: (p) {
            final profit = s.dealProfitOf(p);
            final share = s.dealShareOf(p);
            return [
              Text(p.name),
              Text(p.phone, textDirection: TextDirection.ltr),
              Text(s.dealLabel(p)),
              Text(fmt.money(p.capital)),
              Text(fmt.percent(p.sharePercent)),
              Text(profit == null ? 'لم تنتهِ بعد' : fmt.money(profit)),
              Text(
                share == null ? '-' : fmt.money(share),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(fmt.money(s.withdrawnBy(p.id))),
            ];
          },
          onEdit: (p) => showPartnerForm(context, existing: p),
          onDelete: (p) => _delete(context, s, p),
        ),
      ],
    );
  }

  static Future<void> _delete(
    BuildContext context,
    AppState s,
    Partner p,
  ) async {
    if (await confirmDelete(context, p.name)) await s.deletePartner(p.id);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// إضافة شريك أو تعديله. [scope] و[dealId] يختاران الصفقة مسبقاً
/// (مثل «إضافة مستثمر» من صفحة السيارة).
Future<void> showPartnerForm(
  BuildContext context, {
  Partner? existing,
  PartnerScope? scope,
  String? dealId,
}) {
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
  final dealTitle = TextEditingController(text: existing?.dealTitle);
  final dealProfit = TextEditingController(
    text: existing?.dealProfit == null ? '' : fmt.number(existing!.dealProfit!),
  );
  var joined = existing?.joinedAt ?? DateTime.now();
  var kind = existing?.scope ?? scope ?? PartnerScope.company;
  String? deal = existing?.dealId ?? dealId;

  List<(String, String)> choices() => switch (kind) {
    PartnerScope.car => [for (final c in s.cars) (c.id, c.title)],
    PartnerScope.plot => [
      for (final p in s.plots)
        (p.id, [p.name, if (p.location.isNotEmpty) p.location].join(' • ')),
    ],
    _ => const [],
  };

  /// النسبة المتاحة: من أرباح الشركة، أو من ربح الصفقة المختارة.
  double available() {
    if (kind == PartnerScope.company) {
      return 100 - s.partnersShareTotal(excludeId: existing?.id);
    }
    final probe = Partner(
      id: '',
      name: '',
      sharePercent: 0,
      joinedAt: joined,
      scope: kind,
      dealId: deal,
      dealTitle: dealTitle.text,
    );
    return 100 - s.dealShareTotal(probe.dealKey, excludeId: existing?.id);
  }

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة شريك' : 'تعديل بيانات الشريك',
    fields: (setState) {
      final options = choices();
      if (kind.linked && !options.any((o) => o.$1 == deal)) {
        deal = options.firstOrNull?.$1;
      }
      final avail = available();
      return [
        const Text('الشراكة في'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in PartnerScope.values)
              ChoiceChip(
                label: Text(k.label),
                selected: kind == k,
                onSelected: (_) => setState(() => kind = k),
              ),
          ],
        ),
        if (kind.linked)
          options.isEmpty
              ? Text(
                  kind == PartnerScope.car
                      ? 'لا توجد سيارات مسجلة؛ أضف السيارة أولاً من صفحة السيارات'
                      : 'لا توجد قطع مسجلة؛ أضف القطعة أولاً من صفحة القطع الأرضية',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(kind),
                  initialValue: deal,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: kind.label),
                  items: [
                    for (final o in options)
                      DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => deal = v),
                ),
        if (kind == PartnerScope.container || kind == PartnerScope.other)
          TextFormField(
            controller: dealTitle,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: kind == PartnerScope.container
                  ? 'رقم الحاوية أو وصفها'
                  : 'وصف الصفقة',
            ),
            validator: requiredText,
          ),
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
          controller: capital,
          decoration: InputDecoration(
            labelText: kind == PartnerScope.company
                ? 'رأس المال المدفوع'
                : 'المبلغ المستثمر',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(required: false),
        ),
        TextFormField(
          controller: share,
          decoration: InputDecoration(
            labelText: kind == PartnerScope.company
                ? 'نسبة الشراكة %'
                : 'نسبته من ربح الصفقة %',
            helperText: 'المتاح: ${fmt.percent(avail)}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(min: 0, max: avail),
        ),
        if (kind == PartnerScope.container || kind == PartnerScope.other)
          TextFormField(
            controller: dealProfit,
            decoration: const InputDecoration(
              labelText: 'ربح الصفقة بعد انتهائها (اختياري)',
              helperText: 'اتركه فارغاً حتى تنتهي الصفقة',
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
        DateField(
          label: kind == PartnerScope.company
              ? 'تاريخ الانضمام'
              : 'تاريخ الاستثمار',
          value: joined,
          onChanged: (d) => setState(() => joined = d),
        ),
        TextFormField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'ملاحظات ومعلومات الاستثمار',
          ),
          maxLines: 2,
        ),
      ];
    },
    onSave: () async {
      if (kind.linked && deal == null) return;
      await s.savePartner(
        Partner(
          id: existing?.id ?? newId(),
          name: name.text.trim(),
          phone: phone.text.trim(),
          sharePercent: fmt.parseNumber(share.text)!,
          capital: fmt.parseNumber(capital.text) ?? 0,
          joinedAt: joined,
          notes: notes.text.trim(),
          scope: kind,
          dealId: kind.linked ? deal : null,
          dealTitle: kind.linked || kind == PartnerScope.company
              ? ''
              : dealTitle.text.trim(),
          dealProfit: kind.linked || kind == PartnerScope.company
              ? null
              : fmt.parseNumber(dealProfit.text),
        ),
      );
    },
  );
}
