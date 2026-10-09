import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/data_table_card.dart';

enum _Range { month, year, all }

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({super.key});

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final period = switch (_range) {
      _Range.month => Period.month(now),
      _Range.year => Period.year(now.year),
      _Range.all => null,
    };
    final r = s.profitReport(period);
    final cs = Theme.of(context).colorScheme;

    Widget table(String title, List<ProfitShare> rows, String percentLabel) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DataTableCard<ProfitShare>(
              columns: [
                'الاسم',
                percentLabel,
                'الحصة من الربح',
                'المسحوب',
                'الرصيد المتبقي',
              ],
              items: rows,
              cells: (e) => [
                Text(e.name),
                Text(fmt.percent(e.percent)),
                Text(fmt.money(e.amount)),
                Text(fmt.money(e.withdrawn)),
                Text(
                  fmt.money(e.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: e.balance < 0 ? cs.error : null,
                  ),
                ),
              ],
            ),
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'توزيع الأرباح',
          icon: Icons.pie_chart_outline,
          subtitle: 'يُوزَّع صافي الربح على الشركاء حسب نسبة كل شريك',
        ),
        SegmentedButton<_Range>(
          segments: const [
            ButtonSegment(value: _Range.month, label: Text('هذا الشهر')),
            ButtonSegment(value: _Range.year, label: Text('هذه السنة')),
            ButtonSegment(value: _Range.all, label: Text('كل الفترات')),
          ],
          selected: {_range},
          onSelectionChanged: (v) => setState(() => _range = v.first),
        ),
        const SizedBox(height: 16),
        StatGrid(
          children: [
            StatCard(
              label: 'الإيرادات',
              value: fmt.money(r.income),
              icon: Icons.trending_up,
              colors: AppColors.income,
            ),
            StatCard(
              label: 'المصروفات التشغيلية',
              value: fmt.money(r.expenses),
              icon: Icons.trending_down,
              colors: AppColors.expense,
            ),
            StatCard(
              label: 'صافي الربح',
              value: fmt.money(r.netProfit),
              icon: Icons.account_balance,
              colors: r.netProfit >= 0 ? AppColors.profit : AppColors.loss,
            ),
            StatCard(
              label: 'مسحوبات الشركاء',
              value: fmt.money(
                r.partners.fold<double>(0, (s, e) => s + e.withdrawn),
              ),
              icon: Icons.outbox_outlined,
              colors: AppColors.people,
            ),
          ],
        ),
        if (r.netProfit < 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: cs.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text(
                  'الفترة المحددة فيها خسارة يتحملها الشركاء حسب نسبهم.',
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        table('حصص الشركاء', r.partners, 'نسبة الشراكة'),
      ],
    );
  }
}
