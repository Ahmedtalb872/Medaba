import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/invoice.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';

/// الفترة المعروضة في صفحتي الأرباح والديون.
enum DayRange {
  today('اليوم'),
  week('آخر 7 أيام'),
  month('هذا الشهر'),
  all('الكل');

  final String label;
  const DayRange(this.label);

  Period? get period {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DayRange.today => Period(today, today),
      DayRange.week => Period(today.subtract(const Duration(days: 6)), today),
      DayRange.month => Period.month(now),
      DayRange.all => null,
    };
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// يجمع العناصر يوماً بيوم، الأحدث أولاً (العناصر مرتبة مسبقاً).
List<(DateTime, List<T>)> _byDay<T>(List<T> items, DateTime Function(T) date) {
  final out = <(DateTime, List<T>)>[];
  for (final x in items) {
    final d = _day(date(x));
    if (out.isEmpty || out.last.$1 != d) out.add((d, []));
    out.last.$2.add(x);
  }
  return out;
}

String _dayTitle(DateTime d) {
  final today = _day(DateTime.now());
  if (d == today) return 'اليوم • ${fmt.date(d)}';
  if (d == today.subtract(const Duration(days: 1))) {
    return 'أمس • ${fmt.date(d)}';
  }
  return fmt.date(d);
}

Widget _rangePicker(DayRange value, ValueChanged<DayRange> onChanged) =>
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<DayRange>(
        showSelectedIcon: false,
        segments: [
          for (final r in DayRange.values)
            ButtonSegment(value: r, label: Text(r.label)),
        ],
        selected: {value},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );

Color _signColor(double v) =>
    v >= 0 ? AppColors.income.last : AppColors.expense.last;

/// الأرباح: كل عملية بيع يوماً بيوم، مع سعر البيع وسعر الشراء والربح.
class ProfitsByDayScreen extends StatefulWidget {
  const ProfitsByDayScreen({super.key});

