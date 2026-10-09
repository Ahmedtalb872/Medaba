import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final thisMonth = Period.month(DateTime.now());
    final report = s.profitReport(thisMonth);
    final last = s.profitReport(
      Period.month(DateTime(thisMonth.start.year, thisMonth.start.month - 1)),
    );
    final recent = s.transactions.take(5).toList();
    final lowStock = s.lowStockProducts;
    final now = DateTime.now();
    // شحنات تحتاج متابعة: متأخرة، أو تصل خلال أسبوع.
    final shipments = s.activeShipments
        .where((x) => x.isDelayed(now) || x.daysToArrival(now) <= 7)
        .toList();

    final chart = SectionCard(
      title: 'الإيرادات والمصروفات (آخر 6 أشهر)',
      icon: Icons.bar_chart,
      child: IncomeExpenseChart(data: s.monthlySeries()),
    );

    final distribution = SectionCard(
      title: 'توزيع أرباح هذا الشهر',
      icon: Icons.pie_chart_outline,
      child: report.partners.isEmpty
          ? const EmptyState(message: 'أضف شركاء لعرض التوزيع')
          : Column(
              children: [
                for (final e in report.partners)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(e.name)),
                            Text(
                              fmt.money(e.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (e.percent / 100).clamp(0, 1),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'مرحباً بك في لوحة التحكم',
          icon: Icons.space_dashboard_outlined,
          subtitle: 'ملخص أعمال شهر ${fmt.month(DateTime.now())}',
          actionLabel: 'معاملة جديدة',
          onAction: () => showTransactionForm(context),
        ),
        StatGrid(
          children: [
            StatCard(
              label: 'إيرادات الشهر',
              value: fmt.money(report.income),
              icon: Icons.trending_up,
              colors: AppColors.income,
              current: report.income,
              previous: last.income,
            ),
            StatCard(
              label: 'مصروفات الشهر',
              value: fmt.money(report.expenses),
              icon: Icons.trending_down,
              colors: AppColors.expense,
              current: report.expenses,
              previous: last.expenses,
              upIsGood: false,
            ),
            StatCard(
              label: 'صافي ربح الشهر',
              value: fmt.money(report.netProfit),
              icon: Icons.account_balance_wallet_outlined,
              colors: report.netProfit >= 0 ? AppColors.profit : AppColors.loss,
              current: report.netProfit,
              previous: last.netProfit,
            ),
            StatCard(
              label: 'الرصيد النقدي',
              value: fmt.money(s.cashBalance),
              icon: Icons.savings_outlined,
              colors: AppColors.cash,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth > 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: chart),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: distribution),
                  ],
                )
              : Column(
                  children: [chart, const SizedBox(height: 12), distribution],
                ),
        ),
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AlertCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.expense.last,
            title: 'أصناف قاربت على النفاد: ${lowStock.length}',
            body: lowStock
                .map((p) => '${p.name} (${fmt.number(s.stockOf(p.id))})')
                .join('، '),
          ),
        ],
        if (shipments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AlertCard(
            icon: Icons.directions_boat_outlined,
            color: AppColors.capital.last,
            title:
                'شحنات بحرية تحتاج متابعة: ${shipments.length}'
                '${s.delayedShipments(now) == 0 ? '' : ' (متأخرة: ${s.delayedShipments(now)})'}',
            body: shipments
                .map((x) => '${x.contents} - ${x.status.label}')
                .join('، '),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'آخر المعاملات',
          icon: Icons.receipt_long_outlined,
          child: recent.isEmpty
              ? const EmptyState(message: 'لا توجد معاملات بعد')
              : Column(
                  children: [
                    for (final t in recent)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _TxIcon(income: t.type == TxType.income),
                        title: Text(t.note.isEmpty ? t.category.label : t.note),
                        subtitle: Text(
                          '${t.category.label} • ${fmt.date(t.date)}',
                        ),
                        trailing: Text(
                          '${t.type == TxType.income ? '+' : '-'}${fmt.money(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: t.type == TxType.income
                                ? AppColors.income.last
                                : AppColors.expense.last,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// تنبيه بخلفية ملونة خفيفة وشريط جانبي بلون التنبيه.
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _AlertCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark
            ? Color.alphaBlend(
                color.withValues(alpha: 0.14),
                Theme.of(context).colorScheme.surfaceContainer,
              )
            : Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: BorderDirectional(start: BorderSide(color: color, width: 5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxIcon extends StatelessWidget {
  final bool income;
  const _TxIcon({required this.income});

  @override
  Widget build(BuildContext context) {
    final color = income ? AppColors.income.last : AppColors.expense.last;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        income ? Icons.south_west : Icons.north_east,
        color: color,
        size: 20,
      ),
    );
  }
}
