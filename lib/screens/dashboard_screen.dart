import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
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
                for (final e in [...report.investors, ...report.partners])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (e.percent / 100).clamp(0, 1),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
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
              color: Colors.green.shade600,
            ),
            StatCard(
              label: 'مصروفات الشهر',
              value: fmt.money(report.expenses),
              icon: Icons.trending_down,
              color: cs.error,
            ),
            StatCard(
              label: 'صافي ربح الشهر',
              value: fmt.money(report.netProfit),
              icon: Icons.account_balance_wallet_outlined,
              color: report.netProfit >= 0 ? cs.primary : cs.error,
            ),
            StatCard(
              label: 'الرصيد النقدي',
              value: fmt.money(s.cashBalance),
              icon: Icons.savings_outlined,
              color: Colors.teal,
            ),
            StatCard(
              label: 'إجمالي رأس المال',
              value: fmt.money(s.totalCapital),
              icon: Icons.business_center_outlined,
              color: Colors.indigo,
            ),
            StatCard(
              label: 'الشركاء / المستثمرون',
              value: '${s.partners.length} / ${s.investors.length}',
              icon: Icons.groups_outlined,
              color: Colors.deepPurple,
            ),
            StatCard(
              label: 'العمال النشطون',
              value: '${s.workers.where((w) => w.active).length}',
              icon: Icons.engineering_outlined,
              color: Colors.orange.shade700,
            ),
            StatCard(
              label: 'الرواتب الشهرية',
              value: fmt.money(s.monthlyPayroll),
              icon: Icons.payments_outlined,
              color: Colors.brown,
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
                        leading: CircleAvatar(
                          backgroundColor: t.type == TxType.income
                              ? Colors.green.shade50
                              : cs.errorContainer,
                          child: Icon(
                            t.type == TxType.income
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: t.type == TxType.income
                                ? Colors.green.shade700
                                : cs.error,
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
                                ? Colors.green.shade700
                                : cs.error,
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