  @override
  State<ProfitsByDayScreen> createState() => _ProfitsByDayScreenState();
}

class _ProfitsByDayScreenState extends State<ProfitsByDayScreen> {
  DayRange _range = DayRange.month;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entries = s.profitEntries(_range.period);
    final sale = entries.fold<double>(0, (a, e) => a + e.sale);
    final cost = entries.fold<double>(0, (a, e) => a + e.cost);
    final missing = s.productsWithoutCost;

    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح')),
      body: ListView(
        padding: pagePadding.copyWith(top: 16),
        children: [
          _rangePicker(_range, (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          StatGrid(
            children: [
              StatCard(
                label: 'المبيعات',
                value: fmt.money(sale),
                icon: Icons.point_of_sale,
                colors: AppColors.income,
              ),
              StatCard(
                label: 'سعر الشراء',
                value: fmt.money(cost),
                icon: Icons.shopping_cart_outlined,
                colors: AppColors.expense,
              ),
              StatCard(
                label: 'الربح (البيع - الشراء)',
                value: fmt.money(sale - cost),
                icon: Icons.trending_up,
                colors: sale - cost >= 0 ? AppColors.ok : AppColors.loss,
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFF4E0),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB7791F),
                ),
                title: Text(
                  '${missing.length} صنف بدون سعر شراء، فربح بيعها غير دقيق',
                ),
                subtitle: Text(
                  '${missing.take(6).map((p) => p.name).join('، ')}'
                  '${missing.length > 6 ? '...' : ''}\n'
                  'أضف سعر الشراء من المخزون ← الأصناف ← زر التعديل',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا توجد مبيعات في هذه الفترة')),
            ),
          for (final (day, items) in _byDay(entries, (e) => e.date))
            _DayCard(
              title: _dayTitle(day),
              trailing: () {
                final p = items.fold<double>(0, (a, e) => a + e.sale - e.cost);
                return Text(
                  'ربح اليوم ${fmt.money(p)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _signColor(p),
                  ),
                );
              }(),
              children: [
                for (final e in items)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(e.title),
                    subtitle: Text(
                      '${e.kind} • بيع ${fmt.money(e.sale)} • '
                      'شراء ${fmt.money(e.cost)}'
                      '${e.missingCost ? ' • ⚠ سعر شراء ناقص' : ''}',
                    ),
                    trailing: Text(
                      fmt.money(e.sale - e.cost),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _signColor(e.sale - e.cost),
                      ),
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsetsDirectional.only(
                      start: 8,
                      bottom: 8,
                    ),
                    children: [for (final d in e.details) Text('• $d')],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// الديون يوماً بيوم: كل دين جديد وكل دفعة تسديد.
class DebtsByDayScreen extends StatefulWidget {
  /// يفتح صفحة الديون الكاملة (للإضافة والتسديد).
  final VoidCallback? openDebts;
  const DebtsByDayScreen({super.key, this.openDebts});

  @override
  State<DebtsByDayScreen> createState() => _DebtsByDayScreenState();
}

class _DebtsByDayScreenState extends State<DebtsByDayScreen> {
  DayRange _range = DayRange.all;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final events = s.debtEvents(_range.period);
    final open = widget.openDebts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الديون'),
        actions: [
          if (open != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                open();
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('صفحة الديون'),
            ),
        ],
      ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16),
        children: [
          StatGrid(
            children: [
              StatCard(
                label: 'لنا عند الناس',
                value: fmt.money(s.debtsRemaining(DebtDirection.theyOwe)),
                icon: Icons.call_received,
                colors: AppColors.income,
              ),
              StatCard(
                label: 'علينا للناس',
                value: fmt.money(s.debtsRemaining(DebtDirection.weOwe)),
                icon: Icons.call_made,
                colors: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rangePicker(_range, (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا توجد حركات ديون في هذه الفترة')),
            ),
          for (final (day, items) in _byDay(events, (e) => e.date))
            _DayCard(
              title: _dayTitle(day),
              children: [for (final e in items) _DebtEventTile(e)],
            ),
        ],
      ),
    );
  }
}

class _DebtEventTile extends StatelessWidget {
  final DebtEvent e;
  const _DebtEventTile(this.e);

  @override
  Widget build(BuildContext context) {
    final d = e.debt;
    final pay = e.payment;
    final ours = d.direction == DebtDirection.theyOwe;
    final title = pay == null
        ? (ours
              ? 'دين جديد لنا على ${d.personName}'
              : 'دين جديد علينا لـ ${d.personName}')
        : (ours ? 'سدّد ${d.personName}' : 'سدّدنا لـ ${d.personName}');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (pay == null ? AppColors.gold : AppColors.ok.last)
            .withValues(alpha: 0.15),
        child: Icon(
          pay == null ? Icons.receipt_long_outlined : Icons.payments_outlined,
          color: pay == null ? AppColors.gold : AppColors.ok.last,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        [
          if (pay == null && d.note.isNotEmpty) d.note,
          if (pay != null && pay.note.isNotEmpty) pay.note,
          if (d.phone.isNotEmpty) d.phone,
          'المتبقي الآن: ${fmt.money(d.remaining)}',
          if (pay == null && d.dueDate != null)
            'الاستحقاق: ${fmt.date(d.dueDate!)}',
        ].join(' • '),
      ),
      trailing: Text(
        fmt.money(pay?.amount ?? d.amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _DayCard({required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ?trailing,
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );
}

/// تقرير ما دفعه زبون فاتورة مفتوحة: كل دفعة يوماً بيوم، مع المدفوع
/// حتى تلك اللحظة والباقي من المبلغ الكلي.
class OrderPaymentsReport extends StatefulWidget {
  final String orderId;
  const OrderPaymentsReport({super.key, required this.orderId});

  @override
  State<OrderPaymentsReport> createState() => _OrderPaymentsReportState();
}

class _OrderPaymentsReportState extends State<OrderPaymentsReport> {
  DayRange _range = DayRange.all;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.orderById(widget.orderId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('حُذفت الفاتورة المفتوحة')),
      );
    }
    // المدفوع حتى كل دفعة يُحسب من كل الدفعات، ثم تُعرض دفعات الفترة.
    final all = s.orderPayments(o);
    final until = <double>[];
    for (final p in all) {
      until.add((until.lastOrNull ?? 0) + p.amount);
    }
    final period = _range.period;
    final shown = [
      for (final (i, p) in all.indexed)
        if (period == null || period.contains(p.date)) (i: i, p: p),
    ].reversed.toList();
    final inRange = shown.fold<double>(0, (a, e) => a + e.p.amount);
    final paid = s.orderPaid(o);

    return Scaffold(
      appBar: AppBar(title: Text('المدفوع • ${o.number} • ${o.partyName}')),
      body: ListView(
        padding: pagePadding.copyWith(top: 16),
        children: [
          _rangePicker(_range, (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          StatGrid(
            children: [
              StatCard(
                label: _range == DayRange.all
                    ? 'كل المدفوع'
                    : 'المدفوع (${_range.label})',
                value: fmt.money(inRange),
                icon: Icons.payments_outlined,
                colors: AppColors.income,
              ),
              StatCard(
                label: 'عدد الدفعات',
                value: '${shown.length}',
                icon: Icons.receipt_long_outlined,
                colors: AppColors.capital,
              ),
              StatCard(
                label: 'الباقي من المبلغ الكلي',
                value: fmt.money(o.total - paid),
                icon: Icons.hourglass_bottom,
                colors: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا توجد دفعات في هذه الفترة')),
            ),
          for (final (day, items) in _byDay(shown, (e) => e.p.date))
            _DayCard(
              title: _dayTitle(day),
              trailing: Text(
                fmt.money(items.fold<double>(0, (a, e) => a + e.p.amount)),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.income.last,
                ),
              ),
              children: [
                for (final e in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.income.last.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        '${e.i + 1}',
                        style: TextStyle(
                          color: AppColors.income.last,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(e.p.source),
                    subtitle: Text(
                      'المدفوع حتى الآن ${fmt.money(until[e.i])} • '
                      'الباقي ${fmt.money(o.total - until[e.i])}',
                    ),
                    trailing: Text(
                      fmt.money(e.p.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// تقرير ما أخذه زبون فاتورة مفتوحة: كل أخذ يوماً بيوم، بكمياته ومخزنه
/// وما بقي له بعده.
class OrderPickupsReport extends StatefulWidget {
  final String orderId;

  /// يفتح فاتورة البيع لكل أخذ.
  final void Function(BuildContext, Invoice)? openInvoice;
  const OrderPickupsReport({
    super.key,
    required this.orderId,
    this.openInvoice,
  });

  @override
  State<OrderPickupsReport> createState() => _OrderPickupsReportState();
}

class _OrderPickupsReportState extends State<OrderPickupsReport> {
  DayRange _range = DayRange.all;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.orderById(widget.orderId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('حُذفت الفاتورة المفتوحة')),
      );
    }
    String name(String id) => s.productById(id)?.name ?? 'صنف محذوف';
    String unit(String id) => s.productById(id)?.unit ?? '';
    String whName(String id) => s.warehouseById(id)?.name ?? '-';
    final multi = o.warehouseIds.length > 1;
    // الوحدة تُكتب مع المجاميع إذا كانت كل الأصناف بنفس الوحدة.
    final units = {for (final l in o.lines) unit(l.productId)};
    String q(double v) => units.length == 1
        ? '${fmt.number(v)} ${units.first}'.trim()
        : fmt.number(v);

    // الباقي من كل صنف في كل مخزن بعد كل أخذ، من أول الفاتورة.
    final pickups = s.pickupsOf(o.id);
    final left = {
      for (final l in o.lines)
        '${l.productId}|${o.whOf(l)}': o.qtyOf(l.productId, at: o.whOf(l)),
    };
    final leftAfter = <Map<String, double>>[];
    for (final i in pickups) {
      for (final l in i.lines) {
        final k = '${l.productId}|${i.warehouseId}';
        left[k] = (left[k] ?? 0) - l.qty;
      }
      leftAfter.add({...left});
    }
    final period = _range.period;
    final shown = [
      for (final (n, i) in pickups.indexed)
        if (period == null || period.contains(i.date)) (n: n, i: i),
    ].reversed.toList();
    double qtyOf(Invoice i) => i.lines.fold(0, (a, l) => a + l.qty);
    final qty = shown.fold<double>(0, (a, e) => a + qtyOf(e.i));
    final value = shown.fold<double>(0, (a, e) => a + e.i.total);
    final remaining = o.lines.fold<double>(
      0,
      (a, l) => a + s.remainingInOrder(o, l.productId, at: o.whOf(l)),
    );

    return Scaffold(
      appBar: AppBar(title: Text('المأخوذ • ${o.number} • ${o.partyName}')),
      body: ListView(
        padding: pagePadding.copyWith(top: 16),
        children: [
          _rangePicker(_range, (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          StatGrid(
            children: [
              StatCard(
                label: _range == DayRange.all
                    ? 'كل المأخوذ'
                    : 'المأخوذ (${_range.label})',
                value: q(qty),
                icon: Icons.outbox_outlined,
                colors: AppColors.stock,
              ),
              StatCard(
                label: 'قيمته',
                value: fmt.money(value),
                icon: Icons.receipt_long_outlined,
                colors: AppColors.capital,
              ),
              StatCard(
                label: 'المتبقي في المخزن',
                value: q(remaining),
                icon: Icons.warehouse_outlined,
                colors: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لم يأخذ الزبون شيئاً في هذه الفترة')),
            ),
          for (final (day, items) in _byDay(shown, (e) => e.i.date))
            _DayCard(
              title: _dayTitle(day),
              trailing: Text(
                'أخذ ${q(items.fold<double>(0, (a, e) => a + qtyOf(e.i)))}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.stock.last,
                ),
              ),
              children: [
                for (final e in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: widget.openInvoice == null
                        ? null
                        : () => widget.openInvoice!(context, e.i),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.stock.last.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        '${e.n + 1}',
                        style: TextStyle(
                          color: AppColors.stock.last,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${e.i.number}${multi ? ' • ${whName(e.i.warehouseId)}' : ''}',
                    ),
                    subtitle: Text(
                      [
                        for (final l in e.i.lines)
                          '${name(l.productId)}: أخذ ${fmt.number(l.qty)} '
                              '${unit(l.productId)} من '
                              '${fmt.number(o.qtyOf(l.productId, at: e.i.warehouseId))} '
                              '← بقي ${fmt.number(leftAfter[e.n]['${l.productId}|${e.i.warehouseId}'] ?? 0)}',
                        if ((s.debtForInvoice(e.i.id)?.remaining ?? 0) > 0)
                          'باقي عليه ${fmt.money(s.debtForInvoice(e.i.id)!.remaining)}',
                      ].join('\n'),
                    ),
                    trailing: Text(
                      fmt.money(e.i.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
