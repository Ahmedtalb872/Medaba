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
    final recent = s.transactions.take(6).toList();

    final chart = SectionCard(
      title: 'الإيرادات والمصروفات (آخر 6 أشهر)',
      child: IncomeExpenseChart(data: s.monthlySeries()),
    );

    final distribution = SectionCard(
      title: 'توزيع أرباح هذا الشهر',
      child: report.partners.isEmpty && report.investors.isEmpty
          ? const EmptyState(message: 'أضف شركاء أو مستثمرين لعرض التوزيع')
          : Column(
              children: [
                for (final (i, e) in [
                  ...report.investors,
                  ...report.partners,
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 5,
                              backgroundColor: AppColors.seriesAt(i),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.name)),
                            Text(
                              fmt.money(e.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.seriesAt(i),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (e.percent / 100).clamp(0, 1),
                          minHeight: 8,
                          color: AppColors.seriesAt(i),
                          backgroundColor: AppColors.seriesAt(i)
                              .withValues(alpha: 0.15),
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
        _HeroBanner(
          netProfit: report.netProfit,
          onAdd: () => showTransactionForm(context),
        ),
        const SizedBox(height: 16),
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
            StatCard(
              label: 'إجمالي رأس المال',
              value: fmt.money(s.totalCapital),
              icon: Icons.business_center_outlined,
              colors: AppColors.capital,
            ),
            StatCard(
              label: 'الشركاء / المستثمرون',
              value: '${s.partners.length} / ${s.investors.length}',
              icon: Icons.groups_outlined,
              colors: AppColors.people,
            ),
            StatCard(
              label: 'العمال النشطون',
              value: '${s.workers.where((w) => w.active).length}',
              icon: Icons.engineering_outlined,
              colors: AppColors.workers,
            ),
            StatCard(
              label: 'الرواتب الشهرية',
              value: fmt.money(s.monthlyPayroll),
              icon: Icons.payments_outlined,
              colors: AppColors.payroll,
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
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.gradient(
                              t.type == TxType.income
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          child: Icon(
                            t.type == TxType.income
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: Colors.white,
                          ),
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

/// شريط ترحيبي متدرج الألوان أعلى لوحة التحكم.
class _HeroBanner extends StatelessWidget {
  final double netProfit;
  final VoidCallback onAdd;
  const _HeroBanner({required this.netProfit, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.gradient(AppColors.sidebar.reversed.toList()),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'لوحة التحكم',
                style: t.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ملخص أعمال شهر ${fmt.month(DateTime.now())} • '
                'صافي الربح ${fmt.money(netProfit)}',
                style: t.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.seed,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('معاملة جديدة'),
          ),
        ],
      ),
    );
  }
}
