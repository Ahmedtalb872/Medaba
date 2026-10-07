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
    final recent = s.transactions.take(5).toList();
    final lowStock = s.lowStockProducts;

    final chart = SectionCard(
      title: 'الإيرادات والمصروفات (آخر 6 أشهر)',
      child: IncomeExpenseChart(data: s.monthlySeries()),
    );

    final distribution = SectionCard(
      title: 'توزيع أرباح هذا الشهر',
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
          title: 'لوحة التحكم',
          subtitle: 'ملخص شهر ${fmt.month(DateTime.now())}',
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
            ),
            StatCard(
              label: 'مصروفات الشهر',
              value: fmt.money(report.expenses),
              icon: Icons.trending_down,
              colors: AppColors.expense,
            ),
            StatCard(
              label: 'صافي ربح الشهر',
              value: fmt.money(report.netProfit),
              icon: Icons.account_balance_wallet_outlined,
              colors: report.netProfit >= 0 ? AppColors.profit : AppColors.loss,
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
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.expense.last,
              ),
              title: Text('أصناف قاربت على النفاد: ${lowStock.length}'),
              subtitle: Text(
                lowStock
                    .map((p) => '${p.name} (${fmt.number(s.stockOf(p.id))})')
                    .join('، '),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'آخر المعاملات',
          child: recent.isEmpty
              ? const EmptyState(message: 'لا توجد معاملات بعد')
              : Column(
                  children: [
                    for (final t in recent)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          t.type == TxType.income
                              ? Icons.south_west
                              : Icons.north_east,
                          color: t.type == TxType.income
                              ? AppColors.income.last
                              : AppColors.expense.last,
                        ),
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
