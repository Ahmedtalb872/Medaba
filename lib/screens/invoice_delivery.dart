import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/models.dart' show newId;
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';

/// داخل فاتورة البيع: الكمية الأصلية والمأخوذ والمتبقي لكل صنف،
/// مع سجل دفعات التسليم بتواريخها. يظهر بزر حتى لا يزحم الفاتورة.
class DeliveryPanel extends StatelessWidget {
  /// الفاتورة كما هي في المحرر الآن (قبل الحفظ).
  final Invoice invoice;
  final String Function(String productId) productName;
  final String Function(String productId) unitOf;

  /// يُستدعى عند تفعيل التسليم على دفعات أو إيقافه، أو تغيّر السجل.
  final void Function(bool partial, List<Delivery> deliveries) onChanged;

  const DeliveryPanel({
    super.key,
    required this.invoice,
    required this.productName,
    required this.unitOf,
    required this.onChanged,
  });

  bool get _partial => invoice.partialDelivery;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ids = invoice.productIds;
    final history = [...invoice.deliveries]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الزبون يأخذ البضاعة على دفعات'),
          subtitle: const Text('دفع ثمن الكمية كلها وترك جزءاً منها في المخزن'),
          value: _partial,
          onChanged: (v) => onChanged(v, invoice.deliveries),
        ),
        if (!_partial)
          Text(
            'الآن: الزبون أخذ الكمية كلها عند البيع.',
            style: TextStyle(color: muted),
          )
        else ...[
          const SizedBox(height: 8),
          for (final pid in ids) _row(context, pid),
          if (ids.isEmpty) const EmptyState(message: 'أضف أصناف الفاتورة'),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: ids.any((p) => invoice.leftOf(p) > 1e-9)
                ? () => _deliver(context)
                : null,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('تسليم دفعة للزبون'),
          ),
          const SizedBox(height: 16),
          Text(
            'سجل التسليم',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لم يأخذ الزبون شيئاً بعد',
                style: TextStyle(color: muted),
              ),
            ),
          for (final d in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(fmt.dateTime(d.date)),
              subtitle: Text(
                [
                  for (final e in d.items.entries)
                    '${productName(e.key)}: ${fmt.number(e.value)} ${unitOf(e.key)}',
                  if (d.note.isNotEmpty) d.note,
                ].join('\n'),
              ),
              trailing: IconButton(
                tooltip: 'حذف الدفعة',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!await confirmDelete(
                    context,
                    'دفعة ${fmt.dateTime(d.date)}',
                  )) {
                    return;
                  }
                  onChanged(true, [
                    for (final x in invoice.deliveries)
                      if (x.id != d.id) x,
                  ]);
                },
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'تُحفظ التغييرات عند الضغط على «حفظ الفاتورة».',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String pid) {
    final total = invoice.qtyOf(pid);
    final taken = invoice.takenOf(pid);
    final left = invoice.leftOf(pid);
    final unit = unitOf(pid);
    Widget cell(String label, double v, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            '${fmt.number(v)} $unit',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              productName(pid),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                cell('الأصلية', total, AppColors.brand),
                cell('المأخوذ', taken, AppColors.ok.last),
                cell(
                  'المتبقي',
                  left,
                  left > 1e-9 ? AppColors.gold : AppColors.ok.last,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total <= 0 ? 0 : (taken / total).clamp(0, 1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deliver(BuildContext context) {
    final key = GlobalKey<FormState>();
    final ids = [
      for (final p in invoice.productIds)
        if (invoice.leftOf(p) > 1e-9) p,
    ];
    final qty = {for (final p in ids) p: TextEditingController()};
    final note = TextEditingController();
    var date = DateTime.now();
    return showFormDialog(
      context: context,
      formKey: key,
      title: 'تسليم دفعة للزبون',
      fields: (setState) => [
        DateField(
          label: 'تاريخ التسليم',
          value: date,
          onChanged: (d) => setState(() => date = d),
        ),
        for (final p in ids)
          TextFormField(
            controller: qty[p],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المأخوذ من ${productName(p)}',
              helperText:
                  'المتبقي ${fmt.number(invoice.leftOf(p))} ${unitOf(p)}',
              suffixIcon: TextButton(
                onPressed: () => qty[p]!.text = fmt.number(invoice.leftOf(p)),
                child: const Text('الكل'),
              ),
            ),
            validator: numberValidator(required: false, max: invoice.leftOf(p)),
          ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(
            labelText: 'ملاحظة (من استلم، السيارة...)',
          ),
        ),
      ],
      onSave: () async {
        final items = <String, double>{
          for (final p in ids)
            if ((fmt.parseNumber(qty[p]!.text) ?? 0) > 0)
              p: fmt.parseNumber(qty[p]!.text)!,
        };
        if (items.isEmpty) return;
        // التاريخ المختار مع ساعة التسليم الآن، ليظهر ترتيب الدفعات في اليوم.
        final now = DateTime.now();
        final at = DateTime(
          date.year,
          date.month,
          date.day,
          now.hour,
          now.minute,
        );
        onChanged(true, [
          ...invoice.deliveries,
          Delivery(id: newId(), date: at, items: items, note: note.text.trim()),
        ]);
      },
    );
  }
}
