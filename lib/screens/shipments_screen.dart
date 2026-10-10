import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/shipment.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

enum _View {
  active('الجارية'),
  received('المستلمة'),
  all('الكل');

  final String label;
  const _View(this.label);
}

/// الشحنات البحرية الواردة، موزعة على شركات الشحن.
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  _View _view = _View.active;
  String? _company;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final active = s.activeShipments;
    final companies = s.shippingCompanies;
    if (_company != null && !companies.contains(_company)) _company = null;

    final items = s.shipments.where((x) {
      if (_company != null && x.company != _company) return false;
      return switch (_view) {
        _View.active => !x.isReceived,
        _View.received => x.isReceived,
        _View.all => true,
      };
    }).toList();

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'الشحنات البحرية',
          icon: Icons.directions_boat_outlined,
          subtitle: 'الحاويات الواردة عبر شركات الشحن حتى استلامها',
          actionLabel: 'شحنة جديدة',
          onAction: () => showShipmentForm(context),
        ),
        StatGrid(
          children: [
            StatCard(
              label: 'في البحر',
              value:
                  '${active.where((x) => x.status == ShipmentStatus.atSea).length}',
              icon: Icons.directions_boat_outlined,
              colors: AppColors.capital,
            ),
            StatCard(
              label: 'في الميناء والجمارك',
              value:
                  '${active.where((x) => x.status != ShipmentStatus.atSea).length}',
              icon: Icons.anchor,
              colors: AppColors.cash,
            ),
            StatCard(
              label: 'متأخرة عن موعدها',
              value: '${s.delayedShipments(now)}',
              icon: Icons.schedule,
              colors: s.delayedShipments(now) == 0
                  ? AppColors.ok
                  : AppColors.loss,
            ),
            StatCard(
              label: 'تكلفة الشحنات الجارية',
              value: fmt.money(active.fold(0.0, (t, x) => t + x.totalCost)),
              icon: Icons.payments_outlined,
              colors: AppColors.profit,
            ),
          ],
        ),
        if (companies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in companies)
                _CompanyCard(
                  name: c,
                  shipments: [
                    for (final x in active)
                      if (x.company == c) x,
                  ],
                  selected: _company == c,
                  onTap: () =>
                      setState(() => _company = _company == c ? null : c),
                ),
            ],
          ),
        ],
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
        DataTableCard<Shipment>(
          columns: const [
            'الشركة',
            'البوليصة',
            'الحاوية',
            'البضاعة',
            'من ميناء',
            'الوصول المتوقع',
            'التكلفة',
            'الحالة',
          ],
          items: items,
          emptyMessage: 'لا توجد شحنات هنا',
          cells: (x) => [
            Text(x.company),
            Text(
              x.billOfLading.isEmpty ? '-' : x.billOfLading,
              textDirection: TextDirection.ltr,
            ),
            Text(
              x.containerNumber.isEmpty ? '-' : x.containerNumber,
              textDirection: TextDirection.ltr,
            ),
            Text(
              x.contents,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(x.originPort.isEmpty ? '-' : x.originPort),
            _Arrival(shipment: x, now: now),
            Text(fmt.money(x.totalCost)),
            _StatusChip(shipment: x, now: now),
          ],
          extraActions: (x) => [
            PopupMenuButton<ShipmentStatus>(
              tooltip: 'تغيير الحالة',
              icon: Icon(Icons.swap_horiz, color: AppColors.capital.last),
              onSelected: (st) => s.setShipmentStatus(x.id, st),
              itemBuilder: (_) => [
                for (final st in ShipmentStatus.values)
                  CheckedPopupMenuItem(
                    value: st,
                    checked: st == x.status,
                    child: Text(st.label),
                  ),
              ],
            ),
          ],
          onEdit: (x) => showShipmentForm(context, existing: x),
          onDelete: (x) async {
            if (await confirmDelete(context, 'شحنة ${x.contents}')) {
              await s.deleteShipment(x.id);
            }
          },
        ),
      ],
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final String name;
  final List<Shipment> shipments;
  final bool selected;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.name,
    required this.shipments,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cost = shipments.fold(0.0, (t, x) => t + x.totalCost);
    return SizedBox(
      width: 300,
      child: Card(
        color: selected ? AppColors.brandLight : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sailing_outlined, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${shipments.length} جارية  •  ${fmt.money(cost)}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.filter_alt, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrival extends StatelessWidget {
  final Shipment shipment;
  final DateTime now;
  const _Arrival({required this.shipment, required this.now});

  @override
  Widget build(BuildContext context) {
    final x = shipment;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (x.isReceived) {
      return Text(
        'استُلمت ${x.receivedDate == null ? '' : fmt.date(x.receivedDate!)}',
        style: TextStyle(color: muted),
      );
    }
    final days = x.daysToArrival(now);
    final hint = x.status != ShipmentStatus.atSea
        ? ''
        : days > 0
        ? 'بعد $days يوم'
        : days == 0
        ? 'اليوم'
        : 'متأخرة ${-days} يوم';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmt.date(x.expectedArrival)),
        if (hint.isNotEmpty)
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: days < 0 ? AppColors.expense.last : muted,
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Shipment shipment;
  final DateTime now;
  const _StatusChip({required this.shipment, required this.now});

  @override
  Widget build(BuildContext context) {
    final color = shipment.isDelayed(now)
        ? AppColors.expense.last
        : switch (shipment.status) {
            ShipmentStatus.atSea => AppColors.capital.last,
            ShipmentStatus.atPort => AppColors.cash.last,
            ShipmentStatus.customs => AppColors.profit.last,
            ShipmentStatus.received => AppColors.income.last,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        shipment.isDelayed(now) ? 'متأخرة' : shipment.status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<void> showShipmentForm(BuildContext context, {Shipment? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final company = TextEditingController(text: existing?.company);
  final bl = TextEditingController(text: existing?.billOfLading);
  final container = TextEditingController(text: existing?.containerNumber);
  final contents = TextEditingController(text: existing?.contents);
  final origin = TextEditingController(text: existing?.originPort);
  final destination = TextEditingController(
    text: existing?.destinationPort ?? 'نواكشوط',
  );
  String money(double? v) => v == null || v == 0 ? '' : fmt.number(v);
  final goods = TextEditingController(text: money(existing?.goodsValue));
  final freight = TextEditingController(text: money(existing?.freightCost));
  final customs = TextEditingController(text: money(existing?.customsCost));
  final note = TextEditingController(text: existing?.note);
  final today = DateTime.now();
  var departure = existing?.departureDate ?? today;
  var arrival =
      existing?.expectedArrival ?? today.add(const Duration(days: 14));
  var status = existing?.status ?? ShipmentStatus.atSea;
  final companies = s.shippingCompanies;
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
    title: existing == null ? 'شحنة بحرية جديدة' : 'تعديل الشحنة',
    fields: (setState) => [
      TextFormField(
        controller: company,
        decoration: const InputDecoration(labelText: 'شركة الشحن'),
        validator: requiredText,
      ),
      if (companies.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in companies)
              ActionChip(
                label: Text(c),
                onPressed: () => setState(() => company.text = c),
              ),
          ],
        ),
      TextFormField(
        controller: contents,
        decoration: const InputDecoration(labelText: 'البضاعة'),
        validator: requiredText,
      ),
      pair(
        TextFormField(
          controller: bl,
          decoration: const InputDecoration(labelText: 'رقم البوليصة'),
          textDirection: TextDirection.ltr,
        ),
        TextFormField(
          controller: container,
          decoration: const InputDecoration(labelText: 'رقم الحاوية'),
          textDirection: TextDirection.ltr,
        ),
      ),
      pair(
        TextFormField(
          controller: origin,
          decoration: const InputDecoration(labelText: 'ميناء الشحن'),
        ),
        TextFormField(
          controller: destination,
          decoration: const InputDecoration(labelText: 'ميناء الوصول'),
        ),
      ),
      DateField(
        label: 'تاريخ الإبحار',
        value: departure,
        onChanged: (d) => setState(() => departure = d),
      ),
      DateField(
        label: 'الوصول المتوقع',
        value: arrival,
        onChanged: (d) => setState(() => arrival = d),
      ),
      DropdownButtonFormField<ShipmentStatus>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'الحالة'),
        items: [
          for (final st in ShipmentStatus.values)
            DropdownMenuItem(value: st, child: Text(st.label)),
        ],
        onChanged: (v) => setState(() => status = v!),
      ),
      TextFormField(
        controller: goods,
        decoration: const InputDecoration(labelText: 'قيمة البضاعة'),
        keyboardType: decimal,
        validator: numberValidator(required: false),
      ),
      pair(
        TextFormField(
          controller: freight,
          decoration: const InputDecoration(labelText: 'تكلفة الشحن'),
          keyboardType: decimal,
          validator: numberValidator(required: false),
        ),
        TextFormField(
          controller: customs,
          decoration: const InputDecoration(labelText: 'الجمارك والتخليص'),
          keyboardType: decimal,
          validator: numberValidator(required: false),
        ),
      ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () async {
      final received = status == ShipmentStatus.received;
      try {
        await s.saveShipment(
          Shipment(
            id: existing?.id ?? newId(),
            company: company.text.trim(),
            billOfLading: bl.text.trim(),
            containerNumber: container.text.trim(),
            contents: contents.text.trim(),
            originPort: origin.text.trim(),
            destinationPort: destination.text.trim(),
            departureDate: departure,
            expectedArrival: arrival,
            receivedDate: received
                ? existing?.receivedDate ?? DateTime.now()
                : null,
            status: status,
            goodsValue: fmt.parseNumber(goods.text) ?? 0,
            freightCost: fmt.parseNumber(freight.text) ?? 0,
            customsCost: fmt.parseNumber(customs.text) ?? 0,
            note: note.text.trim(),
          ),
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}
