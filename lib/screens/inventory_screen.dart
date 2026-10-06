import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

/// إدارة المخازن: الأرصدة، الحركات، الأصناف، والمخازن.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: PageHeader(
              title: 'المخازن',
              subtitle: 'أرصدة الأصناف وحركات الوارد والصادر والتحويل',
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.inventory_outlined), text: 'المخزون'),
              Tab(icon: Icon(Icons.swap_vert), text: 'الحركات'),
              Tab(icon: Icon(Icons.category_outlined), text: 'الأصناف'),
              Tab(icon: Icon(Icons.warehouse_outlined), text: 'المخازن'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _StockTab(),
                _MovesTab(),
                _ProductsTab(),
                _WarehousesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// صف أزرار الإجراءات أعلى كل تبويب.
class _Actions extends StatelessWidget {
  final List<Widget> children;
  const _Actions({required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}

// ---------------- تبويب المخزون ----------------

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  String? _warehouseId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.warehouseById(_warehouseId) == null) _warehouseId = null;
    final rows = [
      for (final p in s.products)
        (product: p, qty: s.stockOf(p.id, warehouseId: _warehouseId)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Actions(
          children: [
            FilledButton.icon(
              onPressed: () => showMoveForm(context),
              icon: const Icon(Icons.add),
              label: const Text('حركة جديدة'),
            ),
          ],
        ),
        StatGrid(
          children: [
            StatCard(
              label: 'عدد الأصناف',
              value: '${s.products.length}',
              icon: Icons.category_outlined,
              colors: AppColors.capital,
            ),
            StatCard(
              label: 'قيمة المخزون (بسعر التكلفة)',
              value: fmt.money(s.stockValue(warehouseId: _warehouseId)),
              icon: Icons.warehouse_outlined,
              colors: AppColors.stock,
            ),
            StatCard(
              label: 'أصناف تحت الحد الأدنى',
              value: '${s.lowStockProducts.length}',
              icon: Icons.warning_amber_rounded,
              colors: s.lowStockProducts.isEmpty
                  ? AppColors.ok
                  : AppColors.loss,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('كل المخازن'),
              selected: _warehouseId == null,
              onSelected: (_) => setState(() => _warehouseId = null),
            ),
            for (final w in s.warehouses)
              ChoiceChip(
                label: Text(w.name),
                selected: _warehouseId == w.id,
                onSelected: (_) => setState(() => _warehouseId = w.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DataTableCard<({Product product, double qty})>(
          columns: const [
            'الصنف',
            'الكود',
            'الكمية',
            'الوحدة',
            'سعر التكلفة',
            'سعر البيع',
            'القيمة',
            'الحالة',
          ],
          items: rows,
          emptyMessage: 'أضف أصنافاً من تبويب "الأصناف"',
          cells: (r) {
            final p = r.product;
            return [
              Text(p.name),
              Text(p.code),
              Text(
                fmt.number(r.qty),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(p.unit),
              Text(fmt.money(p.costPrice)),
              Text(fmt.money(p.salePrice)),
              Text(fmt.money(r.qty * p.costPrice)),
              _StockStatus(qty: s.stockOf(p.id), min: p.minQty),
            ];
          },
        ),
      ],
    );
  }
}

class _StockStatus extends StatelessWidget {
  final double qty;
  final double min;
  const _StockStatus({required this.qty, required this.min});

  @override
  Widget build(BuildContext context) {
    final (label, colors) = qty <= 0
        ? ('نفد', AppColors.loss)
        : min > 0 && qty <= min
        ? ('منخفض', AppColors.workers)
        : ('متوفر', AppColors.income);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.gradient(colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------- تبويب الحركات ----------------

class _MovesTab extends StatelessWidget {
  const _MovesTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Actions(
          children: [
            FilledButton.icon(
              onPressed: () => showMoveForm(context),
              icon: const Icon(Icons.add),
              label: const Text('حركة جديدة'),
            ),
          ],
        ),
        DataTableCard<StockMove>(
          columns: const [
            'التاريخ',
            'النوع',
            'الصنف',
            'المخزن',
            'الكمية',
            'سعر الوحدة',
            'الإجمالي',
            'ملاحظات',
          ],
          items: s.moves,
          emptyMessage: 'لا توجد حركات مخزون بعد',
          cells: (m) {
            final product = s.productById(m.productId);
            final from = s.warehouseById(m.warehouseId)?.name ?? '-';
            final to = s.warehouseById(m.toWarehouseId)?.name;
            return [
              Text(fmt.date(m.date)),
              _MoveTypeChip(type: m.type),
              Text(product?.name ?? '-'),
              Text(to == null ? from : '$from ← $to'),
              Text('${fmt.number(m.qty)} ${product?.unit ?? ''}'),
              Text(m.type.hasPrice ? fmt.money(m.unitPrice) : '-'),
              Text(
                m.type.hasPrice ? fmt.money(m.total) : '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(m.note),
            ];
          },
          onEdit: (m) => m.invoiceId != null
              ? _invoiceMoveNotice(context, s, m)
              : showMoveForm(context, existing: m),
          onDelete: (m) async {
            if (m.invoiceId != null) {
              return _invoiceMoveNotice(context, s, m);
            }
            if (!await confirmDelete(context, 'حركة ${m.type.label}')) return;
            await s.deleteMove(m.id);
          },
        ),
      ],
    );
  }
}

class _MoveTypeChip extends StatelessWidget {
  final MoveType type;
  const _MoveTypeChip({required this.type});

  static List<Color> colorsOf(MoveType t) => switch (t) {
    MoveType.purchase || MoveType.stockIn => AppColors.income,
    MoveType.sale => AppColors.capital,
    MoveType.stockOut => AppColors.expense,
    MoveType.transfer => AppColors.people,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: colorsOf(type).last.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      type.label,
      style: TextStyle(color: colorsOf(type).last, fontWeight: FontWeight.bold),
    ),
  );
}

/// حركات الفواتير تُعدَّل من شاشة الفواتير حتى تبقى الفاتورة مطابقة للمخزون.
void _invoiceMoveNotice(BuildContext context, AppState s, StockMove m) =>
    _snack(
      context,
      'هذه الحركة جزء من ${s.invoiceById(m.invoiceId)?.number ?? 'فاتورة'}؛ '
      'عدّلها أو احذفها من شاشة الفواتير',
    );

Future<void> showMoveForm(BuildContext context, {StockMove? existing}) async {
  final s = context.read<AppState>();
  if (s.products.isEmpty || s.warehouses.isEmpty) {
    _snack(context, 'أضف مخزناً واحداً وصنفاً واحداً على الأقل أولاً');
    return;
  }
  final key = GlobalKey<FormState>();
  var type = existing?.type ?? MoveType.purchase;
  var productId = existing?.productId ?? s.products.first.id;
  var warehouseId = existing?.warehouseId ?? s.warehouses.first.id;
  String? toWarehouseId = existing?.toWarehouseId;
  var date = existing?.date ?? DateTime.now();
  final qty = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.qty),
  );
  final price = TextEditingController(
    text: existing == null ? '' : fmt.number(existing.unitPrice),
  );
  final note = TextEditingController(text: existing?.note);

  void fillPrice() {
    final p = s.productById(productId);
    if (p == null) return;
    price.text = fmt.number(type == MoveType.sale ? p.salePrice : p.costPrice);
  }

  if (existing == null) fillPrice();

  double available() => s.stockOf(
    productId,
    warehouseId: warehouseId,
    excludeMoveId: existing?.id,
  );

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'حركة مخزون جديدة' : 'تعديل حركة المخزون',
    fields: (setState) => [
      DropdownButtonFormField<MoveType>(
        initialValue: type,
        decoration: const InputDecoration(labelText: 'نوع الحركة'),
        items: [
          for (final t in MoveType.values)
            DropdownMenuItem(value: t, child: Text(t.label)),
        ],
        onChanged: (t) => setState(() {
          type = t!;
          fillPrice();
        }),
      ),
      DropdownButtonFormField<String>(
        initialValue: productId,
        decoration: const InputDecoration(labelText: 'الصنف'),
        items: [
          for (final p in s.products)
            DropdownMenuItem(value: p.id, child: Text(p.name)),
        ],
        onChanged: (v) => setState(() {
          productId = v!;
          fillPrice();
        }),
      ),
      DropdownButtonFormField<String>(
        initialValue: warehouseId,
        decoration: InputDecoration(
          labelText: type == MoveType.transfer ? 'من مخزن' : 'المخزن',
          helperText: type.decreasesSource
              ? 'المتاح: ${fmt.number(available())} '
                    '${s.productById(productId)?.unit ?? ''}'
              : null,
        ),
        items: [
          for (final w in s.warehouses)
            DropdownMenuItem(value: w.id, child: Text(w.name)),
        ],
        onChanged: (v) => setState(() => warehouseId = v!),
      ),
      if (type == MoveType.transfer)
        DropdownButtonFormField<String>(
          initialValue: toWarehouseId,
          decoration: const InputDecoration(labelText: 'إلى مخزن'),
          items: [
            for (final w in s.warehouses)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          validator: (v) => v == null
              ? 'اختر المخزن الهدف'
              : v == warehouseId
              ? 'يجب أن يختلف عن المخزن المصدر'
              : null,
          onChanged: (v) => setState(() => toWarehouseId = v),
        ),
      TextFormField(
        controller: qty,
        decoration: InputDecoration(
          labelText: 'الكمية',
          suffixText: s.productById(productId)?.unit,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          final base = numberValidator(min: 0.001)(v);
          if (base != null) return base;
          if (type.decreasesSource && fmt.parseNumber(v)! > available()) {
            return 'أكبر من المتاح (${fmt.number(available())})';
          }
          return null;
        },
      ),
      if (type.hasPrice)
        TextFormField(
          controller: price,
          decoration: InputDecoration(
            labelText: type == MoveType.sale
                ? 'سعر البيع للوحدة'
                : 'سعر الشراء للوحدة',
            helperText:
                'تُسجَّل تلقائياً كمعاملة '
                '${type == MoveType.sale ? 'إيراد' : 'مصروف'} في الحسابات',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(),
        ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
      ),
    ],
    onSave: () => s.saveMove(
      StockMove(
        id: existing?.id ?? newId(),
        type: type,
        productId: productId,
        warehouseId: warehouseId,
        toWarehouseId: type == MoveType.transfer ? toWarehouseId : null,
        qty: fmt.parseNumber(qty.text)!,
        unitPrice: type.hasPrice ? fmt.parseNumber(price.text)! : 0,
        date: date,
        note: note.text.trim(),
        txId: existing?.txId,
      ),
    ),
  );
}

// ---------------- تبويب الأصناف ----------------

class _ProductsTab extends StatelessWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Actions(
          children: [
            FilledButton.icon(
              onPressed: () => showProductForm(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
          ],
        ),
        DataTableCard<Product>(
          columns: const [
            'الصنف',
            'الكود',
            'الوحدة',
            'سعر التكلفة',
            'سعر البيع',
            'هامش الربح',
            'الحد الأدنى',
          ],
          items: s.products,
          emptyMessage: 'لم تتم إضافة أصناف بعد',
          cells: (p) => [
            Text(p.name),
            Text(p.code),
            Text(p.unit),
            Text(fmt.money(p.costPrice)),
            Text(fmt.money(p.salePrice)),
            Text(
              p.costPrice == 0
                  ? '-'
                  : fmt.percent(
                      (p.salePrice - p.costPrice) / p.costPrice * 100,
                    ),
            ),
            Text(fmt.number(p.minQty)),
          ],
          onEdit: (p) => showProductForm(context, existing: p),
          onDelete: (p) async {
            if (!await confirmDelete(context, p.name)) return;
            if (!await s.deleteProduct(p.id) && context.mounted) {
              _snack(context, 'لا يمكن حذف صنف عليه حركات مخزون');
            }
          },
        ),
      ],
    );
  }
}

Future<void> showProductForm(BuildContext context, {Product? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final code = TextEditingController(text: existing?.code);
  final unit = TextEditingController(text: existing?.unit ?? 'قطعة');
  String num(double? v) => v == null ? '' : fmt.number(v);
  final cost = TextEditingController(text: num(existing?.costPrice));
  final sale = TextEditingController(text: num(existing?.salePrice));
  final min = TextEditingController(text: num(existing?.minQty));
  const decimal = TextInputType.numberWithOptions(decimal: true);

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة صنف' : 'تعديل الصنف',
    fields: (_) => [
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'اسم الصنف'),
        validator: requiredText,
      ),
      TextFormField(
        controller: code,
        decoration: const InputDecoration(labelText: 'الكود / الباركود'),
      ),
      TextFormField(
        controller: unit,
        decoration: const InputDecoration(
          labelText: 'الوحدة',
          hintText: 'قطعة، كرتون، كيلو...',
        ),
        validator: requiredText,
      ),
      TextFormField(
        controller: cost,
        decoration: const InputDecoration(labelText: 'سعر التكلفة'),
        keyboardType: decimal,
        validator: numberValidator(),
      ),
      TextFormField(
        controller: sale,
        decoration: const InputDecoration(labelText: 'سعر البيع'),
        keyboardType: decimal,
        validator: numberValidator(),
      ),
      TextFormField(
        controller: min,
        decoration: const InputDecoration(
          labelText: 'الحد الأدنى للتنبيه',
          helperText: 'يظهر تنبيه عندما يصل الرصيد لهذه الكمية',
        ),
        keyboardType: decimal,
        validator: numberValidator(required: false),
      ),
    ],
    onSave: () => s.saveProduct(
      Product(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        code: code.text.trim(),
        unit: unit.text.trim(),
        costPrice: fmt.parseNumber(cost.text)!,
        salePrice: fmt.parseNumber(sale.text)!,
        minQty: fmt.parseNumber(min.text) ?? 0,
      ),
    ),
  );
}

