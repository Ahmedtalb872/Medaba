import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/plot.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import 'partners_screen.dart';
import '../widgets/data_table_card.dart';

enum _View {
  open('غير المباعة'),
  sold('المباعة'),
  all('الكل');

  final String label;
  const _View(this.label);
}

/// القطع الأرضية: الشراء، تكاليف البناء، البيع والربح.
class PlotsScreen extends StatefulWidget {
  const PlotsScreen({super.key});

  @override
  State<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends State<PlotsScreen> {
  _View _view = _View.open;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final open = s.plots.where((x) => !x.isSold).toList();
    final sold = s.plots.where((x) => x.isSold).toList();
    final items = switch (_view) {
      _View.open => open,
      _View.sold => sold,
      _View.all => s.plots,
    };
    final profit = sold.fold(0.0, (t, x) => t + x.profit!);

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'القطع الأرضية',
          icon: Icons.landscape_outlined,
          subtitle: 'شراء القطع وبناؤها وبيعها، مع ربح كل قطعة',
          actionLabel: 'قطعة جديدة',
          onAction: () => showPlotForm(context),
        ),
        StatGrid(
          children: [
            StatCard(
              label: 'قطع لم تُبع',
              value: '${open.length}',
              icon: Icons.landscape_outlined,
              colors: AppColors.capital,
            ),
            StatCard(
              label: 'قيد البناء',
              value:
                  '${open.where((x) => x.status == PlotStatus.building).length}',
              icon: Icons.construction,
              colors: AppColors.workers,
            ),
            StatCard(
              label: 'المدفوع في القطع غير المباعة',
              value: fmt.money(open.fold(0.0, (t, x) => t + x.totalCost)),
              icon: Icons.account_balance_outlined,
              colors: AppColors.profit,
            ),
            StatCard(
              label: 'أرباح القطع المباعة',
              value: fmt.money(profit),
              icon: Icons.trending_up,
              colors: profit >= 0 ? AppColors.income : AppColors.loss,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<_View>(
          segments: [
            for (final v in _View.values)
              ButtonSegment(value: v, label: Text(v.label)),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
        const SizedBox(height: 12),
        DataTableCard<Plot>(
          columns: const [
            'القطعة',
            'الموقع',
            'المساحة',
            'سعر الشراء',
            'تكاليف البناء',
            'إجمالي التكلفة',
            'الحالة',
            'سعر البيع',
            'الربح',
            'المستثمرون',
          ],
          items: items,
          emptyMessage: 'لا توجد قطع هنا',
          cells: (x) => [
            Text(x.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(x.location.isEmpty ? '-' : x.location),
            Text(x.area == 0 ? '-' : '${fmt.number(x.area)} م²'),
            Text(fmt.money(x.purchasePrice)),
            Tooltip(
              message: x.costs.isEmpty
                  ? 'لا توجد تكاليف بعد'
                  : [
                      for (final c in x.costs)
                        '${c.label}: ${fmt.money(c.amount)} (${fmt.date(c.date)})',
                    ].join('\n'),
              child: Text(fmt.money(x.costsTotal)),
            ),
            Text(
              fmt.money(x.totalCost),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _StatusChip(status: x.status),
            Text(x.isSold ? fmt.money(x.salePrice) : '-'),
            x.profit == null
                ? const Text('-')
                : Text(
                    fmt.money(x.profit!),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: x.profit! >= 0
                          ? AppColors.income.last
                          : AppColors.expense.last,
                    ),
                  ),
            Text(
              s
                  .investorsIn(PartnerScope.plot, x.id)
                  .map((p) {
                    final share = x.profit == null
                        ? fmt.percent(p.sharePercent)
                        : fmt.money(x.profit! * p.sharePercent / 100);
                    return '${p.name} ($share)';
                  })
                  .join('، ')
                  .orDash,
            ),
          ],
          extraActions: (x) => [
            TableAction(
              tooltip: 'إضافة مستثمر',
              icon: Icons.person_add_alt_1,
              color: AppColors.capital.last,
              onTap: () => showPartnerForm(
                context,
                scope: PartnerScope.plot,
                dealId: x.id,
              ),
            ),
            TableAction(
              tooltip: 'إضافة تكلفة',
              icon: Icons.add_card_outlined,
              color: AppColors.gold,
              onTap: x.isSold ? null : () => showPlotCostForm(context, x),
            ),
          ],
          onEdit: (x) => showPlotForm(context, existing: x),
          onDelete: (x) async {
            if (await confirmDelete(context, 'القطعة ${x.name}')) {
              await s.deletePlot(x.id);
            }
          },
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PlotStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlotStatus.land => AppColors.capital.last,
      PlotStatus.building => AppColors.workers.last,
      PlotStatus.ready => AppColors.income.last,
      PlotStatus.sold => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// تكلفة سريعة على قطعة (أسمنت، عمال، رسوم...) دون فتح نموذج القطعة كله.
Future<void> showPlotCostForm(BuildContext context, Plot plot) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final label = TextEditingController();
  final amount = TextEditingController();
  var date = DateTime.now();
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'تكلفة على ${plot.name}',
    fields: (setState) => [
      TextFormField(
        controller: label,
        decoration: const InputDecoration(
          labelText: 'البيان',
          hintText: 'أسمنت، حديد، عمال، رسوم، كهرباء...',
        ),
        validator: requiredText,
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
    ],
    onSave: () => s.addPlotCost(
      plot.id,
      PlotCost(label.text.trim(), fmt.parseNumber(amount.text)!, date),
    ),
  );
}

Future<void> showPlotForm(BuildContext context, {Plot? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  String money(double? v) => v == null || v == 0 ? '' : fmt.number(v);
  final name = TextEditingController(text: existing?.name);
  final location = TextEditingController(text: existing?.location);
  final area = TextEditingController(text: money(existing?.area));
  final price = TextEditingController(text: money(existing?.purchasePrice));
  final buyer = TextEditingController(text: existing?.buyer);
  final salePrice = TextEditingController(text: money(existing?.salePrice));
  final note = TextEditingController(text: existing?.note);
  var purchaseDate = existing?.purchaseDate ?? DateTime.now();
  var saleDate = existing?.saleDate ?? DateTime.now();
  var status = existing?.status ?? PlotStatus.land;
  final costs = [
    for (final c in existing?.costs ?? const <PlotCost>[])
      (
        label: TextEditingController(text: c.label),
        amount: TextEditingController(text: money(c.amount)),
        date: c.date,
      ),
  ];
  const decimal = TextInputType.numberWithOptions(decimal: true);

  Widget pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'قطعة أرضية جديدة' : 'تعديل القطعة',
    fields: (setState) => [
      pair(
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'اسم / رقم القطعة'),
          validator: requiredText,
        ),
        TextFormField(
          controller: location,
          decoration: const InputDecoration(
            labelText: 'الموقع',
            hintText: 'تفرغ زينة، توجنين...',
          ),
        ),
      ),
      pair(
        TextFormField(
          controller: area,
          decoration: const InputDecoration(
            labelText: 'المساحة',
            suffixText: 'م²',
          ),
          keyboardType: decimal,
          validator: numberValidator(required: false),
        ),
        TextFormField(
          controller: price,
          decoration: const InputDecoration(labelText: 'سعر الشراء'),
          keyboardType: decimal,
          validator: numberValidator(),
        ),
      ),
      DateField(
        label: 'تاريخ الشراء',
        value: purchaseDate,
        onChanged: (d) => setState(() => purchaseDate = d),
      ),
      DropdownButtonFormField<PlotStatus>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'الحالة'),
        items: [
          for (final st in PlotStatus.values)
            DropdownMenuItem(value: st, child: Text(st.label)),
        ],
        onChanged: (v) => setState(() => status = v!),
      ),
      if (costs.isNotEmpty)
        const Text(
          'تكاليف البناء والرسوم',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      for (final (i, c) in costs.indexed)
        Row(
          key: ObjectKey(c),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: c.label,
                decoration: const InputDecoration(
                  labelText: 'البيان',
                  hintText: 'أسمنت، عمال، رسوم...',
                ),
                validator: requiredText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: c.amount,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: decimal,
                validator: numberValidator(),
              ),
            ),
            IconButton(
              tooltip: 'حذف التكلفة',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() => costs.removeAt(i)),
            ),
          ],
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: () => setState(
            () => costs.add((
              label: TextEditingController(),
              amount: TextEditingController(),
              date: DateTime.now(),
            )),
          ),
          icon: const Icon(Icons.add),
          label: const Text('إضافة تكلفة بناء'),
        ),
      ),
      if (status == PlotStatus.sold) ...[
        const Text('البيع', style: TextStyle(fontWeight: FontWeight.bold)),
        pair(
          TextFormField(
            controller: buyer,
            decoration: const InputDecoration(labelText: 'المشتري'),
          ),
          TextFormField(
            controller: salePrice,
            decoration: const InputDecoration(labelText: 'سعر البيع'),
            keyboardType: decimal,
            validator: numberValidator(min: 0.01),
          ),
        ),
        DateField(
          label: 'تاريخ البيع',
          value: saleDate,
          onChanged: (d) => setState(() => saleDate = d),
        ),
      ],
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () async {
      final sold = status == PlotStatus.sold;
      try {
        await s.savePlot(
          Plot(
            id: existing?.id ?? newId(),
            name: name.text.trim(),
            location: location.text.trim(),
            area: fmt.parseNumber(area.text) ?? 0,
            purchaseDate: purchaseDate,
            purchasePrice: fmt.parseNumber(price.text) ?? 0,
            costs: [
              for (final c in costs)
                PlotCost(
                  c.label.text.trim(),
                  fmt.parseNumber(c.amount.text) ?? 0,
                  c.date,
                ),
            ],
            status: status,
            buyer: sold ? buyer.text.trim() : '',
            salePrice: sold ? fmt.parseNumber(salePrice.text) ?? 0 : 0,
            saleDate: sold ? saleDate : null,
            note: note.text.trim(),
          ),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

extension on String {
  String get orDash => isEmpty ? '-' : this;
}
