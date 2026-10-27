import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../models/open_order.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import 'invoices_screen.dart';

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// قسم الفواتير المفتوحة في صفحة الفواتير.
class OpenOrdersSection extends StatelessWidget {
  const OpenOrdersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final orders = s.openOrders;
    final active = orders.where((o) => !s.isOrderComplete(o)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفواتير المفتوحة',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'زبون يشتري كمية ويتركها في المخزن، ويأخذ منها على '
                      'دفعات • $active جارية',
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => showOpenOrderForm(context),
                  icon: const Icon(Icons.inventory_outlined),
                  label: const Text('فاتورة مفتوحة جديدة'),
                ),
              ],
            ),
            if (orders.isNotEmpty) const Divider(height: 24),
            for (final o in orders) _OrderTile(order: o),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OpenOrder order;
  const _OrderTile({required this.order});

  void _open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => OpenOrderPage(orderId: order.id)),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = order;
    final done = s.isOrderComplete(o);
    final taken = o.lines.fold<double>(
      0,
      (a, l) => a + l.qty - s.remainingInOrder(o, l.productId, at: o.whOf(l)),
    );
    final progress = o.totalQty == 0 ? 0.0 : taken / o.totalQty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${o.number} • ${o.partyName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (done)
                    Chip(
                      label: const Text('مكتملة'),
                      backgroundColor: AppColors.ok.first.withValues(
                        alpha: 0.15,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Text(
                'أخذ ${fmt.number(taken)} من ${fmt.number(o.totalQty)} • '
                'الباقي ${fmt.number(o.totalQty - taken)} • '
                'المدفوع ${fmt.money(s.orderPaid(o))} من ${fmt.money(o.total)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _open(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح الفاتورة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showOpenOrderForm(context, existing: o),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                  if (!done)
                    OutlinedButton.icon(
                      onPressed: () => showPickupForm(context, o),
                      icon: const Icon(Icons.outbox_outlined),
                      label: const Text('أخذ دفعة'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تفاصيل الفاتورة المفتوحة: الأصناف (المأخوذ والباقي) والدفعات.
class OpenOrderPage extends StatelessWidget {
  final String orderId;
  const OpenOrderPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.orderById(orderId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('حُذفت الفاتورة المفتوحة')),
      );
    }
    final pickups = s.pickupsOf(o.id);
    final done = s.isOrderComplete(o);
    final paid = s.orderPaid(o);
    final credit = s.orderCredit(o.id);
    final payments = s.orderPayments(o);
    final taken = o.lines.fold<double>(
      0,
      (a, l) => a + l.qty - s.remainingInOrder(o, l.productId, at: o.whOf(l)),
    );
    String name(String id) => s.productById(id)?.name ?? 'صنف محذوف';
    // الوحدة تُكتب إذا كانت كل الأصناف بنفس الوحدة.
    final units = {for (final l in o.lines) s.productById(l.productId)?.unit};
    String qty(double v) => units.length == 1 && units.first != null
        ? '${fmt.number(v)} ${units.first}'
        : fmt.number(v);
    // المدفوع بعد كل دفعة، والمتبقي من كل صنف بعد كل أخذ.
    final paidUntil = <double>[];
    for (final p in payments) {
      paidUntil.add((paidUntil.lastOrNull ?? 0) + p.amount);
    }
    // المفتاح: الصنف والمخزن، لأن الصنف نفسه قد يُحجز من مخزنين.
    final leftAfter = <Map<String, double>>[];
    final left = {
      for (final l in o.lines)
        '${l.productId}|${o.whOf(l)}': o.qtyOf(l.productId, at: o.whOf(l)),
    };
    for (final i in pickups) {
      for (final l in i.lines) {
        final k = '${l.productId}|${i.warehouseId}';
        left[k] = (left[k] ?? 0) - l.qty;
      }
      leftAfter.add({...left});
    }
    final multi = o.warehouseIds.length > 1;
    String whName(String id) => s.warehouseById(id)?.name ?? '-';
    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة مفتوحة ${o.number}'),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showOpenOrderForm(context, existing: o),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirmDelete(context, o.number)) return;
              if (await s.deleteOpenOrder(o.id)) {
                if (context.mounted) Navigator.pop(context);
              } else if (context.mounted) {
                _snack(
                  context,
                  'أخذ الزبون منها أو دفع مقدماً؛ احذف فواتير الدفعات '
                  'والمبالغ المدفوعة أولاً',
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: done
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPickupForm(context, o),
              icon: const Icon(Icons.outbox_outlined),
              label: const Text('أخذ دفعة'),
            ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16, bottom: 96),
        children: [
          StatGrid(
            children: [
              StatCard(
                label: 'المبلغ الكلي',
                value: fmt.money(o.total),
                icon: Icons.receipt_long_outlined,
                colors: AppColors.capital,
              ),
              StatCard(
                label: 'المدفوع',
                value: fmt.money(paid),
                icon: Icons.payments_outlined,
                colors: AppColors.income,
              ),
              StatCard(
                label: 'الباقي من المبلغ',
                value: fmt.money(o.total - paid),
                icon: Icons.hourglass_bottom,
                colors: AppColors.loss,
              ),
              StatCard(
                label: 'الكمية الكلية',
                value: qty(o.totalQty),
                icon: Icons.inventory_2_outlined,
                colors: AppColors.capital,
              ),
              StatCard(
                label: 'المأخوذ',
                value: qty(taken),
                icon: Icons.outbox_outlined,
                colors: AppColors.stock,
              ),
              StatCard(
                label: 'المتبقي في المخزن',
                value: qty(o.totalQty - taken),
                icon: Icons.warehouse_outlined,
                colors: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: o.partyName,
            icon: Icons.person_outline,
            child: Text(
              [
                if (o.partyPhone.isNotEmpty) o.partyPhone,
                '${multi ? 'المخازن' : 'المخزن'}: '
                    '${o.warehouseIds.map(whName).join('، ')}',
                'التاريخ: ${fmt.date(o.date)}',
                'قيمة ما أخذه: ${fmt.money(s.orderTakenValue(o))}',
                if (o.notes.isNotEmpty) o.notes,
              ].join(' • '),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'الأصناف',
            icon: Icons.inventory_2_outlined,
            child: Column(
              children: [
                for (final l in o.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      multi
                          ? '${name(l.productId)} • ${whName(o.whOf(l))}'
                          : name(l.productId),
                    ),
                    subtitle: Text(
                      'الأصلية ${fmt.number(l.qty)} • السعر ${fmt.money(l.unitPrice)} '
                      '• أخذ ${fmt.number(l.qty - s.remainingInOrder(o, l.productId, at: o.whOf(l)))}',
                    ),
                    trailing: Text(
                      'المتبقي ${fmt.number(s.remainingInOrder(o, l.productId, at: o.whOf(l)))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'سجل الدفع',
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (o.total - paid > 1e-9)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: () => showOrderPaymentForm(context, o),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('تسجيل دفعة مالية'),
                    ),
                  ),
                payments.isEmpty
                    ? const Text('لم يدفع الزبون شيئاً بعد')
                    : Column(
                        children: [
                          if (credit > 1e-9)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'رصيد مدفوع مقدماً لم يأخذ به بضاعة بعد: '
                                '${fmt.money(credit)} • يُخصم تلقائياً عند الأخذ',
                                style: TextStyle(
                                  color: AppColors.income.last,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          for (final (n, p) in payments.indexed)
                            _HistoryTile(
                              index: n + 1,
                              title: '${fmt.date(p.date)} • ${p.source}',
                              lines: [
                                'المدفوع حتى الآن ${fmt.money(paidUntil[n])}',
                                'الباقي ${fmt.money(o.total - paidUntil[n])}',
                              ],
                              amount: fmt.money(p.amount),
                              color: AppColors.income.last,
                              onDelete: p.advanceId == null
                                  ? null
                                  : () async {
                                      if (!await confirmDelete(
                                        context,
                                        'دفعة ${fmt.money(p.amount)}',
                                      )) {
                                        return;
                                      }
                                      try {
                                        await s.deleteOrderAdvance(
                                          o.id,
                                          p.advanceId!,
                                        );
                                      } on StateError catch (e) {
                                        if (context.mounted) {
                                          _snack(context, e.message);
                                        }
                                      }
                                    },
                            ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'سجل الأخذ من الكمية',
            icon: Icons.history,
            child: pickups.isEmpty
                ? const Text('لم يأخذ الزبون شيئاً بعد')
                : Column(
                    children: [
                      for (final (n, i) in pickups.indexed)
                        _HistoryTile(
                          index: n + 1,
                          title:
                              '${fmt.date(i.date)} • ${i.number}'
                              '${multi ? ' • ${whName(i.warehouseId)}' : ''}',
                          lines: [
                            for (final l in i.lines)
                              '${name(l.productId)}: أخذ ${fmt.number(l.qty)} '
                                  'من ${fmt.number(o.qtyOf(l.productId, at: i.warehouseId))} '
                                  '← بقي ${fmt.number(leftAfter[n]['${l.productId}|${i.warehouseId}'] ?? 0)}',
                            if ((s.debtForInvoice(i.id)?.remaining ?? 0) > 0)
                              'باقي عليه ${fmt.money(s.debtForInvoice(i.id)!.remaining)}',
                          ],
                          amount: fmt.money(i.total),
                          color: AppColors.stock.last,
                          onTap: () => openInvoicePdf(context, i),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// سطر مرقّم في سجل الدفع أو سجل الأخذ.
class _HistoryTile extends StatelessWidget {
  final int index;
  final String title;
  final List<String> lines;
  final String amount;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _HistoryTile({
    required this.index,
    required this.title,
    required this.lines,
    required this.amount,
    required this.color,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '$index',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final l in lines)
                  Text(
                    l,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LineDraft {
  String productId;

  /// المخزن الذي يُحجز منه هذا الصنف.
  String warehouseId;
  final TextEditingController qty;
  final TextEditingController price;
  _LineDraft(
    this.productId,
    this.warehouseId, {
    String qty = '',
    String price = '',
  }) : qty = TextEditingController(text: qty),
       price = TextEditingController(text: price);
}

/// إنشاء فاتورة مفتوحة أو تعديلها: الزبون، المخزن، والأصناف بكمياتها وسعرها.
Future<void> showOpenOrderForm(BuildContext context, {OpenOrder? existing}) {
  final s = context.read<AppState>();
  if (s.warehouses.isEmpty || s.products.isEmpty) {
    _snack(context, 'أضف مخزناً وصنفاً أولاً');
    return Future.value();
  }
  final key = GlobalKey<FormState>();
  final party = TextEditingController(text: existing?.partyName);
  final phone = TextEditingController(text: existing?.partyPhone);
  final notes = TextEditingController(text: existing?.notes);
  var date = existing?.date ?? DateTime.now();
  final number = existing?.number ?? s.nextOrderNumber();
  final lines = [
    for (final l in existing?.lines ?? const <InvoiceLine>[])
      _LineDraft(
        l.productId,
        existing!.whOf(l),
        qty: fmt.number(l.qty),
        price: fmt.number(l.unitPrice),
      ),
  ];
  void addLine() {
    final p = s.products.first;
    // السطر الجديد من نفس مخزن السطر السابق.
    final w = lines.lastOrNull?.warehouseId ?? s.warehouses.first.id;
    lines.add(_LineDraft(p.id, w, price: fmt.number(p.salePrice)));
  }

  if (lines.isEmpty) addLine();

  // ما يمكن حجزه من صنف في مخزن. لا يُعرض رقم سالب إذا قلّ المخزون عن المحجوز.
  double free(String productId, String w) =>
      (s.stockOf(productId, warehouseId: w) -
              s.reservedQty(
                productId,
                warehouseId: w,
                excludeOrderId: existing?.id,
              ) +
              (existing == null
                  ? 0
                  : s.takenFromOrder(existing.id, productId, at: w)))
          .clamp(0.0, double.infinity);

  return showFormDialog(
    context: context,
    formKey: key,
    title: existing == null
        ? 'فاتورة مفتوحة جديدة $number'
        : 'تعديل الفاتورة المفتوحة $number',
    fields: (setState) => [
      TextFormField(
        controller: party,
        decoration: const InputDecoration(labelText: 'الزبون'),
        validator: requiredText,
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'هاتف الزبون'),
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
      ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text(
        'لكل صنف مخزنه. لأخذ نفس الصنف من مخزنين أضفه مرتين بمخزنين مختلفين.',
        style: TextStyle(fontSize: 12),
      ),
      for (final (i, l) in lines.indexed)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('p$i${l.productId}'),
                    initialValue: l.productId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الصنف'),
                    items: [
                      for (final p in s.products)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      l.productId = v!;
                      final p = s.productById(v);
                      if (p != null) l.price.text = fmt.number(p.salePrice);
                    }),
                  ),
                ),
                if (lines.length > 1)
                  IconButton(
                    tooltip: 'إزالة',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => lines.removeAt(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('w$i${l.warehouseId}'),
              initialValue: l.warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'من مخزن'),
              items: [
                for (final w in s.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => l.warehouseId = v!),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: l.qty,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      helperText:
                          'المتوفر: ${fmt.number(free(l.productId, l.warehouseId))}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final base = numberValidator(min: 0.001)(v);
                      if (base != null) return base;
                      // مجموع الصنف من نفس المخزن لا يتجاوز المتوفر فيه.
                      final want = lines
                          .where(
                            (x) =>
                                x.productId == l.productId &&
                                x.warehouseId == l.warehouseId,
                          )
                          .fold<double>(
                            0,
                            (a, x) => a + (fmt.parseNumber(x.qty.text) ?? 0),
                          );
                      final have = free(l.productId, l.warehouseId);
                      return want > have + 1e-9
                          ? 'المتوفر ${fmt.number(have)} فقط'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: l.price,
                    decoration: const InputDecoration(labelText: 'سعر الوحدة'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: numberValidator(min: 0.01),
                  ),
                ),
              ],
            ),
          ],
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(addLine),
          icon: const Icon(Icons.add),
          label: const Text('إضافة صنف'),
        ),
      ),
      TextFormField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
      ),
    ],
    onSave: () async {
      // نفس الصنف من نفس المخزن يُجمع في سطر واحد.
      final merged = <String, InvoiceLine>{};
      for (final l in lines) {
        final qty = fmt.parseNumber(l.qty.text) ?? 0;
        final price = fmt.parseNumber(l.price.text) ?? 0;
        final key = '${l.productId}|${l.warehouseId}';
        final prev = merged[key];
        merged[key] = InvoiceLine(
          productId: l.productId,
          qty: qty + (prev?.qty ?? 0),
          unitPrice: price,
          warehouseId: l.warehouseId,
        );
      }
      // الرفض (مثل كمية أكبر من المتوفر) يظهر داخل النموذج ويبقى مفتوحاً.
      await s.saveOpenOrder(
        OpenOrder(
          id: existing?.id ?? newId(),
          number: number,
          date: date,
          partyName: party.text.trim(),
          partyPhone: phone.text.trim(),
          warehouseId: lines.first.warehouseId,
          lines: merged.values.toList(),
          notes: notes.text.trim(),
        ),
      );
      if (context.mounted) {
        _snack(
          context,
          existing == null
              ? 'تم إنشاء الفاتورة المفتوحة $number'
              : 'تم حفظ الفاتورة المفتوحة $number',
        );
      }
    },
  );
}

/// الزبون يأخذ دفعة: كم أخذ من كل صنف وكم دفع. تُنشأ فاتورة بيع بها.
Future<void> showPickupForm(BuildContext context, OpenOrder o) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  String keyOf(InvoiceLine l) => '${l.productId}|${o.whOf(l)}';
  final qty = {for (final l in o.lines) keyOf(l): TextEditingController()};
  final paid = TextEditingController();
  final notes = TextEditingController();
  var paidTouched = false;
  var date = DateTime.now();
  final credit = s.orderCredit(o.id);

  // كل دفعة من مخزن واحد؛ يبدأ بأول مخزن بقي فيه شيء للزبون.
  final whs = o.warehouseIds;
  var wh = whs.firstWhere(
    (w) => o.lines.any(
      (l) => o.whOf(l) == w && s.remainingInOrder(o, l.productId, at: w) > 1e-9,
    ),
    orElse: () => whs.first,
  );
  List<InvoiceLine> here() => [
    for (final l in o.lines)
      if (o.whOf(l) == wh) l,
  ];

  double value() => here().fold(
    0,
    (a, l) => a + (fmt.parseNumber(qty[keyOf(l)]!.text) ?? 0) * l.unitPrice,
  );

  /// ما يُخصم من المدفوع مقدماً، وما بقي ليُدفع الآن.
  double fromCredit() => credit.clamp(0.0, value());
  double due() => value() - fromCredit();

  return showFormDialog(
    context: context,
    formKey: key,
    title: 'أخذ دفعة من ${o.number} • ${o.partyName}',
    fields: (setState) => [
      if (whs.length > 1)
        DropdownButtonFormField<String>(
          initialValue: wh,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'يأخذ من مخزن'),
          items: [
            for (final w in whs)
              DropdownMenuItem(
                value: w,
                child: Text(s.warehouseById(w)?.name ?? '-'),
              ),
          ],
          onChanged: (v) => setState(() {
            wh = v!;
            if (!paidTouched) paid.text = fmt.number(due());
          }),
        )
      else
        Text('من ${s.warehouseById(wh)?.name ?? '-'}'),
      for (final l in here())
        TextFormField(
          key: ValueKey(keyOf(l)),
          controller: qty[keyOf(l)],
          onChanged: (_) => setState(() {
            if (!paidTouched) paid.text = fmt.number(due());
          }),
          decoration: InputDecoration(
            labelText:
                'الكمية المأخوذة: ${s.productById(l.productId)?.name ?? ''}',
            helperText:
                'الباقي له هنا ${fmt.number(s.remainingInOrder(o, l.productId, at: wh))} '
                '• السعر ${fmt.money(l.unitPrice)}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final n = fmt.parseNumber(v ?? '');
            if (n == null || n == 0) return null;
            if (n < 0) return 'كمية غير صحيحة';
            if (n > s.remainingInOrder(o, l.productId, at: wh) + 1e-9) {
              return 'أكثر من الباقي له';
            }
            return null;
          },
        ),
      Text(
        'قيمة هذه الدفعة: ${fmt.money(value())}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      if (credit > 1e-9)
        Text(
          'يُخصم من المدفوع مقدماً: ${fmt.money(fromCredit())} '
          '(الرصيد ${fmt.money(credit)}) • الباقي للدفع ${fmt.money(due())}',
          style: TextStyle(color: AppColors.income.last),
        ),
      TextFormField(
        controller: paid,
        onChanged: (_) => setState(() => paidTouched = true),
        decoration: InputDecoration(
          labelText: 'المبلغ المدفوع',
          helperText: () {
            final rest = due() - (fmt.parseNumber(paid.text) ?? 0);
            return rest > 0.0001
                ? 'الباقي ${fmt.money(rest)} يُسجَّل ديناً على الزبون'
                : 'مدفوعة كاملة';
          }(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(required: false),
      ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: notes,
        decoration: const InputDecoration(labelText: 'ملاحظات'),
      ),
    ],
    onSave: () async {
      try {
        final inv = await s.pickupFromOrder(
          o.id,
          quantities: {
            for (final l in here())
              l.productId: fmt.parseNumber(qty[keyOf(l)]!.text) ?? 0,
          },
          paid: fmt.parseNumber(paid.text) ?? 0,
          date: date,
          notes: notes.text,
          warehouseId: wh,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('سُجّلت الدفعة في فاتورة البيع ${inv.number}'),
              action: SnackBarAction(
                label: 'عرض الفاتورة',
                onPressed: () => openInvoicePdf(context, inv),
              ),
            ),
          );
        }
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}

/// يسجّل مبلغاً دفعه الزبون في الفاتورة المفتوحة دون أن يأخذ بضاعة.
Future<void> showOrderPaymentForm(BuildContext context, OpenOrder o) {
  final s = context.read<AppState>();
  final key = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();
  var date = DateTime.now();
  final left = o.total - s.orderPaid(o);
  return showFormDialog(
    context: context,
    formKey: key,
    title: 'دفعة مالية من ${o.partyName} • ${o.number}',
    fields: (setState) => [
      Text('الباقي من مبلغ الفاتورة: ${fmt.money(left)}'),
      TextFormField(
        controller: amount,
        decoration: InputDecoration(
          labelText: 'المبلغ المدفوع',
          suffixIcon: TextButton(
            onPressed: () => amount.text = fmt.number(left),
            child: const Text('الكل'),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(min: 0.01, max: left),
      ),
      DateField(
        label: 'التاريخ',
        value: date,
        onChanged: (d) => setState(() => date = d),
      ),
      TextFormField(
        controller: note,
        decoration: const InputDecoration(
          labelText: 'ملاحظة (نقداً، تحويل Bankily...)',
        ),
      ),
      const Text('يُخصم هذا المبلغ تلقائياً من قيمة ما يأخذه الزبون لاحقاً.'),
    ],
    onSave: () async {
      try {
        await s.addOrderAdvance(
          o.id,
          amount: fmt.parseNumber(amount.text) ?? 0,
          date: date,
          note: note.text,
        );
      } on StateError catch (e) {
        if (context.mounted) _snack(context, e.message);
      }
    },
  );
}