// ---------------- تبويب المخازن ----------------

class _WarehousesTab extends StatelessWidget {
  const _WarehousesTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Actions(
          children: [
            FilledButton.icon(
              onPressed: () => showWarehouseForm(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مخزن'),
            ),
          ],
        ),
        DataTableCard<Warehouse>(
          columns: const [
            'المخزن',
            'الموقع',
            'أصناف متوفرة',
            'قيمة المخزون',
            'ملاحظات',
          ],
          items: s.warehouses,
          emptyMessage: 'لم تتم إضافة مخازن بعد',
          cells: (w) => [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(w.location),
            Text(
              '${s.products.where((p) => s.stockOf(p.id, warehouseId: w.id) > 0).length}',
            ),
            Text(fmt.money(s.stockValue(warehouseId: w.id))),
            Text(w.notes),
          ],
          onEdit: (w) => showWarehouseForm(context, existing: w),
          onDelete: (w) async {
            if (!await confirmDelete(context, w.name)) return;
            if (!await s.deleteWarehouse(w.id) && context.mounted) {
              _snack(context, 'لا يمكن حذف مخزن عليه حركات مخزون');
            }
          },
        ),
      ],
    );
  }
}

Future<void> showWarehouseForm(BuildContext context, {Warehouse? existing}) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name);
  final location = TextEditingController(text: existing?.location);
  final notes = TextEditingController(text: existing?.notes);

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null ? 'إضافة مخزن' : 'تعديل المخزن',
    fields: (_) => [
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'اسم المخزن'),
        validator: requiredText,
      ),
      TextFormField(
        controller: location,
        decoration: const InputDecoration(labelText: 'الموقع / العنوان'),
      ),
      TextFormField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
        maxLines: 2,
      ),
    ],
    onSave: () => s.saveWarehouse(
      Warehouse(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        location: location.text.trim(),
        notes: notes.text.trim(),
      ),
    ),
  );
}
