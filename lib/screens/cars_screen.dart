import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/car_card_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/share_pdf.dart';
import '../utils/format.dart' as fmt;
import '../utils/product_image.dart';
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';
import 'business_actions.dart';

enum _View {
  open('غير المباعة'),
  onTheWay('في الطريق'),
  sold('المباعة'),
  all('الكل');

  final String label;
  const _View(this.label);
}

/// السيارات المستوردة: الشحن، المصاريف، العرض والبيع.
class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  _View _view = _View.open;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final open = s.cars.where((x) => !x.isSold).toList();
    final sold = s.cars.where((x) => x.isSold).toList();
    final items = switch (_view) {
      _View.open => open,
      _View.onTheWay => s.carsOnTheWay,
      _View.sold => sold,
      _View.all => s.cars,
    };
    final profit = sold.fold(0.0, (t, x) => t + x.profit!);
    final late = s.lateCars(now);

    return ListView(
      padding: pagePadding,
      children: [
        PageHeader(
          title: 'السيارات',
          icon: Icons.directions_car_outlined,
          subtitle: 'السيارات المستوردة من الشحن حتى البيع، ومصاريف كل سيارة',
          actionLabel: 'سيارة جديدة',
          onAction: () => showCarForm(context),
        ),
        StatGrid(
          children: [
            StatCard(
              label: late == 0 ? 'في الطريق' : 'في الطريق (متأخرة: $late)',
              value: '${s.carsOnTheWay.length}',
              icon: Icons.directions_boat_outlined,
              colors: late == 0 ? AppColors.capital : AppColors.loss,
            ),
            StatCard(
              label: 'في المعرض',
              value:
                  '${open.where((x) => x.status == CarStatus.inStock).length}',
              icon: Icons.directions_car_outlined,
              colors: AppColors.cash,
            ),
            StatCard(
              label: 'المدفوع في السيارات غير المباعة',
              value: fmt.money(open.fold(0.0, (t, x) => t + x.totalCost)),
              icon: Icons.payments_outlined,
              colors: AppColors.profit,
            ),
            StatCard(
              label: 'أرباح السيارات المباعة',
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
        DataTableCard<Car>(
          columns: const [
            'الصورة',
            'السيارة',
            'الشاسيه / اللوحة',
            'الحالة',
            'الوصول',
            'إجمالي التكلفة',
            'سعر البيع',
            'الربح',
          ],
          items: items,
          emptyMessage: 'لا توجد سيارات هنا',
          cells: (x) => [
            CarPhoto(car: x, size: 44),
            InkWell(
              onTap: () => openCarCard(context, x),
              child: Text(
                x.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              [
                x.vin,
                x.plate,
              ].where((t) => t.isNotEmpty).join(' / ').ifEmpty('-'),
              textDirection: TextDirection.ltr,
            ),
            CarStatusChip(car: x, now: now),
            Text(_arrival(x, now)),
            Text(
              fmt.money(x.totalCost),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
          ],
          extraActions: (x) => [
            TableAction(
              tooltip: 'بطاقة السيارة',
              icon: Icons.badge_outlined,
              color: AppColors.capital.last,
              onTap: () => openCarCard(context, x),
            ),
            TableAction(
              tooltip: 'بيع السيارة',
              icon: Icons.sell_outlined,
              color: AppColors.income.last,
              onTap: x.isSold ? null : () => showSellCarForm(context, car: x),
            ),
            TableAction(
              tooltip: 'إضافة مصروف',
              icon: Icons.add_card_outlined,
              color: AppColors.gold,
              onTap: x.isSold ? null : () => showCarCostForm(context, x),
            ),
          ],
          onEdit: (x) => showCarForm(context, existing: x),
          onDelete: (x) async {
            if (await confirmDelete(context, x.title)) {
              await s.deleteCar(x.id);
            }
          },
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

String _arrival(Car x, DateTime now) {
  final a = x.arrivalDate;
  if (a == null) return '-';
  if (!x.status.onTheWay || x.status == CarStatus.atPort) return fmt.date(a);
  final days = x.daysToArrival(now)!;
  final when = days > 0
      ? 'بعد $days يوم'
      : days == 0
      ? 'اليوم'
      : 'متأخرة ${-days} يوم';
  return '${fmt.date(a)} ($when)';
}

/// صورة السيارة، أو أيقونة عند عدم وجودها.
class CarPhoto extends StatelessWidget {
  final Car? car;
  final String? photo;
  final double size;
  final VoidCallback? onTap;
  const CarPhoto({super.key, this.car, this.photo, this.size = 48, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = photo ?? car?.photo;
    final box = Container(
      width: size * 1.4,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: image != null
          ? Image.memory(
              productImageBytes(image),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Icon(
              onTap == null
                  ? Icons.directions_car_outlined
                  : Icons.add_a_photo_outlined,
              size: size * 0.5,
              color: cs.onSurfaceVariant,
            ),
    );
    if (onTap == null) return box;
    return Tooltip(
      message: image == null ? 'رفع صورة السيارة' : 'تغيير الصورة',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class CarStatusChip extends StatelessWidget {
  final Car car;
  final DateTime now;
  const CarStatusChip({super.key, required this.car, required this.now});

  @override
  Widget build(BuildContext context) {
    final late = car.isLate(now);
    final color = late
        ? AppColors.expense.last
        : switch (car.status) {
            CarStatus.purchased => Colors.blueGrey.shade600,
            CarStatus.atSea => AppColors.capital.last,
            CarStatus.atPort => AppColors.workers.last,
            CarStatus.inStock => AppColors.income.last,
            CarStatus.sold => Colors.grey.shade700,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        late ? 'متأخرة في البحر' : car.status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// مصروف جديد على السيارة، مع أزرار للمصاريف الشائعة.
Future<void> showCarCostForm(BuildContext context, Car car) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final label = TextEditingController();
  final amount = TextEditingController();
  var date = DateTime.now();
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'مصروف على ${car.title}',
    fields: (setState) => [
      TextFormField(
        controller: label,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'البيان'),
        validator: requiredText,
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in CarCost.common)
            ChoiceChip(
              label: Text(c),
              selected: label.text.trim() == c,
              onSelected: (_) => setState(() => label.text = c),
            ),
        ],
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
    onSave: () => s.addCarCost(
      car.id,
      CarCost(label.text.trim(), fmt.parseNumber(amount.text)!, date),
    ),
  );
}

Future<void> showCarForm(BuildContext context, {Car? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  String money(double? v) => v == null || v == 0 ? '' : fmt.number(v);
  TextEditingController text(String? v) => TextEditingController(text: v);
  final make = text(existing?.make);
  final model = text(existing?.model);
  final year = text(existing?.year?.toString());
  final color = text(existing?.color);
  final vin = text(existing?.vin);
  final plate = text(existing?.plate);
  final price = text(money(existing?.purchasePrice));
  final origin = text(existing?.origin);
  final company = text(existing?.shippingCompany);
  final container = text(existing?.container);
  final buyer = text(existing?.buyer);
  final buyerPhone = text(existing?.buyerPhone);
  final salePrice = text(money(existing?.salePrice));
  final note = text(existing?.note);
  var photo = existing?.photo;
  var purchaseDate = existing?.purchaseDate ?? DateTime.now();
  DateTime? shipped = existing?.shippedDate;
  DateTime? arrival = existing?.arrivalDate;
  var saleDate = existing?.saleDate ?? DateTime.now();
  var status = existing?.status ?? CarStatus.purchased;
  final costs = [
    for (final c in existing?.costs ?? const <CarCost>[])
      (label: text(c.label), amount: text(money(c.amount)), date: c.date),
  ];
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
  Widget section(String t) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.brand,
      ),
    ),
  );
  Widget optionalDate(
    String label,
    DateTime? value,
    void Function(DateTime?) set,
  ) => value == null
      ? Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => set(DateTime.now()),
            icon: const Icon(Icons.event_outlined),
            label: Text('إضافة $label'),
          ),
        )
      : Row(
          children: [
            Expanded(
              child: DateField(label: label, value: value, onChanged: set),
            ),
            IconButton(
              tooltip: 'إزالة التاريخ',
              icon: const Icon(Icons.close),
              onPressed: () => set(null),
            ),
          ],
        );

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'سيارة جديدة' : 'تعديل السيارة',
    fields: (setState) => [
      section('معلومات السيارة'),
      Row(
        children: [
          CarPhoto(
            photo: photo,
            size: 56,
            onTap: () async {
              try {
                final picked = await pickProductImage();
                if (picked != null) setState(() => photo = picked);
              } on FormatException catch (e) {
                if (context.mounted) _snack(context, e.message);
              }
            },
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('اضغط على المربع لإضافة صورة السيارة')),
          if (photo != null)
            IconButton(
              tooltip: 'حذف الصورة',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => photo = null),
            ),
        ],
      ),
      pair(
        TextFormField(
          controller: make,
          decoration: const InputDecoration(
            labelText: 'الماركة',
            hintText: 'تويوتا، هيونداي...',
          ),
          validator: requiredText,
        ),
        TextFormField(
          controller: model,
          decoration: const InputDecoration(labelText: 'الموديل'),
        ),
      ),
      pair(
        TextFormField(
          controller: year,
          decoration: const InputDecoration(labelText: 'سنة الصنع'),
          keyboardType: TextInputType.number,
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            final y = int.tryParse(t);
            return y == null || y < 1950 || y > DateTime.now().year + 1
                ? 'سنة غير صحيحة'
                : null;
          },
        ),
        TextFormField(
          controller: color,
          decoration: const InputDecoration(labelText: 'اللون'),
        ),
      ),
      pair(
        TextFormField(
          controller: vin,
          decoration: const InputDecoration(labelText: 'رقم الشاسيه (VIN)'),
          textDirection: TextDirection.ltr,
        ),
        TextFormField(
          controller: plate,
          decoration: const InputDecoration(labelText: 'رقم اللوحة'),
          textDirection: TextDirection.ltr,
        ),
      ),
      section('الشراء والشحن'),
      pair(
        TextFormField(
          controller: price,
          decoration: const InputDecoration(labelText: 'سعر الشراء'),
          keyboardType: decimal,
          validator: numberValidator(),
        ),
        DateField(
          label: 'تاريخ الشراء',
          value: purchaseDate,
          onChanged: (d) => setState(() => purchaseDate = d),
        ),
      ),
      pair(
        TextFormField(
          controller: origin,
          decoration: const InputDecoration(
            labelText: 'شُحنت من',
            hintText: 'أنتويرب، دبي...',
          ),
        ),
        TextFormField(
          controller: container,
          decoration: const InputDecoration(
            labelText: 'رقم الحاوية / البوليصة',
          ),
          textDirection: TextDirection.ltr,
        ),
      ),
      TextFormField(
        controller: company,
        decoration: const InputDecoration(labelText: 'شركة الشحن'),
      ),
      if (companies.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in companies)
              ActionChip(
                label: Text(c),
                onPressed: () => setState(() => company.text = c),
              ),
          ],
        ),
      optionalDate('تاريخ الشحن', shipped, (d) => setState(() => shipped = d)),
      optionalDate('تاريخ الوصول', arrival, (d) => setState(() => arrival = d)),
      DropdownButtonFormField<CarStatus>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'المرحلة'),
        items: [
          for (final st in CarStatus.values)
            DropdownMenuItem(value: st, child: Text(st.label)),
        ],
        onChanged: (v) => setState(() => status = v!),
      ),
      section('المصاريف منذ الشراء'),
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
                  hintText: 'الشحن، الجمارك، تصليح...',
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
              tooltip: 'حذف المصروف',
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
              label: text(''),
              amount: text(''),
              date: DateTime.now(),
            )),
          ),
          icon: const Icon(Icons.add),
          label: const Text('إضافة مصروف'),
        ),
      ),
      if (status == CarStatus.sold) ...[
        section('البيع'),
        pair(
          TextFormField(
            controller: buyer,
            decoration: const InputDecoration(labelText: 'المشتري'),
          ),
          TextFormField(
            controller: buyerPhone,
            decoration: const InputDecoration(labelText: 'هاتف المشتري'),
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
        ),
        pair(
          TextFormField(
            controller: salePrice,
            decoration: const InputDecoration(labelText: 'سعر البيع'),
            keyboardType: decimal,
            validator: numberValidator(min: 0.01),
          ),
          DateField(
            label: 'تاريخ البيع',
            value: saleDate,
            onChanged: (d) => setState(() => saleDate = d),
          ),
        ),
      ],
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () async {
      final sold = status == CarStatus.sold;
      try {
        await s.saveCar(
          Car(
            id: existing?.id ?? newId(),
            make: make.text.trim(),
            model: model.text.trim(),
            year: int.tryParse(year.text.trim()),
            color: color.text.trim(),
            vin: vin.text.trim(),
            plate: plate.text.trim(),
            photo: photo,
            purchaseDate: purchaseDate,
            purchasePrice: fmt.parseNumber(price.text) ?? 0,
            origin: origin.text.trim(),
            shippingCompany: company.text.trim(),
            container: container.text.trim(),
            shippedDate: shipped,
            arrivalDate: arrival,
            costs: [
              for (final c in costs)
                CarCost(
                  c.label.text.trim(),
                  fmt.parseNumber(c.amount.text) ?? 0,
                  c.date,
                ),
            ],
            status: status,
            buyer: sold ? buyer.text.trim() : '',
            buyerPhone: sold ? buyerPhone.text.trim() : '',
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

Future<void> openCarCard(BuildContext context, Car car) {
  final s = context.read<AppState>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: s,
        child: CarCardPage(carId: car.id),
      ),
    ),
  );
}

/// بطاقة السيارة: معلوماتها وشحنها وكل مصاريفها منذ الشراء، مع الطباعة.
class CarCardPage extends StatelessWidget {
  final String carId;
  const CarCardPage({super.key, required this.carId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final car = s.carById(carId);
    if (car == null) {
      return const Scaffold(body: Center(child: Text('حُذفت السيارة')));
    }
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;

    Widget info(String label, String value, {bool ltr = false}) => SizedBox(
      width: 230,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Text(
              value.isEmpty ? '-' : value,
              textDirection: ltr && value.isNotEmpty ? TextDirection.ltr : null,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final costs = [...car.costs]..sort((a, b) => a.date.compareTo(b.date));
    Widget costRow(
      String date,
      String label,
      double amount, {
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(date)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
            ),
          ),
          Text(
            fmt.money(amount),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('بطاقة ${car.title}'),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCarForm(context, existing: car),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('طباعة / PDF'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _CarPdfPage(car: car, company: s.company),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: car.isSold
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showCarCostForm(context, car),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('إضافة مصروف'),
            ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16, bottom: 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 20,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CarPhoto(
                    car: car,
                    size: 110,
                    onTap: () async {
                      try {
                        final picked = await pickProductImage();
                        if (picked != null) {
                          await s.saveCar(car.copyWith(photo: picked));
                        }
                      } on FormatException catch (e) {
                        if (context.mounted) _snack(context, e.message);
                      }
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.title,
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CarStatusChip(car: car, now: now),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'معلومات السيارة',
            icon: Icons.directions_car_outlined,
            child: Wrap(
              spacing: 16,
              children: [
                info('الماركة', car.make),
                info('الموديل', car.model),
                info('سنة الصنع', car.year?.toString() ?? ''),
                info('اللون', car.color),
                info('رقم الشاسيه', car.vin, ltr: true),
                info('رقم اللوحة', car.plate, ltr: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'الشحن',
            icon: Icons.directions_boat_outlined,
            child: Wrap(
              spacing: 16,
              children: [
                info('شُحنت من', car.origin),
                info('شركة الشحن', car.shippingCompany),
                info('الحاوية / البوليصة', car.container, ltr: true),
                info(
                  'تاريخ الشحن',
                  car.shippedDate == null ? '' : fmt.date(car.shippedDate!),
                ),
                info(
                  'الوصول',
                  car.arrivalDate == null ? '' : _arrival(car, now),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'المصاريف منذ الشراء',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                costRow(
                  fmt.date(car.purchaseDate),
                  'سعر شراء السيارة',
                  car.purchasePrice,
                ),
                for (final c in costs) ...[
                  const Divider(height: 1),
                  costRow(fmt.date(c.date), c.label, c.amount),
                ],
                const Divider(thickness: 2),
                costRow('', 'إجمالي التكلفة', car.totalCost, bold: true),
                if (car.isSold) ...[
                  costRow(
                    car.saleDate == null ? '' : fmt.date(car.saleDate!),
                    'سعر البيع${car.buyer.isEmpty ? '' : ' (${car.buyer})'}',
                    car.salePrice,
                    bold: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            car.profit! >= 0 ? 'الربح' : 'الخسارة',
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          fmt.money(car.profit!.abs()),
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: car.profit! >= 0
                                ? AppColors.income.last
                                : AppColors.expense.last,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (car.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'ملاحظات',
              icon: Icons.notes,
              child: Text(car.note),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarPdfPage extends StatelessWidget {
  final Car car;
  final CompanyInfo company;
  const _CarPdfPage({required this.car, required this.company});

  String get fileName => 'بطاقة-${car.title}.pdf';

  Future<Uint8List> _build() => buildCarCardPdf(car: car, company: company);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('بطاقة ${car.title}'),
      actions: [
        IconButton(
          tooltip: 'طباعة',
          icon: const Icon(Icons.print_outlined),
          onPressed: () =>
              Printing.layoutPdf(name: fileName, onLayout: (_) => _build()),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('تنزيل PDF'),
            onPressed: () async => sharePdfFile(await _build(), fileName),
          ),
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) => _build(),
      pdfFileName: fileName,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      onError: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'تعذّر عرض المعاينة في هذا المتصفح.\n'
            'استخدم زر «تنزيل PDF» أو «طباعة» في الأعلى.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
