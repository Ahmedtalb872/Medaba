import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/invoice.dart';
import '../models/plot.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import 'cars_screen.dart';
import 'invoices_screen.dart';
import 'plots_screen.dart';

/// الأنشطة الثلاثة التي يديرها النظام.
enum Business {
  cars('للسيارات', 'السيارات المستوردة', Icons.directions_car_filled),
  plots('للقطع الأرضية', 'شراء القطع وبيعها', Icons.landscape),
  trade('للتجارة العامة', 'فواتير البضائع والمخزون', Icons.storefront);

  final String suffix;
  final String hint;
  final IconData icon;
  const Business(this.suffix, this.hint, this.icon);

  Color get color => switch (this) {
    Business.cars => const Color(0xFF1E6FD9),
    Business.plots => const Color(0xFFB7791F),
    Business.trade => AppColors.brand,
  };
}

/// يسأل عن النشاط ثم يفتح شراءه أو بيعه.
Future<void> startDeal(BuildContext context, {required bool sale}) async {
  final s = context.read<AppState>();
  final brand = s.company.name.trim().split(' ').first;
  final business = await showDialog<Business>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(sale ? 'بيع جديد' : 'شراء جديد'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in Business.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BusinessTile(
                  title: '$brand ${b.suffix}',
                  subtitle: b.hint,
                  icon: b.icon,
                  color: b.color,
                  onTap: () => Navigator.pop(dialog, b),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('إلغاء'),
        ),
      ],
    ),
  );
  if (business == null || !context.mounted) return;
  switch ((business, sale)) {
    case (Business.trade, _):
      await openInvoiceEditor(
        context,
        sale ? InvoiceType.sale : InvoiceType.purchase,
      );
    case (Business.cars, false):
      await showCarForm(context);
    case (Business.cars, true):
      await showSellCarForm(context);
    case (Business.plots, false):
      await showPlotForm(context);
    case (Business.plots, true):
      await showSellPlotForm(context);
  }
}

class _BusinessTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BusinessTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: color),
          ],
        ),
      ),
    ),
  );
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// سطر «التكلفة / الربح» يتحدث مع كتابة سعر البيع.
Widget _profitLine(double cost, String priceText) {
  final price = fmt.parseNumber(priceText);
  final profit = price == null ? null : price - cost;
  return Text(
    profit == null
        ? 'إجمالي التكلفة: ${fmt.money(cost)}'
        : '${profit >= 0 ? 'الربح' : 'الخسارة'}: ${fmt.money(profit.abs())}'
              '  (التكلفة ${fmt.money(cost)})',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: profit == null
          ? null
          : profit >= 0
          ? AppColors.income.last
          : AppColors.expense.last,
    ),
  );
}

/// بيع سيارة من السيارات غير المباعة (التي في المعرض أولاً).
Future<void> showSellCarForm(BuildContext context, {Car? car}) {
  final s = context.read<AppState>();
  final cars = s.cars.where((x) => !x.isSold).toList()
    ..sort((a, b) {
      final ai = a.status == CarStatus.inStock ? 0 : 1;
      final bi = b.status == CarStatus.inStock ? 0 : 1;
      return ai.compareTo(bi);
    });
  if (cars.isEmpty) {
    _snack(context, 'لا توجد سيارات غير مباعة');
    return Future.value();
  }
  final key = GlobalKey<FormState>();
  var selected = car ?? cars.first;
  final buyer = TextEditingController();
  final phone = TextEditingController();
  final price = TextEditingController();
  var date = DateTime.now();
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'بيع سيارة',
    fields: (setState) => [
      DropdownButtonFormField<String>(
        initialValue: selected.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'السيارة'),
        items: [
          for (final c in cars)
            DropdownMenuItem(
              value: c.id,
              child: Text(
                '${c.title} • ${c.status.label}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) =>
            setState(() => selected = cars.firstWhere((c) => c.id == v)),
      ),
      TextFormField(
        controller: buyer,
        decoration: const InputDecoration(labelText: 'المشتري'),
        validator: requiredText,
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'هاتف المشتري'),
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
      ),
      TextFormField(
        controller: price,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'سعر البيع'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01),
      ),
      _profitLine(selected.totalCost, price.text),
      DateField(
        label: 'تاريخ البيع',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
    ],
    onSave: () async {
      try {
        await s.saveCar(
          Car.fromJson({
            ...selected.toJson(),
            'status': CarStatus.sold.name,
            'buyer': buyer.text.trim(),
            'buyerPhone': phone.text.trim(),
            'salePrice': fmt.parseNumber(price.text),
            'saleDate': date.toIso8601String(),
          }),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

/// بيع قطعة أرضية من القطع غير المباعة.
Future<void> showSellPlotForm(BuildContext context) {
  final s = context.read<AppState>();
  final plots = s.plots.where((x) => !x.isSold).toList();
  if (plots.isEmpty) {
    _snack(context, 'لا توجد قطع غير مباعة');
    return Future.value();
  }
  final key = GlobalKey<FormState>();
  var selected = plots.first;
  final buyer = TextEditingController();
  final price = TextEditingController();
  var date = DateTime.now();
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'بيع قطعة أرضية',
    fields: (setState) => [
      DropdownButtonFormField<String>(
        initialValue: selected.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'القطعة'),
        items: [
          for (final p in plots)
            DropdownMenuItem(
              value: p.id,
              child: Text(
                [
                  p.name,
                  if (p.location.isNotEmpty) p.location,
                  p.status.label,
                ].join(' • '),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) =>
            setState(() => selected = plots.firstWhere((p) => p.id == v)),
      ),
      TextFormField(
        controller: buyer,
        decoration: const InputDecoration(labelText: 'المشتري'),
        validator: requiredText,
      ),
      TextFormField(
        controller: price,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'سعر البيع'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01),
      ),
      _profitLine(selected.totalCost, price.text),
      DateField(
        label: 'تاريخ البيع',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
    ],
    onSave: () async {
      try {
        await s.savePlot(
          Plot.fromJson({
            ...selected.toJson(),
            'status': PlotStatus.sold.name,
            'buyer': buyer.text.trim(),
            'salePrice': fmt.parseNumber(price.text),
            'saleDate': date.toIso8601String(),
          }),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}
