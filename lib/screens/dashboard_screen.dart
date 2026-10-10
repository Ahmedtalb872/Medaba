import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/shell_nav.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';

/// الصفحة الرئيسية: ترحيب، اختصارات سريعة، ثلاثة أرقام، وآخر المعاملات.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final month = Period.month(DateTime.now());
    final sales = s.transactions
        .where((t) => t.category == TxCategory.sales && month.contains(t.date))
        .fold<double>(0, (a, t) => a + t.amount);

    return ListView(
      padding: pagePadding,
      children: [
        const _Welcome(),
        const SizedBox(height: 20),
        _Grid(
          children: [
            _QuickAction(
              title: 'إضافة منتج',
              subtitle: 'إدخال منتج جديد',
              icon: Icons.view_in_ar,
              color: const Color(0xFF1E6FD9),
              onTap: () => showProductForm(context),
            ),
            _QuickAction(
              title: 'شراء جديد',
              subtitle: 'إنشاء فاتورة شراء',
              icon: Icons.inventory_2,
              color: const Color(0xFFC07F12),
              onTap: () => openInvoiceEditor(context, InvoiceType.purchase),
            ),
            _QuickAction(
              title: 'بيع جديد',
              subtitle: 'إنشاء فاتورة بيع',
              icon: Icons.add_shopping_cart,
              color: const Color(0xFF15803D),
              onTap: () => openInvoiceEditor(context, InvoiceType.sale),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Grid(
          children: [
            _Total(
              label: 'الرصيد المتوفر',
              value: s.cashBalance,
              hint: 'أوقية',
              icon: Icons.savings,
              color: const Color(0xFFC08A1E),
            ),
            _Total(
              label: 'إجمالي المصروفات',
              value: s.totalExpenses(month),
              hint: 'أوقية • هذا الشهر',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFFC0392B),
            ),
            _Total(
              label: 'إجمالي المبيعات',
              value: sales,
              hint: 'أوقية • هذا الشهر',
              icon: Icons.trending_up,
              color: const Color(0xFF15803D),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RecentTransactions(items: s.transactions.take(6).toList()),
      ],
    );
  }
}

/// ثلاث بطاقات في صف على الشاشات العريضة، وتحت بعضها على الجوال.
class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth > 760 ? 3 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}

/// لافتة الترحيب باسم المستخدم مع رسم الصناديق.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final c = context.select<AppState, CompanyInfo>((s) => s.company);
    final firstName = c.name.trim().split(' ').first;
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        return Container(
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: wide ? 210 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFCF6), Color(0xFFF8EEDB)],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 32 : 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً بك ${c.ownerName}',
                          style: (wide ? t.displaySmall : t.headlineSmall)
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(c.ownerRole, style: t.headlineSmall),
                        Text('في لوحة تحكم $firstName', style: t.titleMedium),
                        const SizedBox(height: 14),
                        Container(
                          width: 56,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (wide) BannerArt(width: box.maxWidth * 0.5),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// اختصار ملون بأيقونة كبيرة وسهم.
class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              _IconTile(icon: icon, color: color, badge: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(Icons.chevron_left, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مربع أيقونة ملون، مع علامة «+» صغيرة عند [badge].
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool badge;
  const _IconTile({
    required this.icon,
    required this.color,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color, size: 44),
        if (badge)
          PositionedDirectional(
            end: 12,
            bottom: 12,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
      ],
    ),
  );
}

/// رقم إجمالي كبير بلون البطاقة.
class _Total extends StatelessWidget {
  final String label;
  final double value;
  final String hint;
  final IconData icon;
  final Color color;
  const _Total({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.05), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    fmt.number(value),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(hint, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          _IconTile(icon: icon, color: color),
        ],
      ),
    );
  }
}

/// جدول آخر المعاملات مع زر «عرض الكل».
class _RecentTransactions extends StatelessWidget {
  final List<Transaction> items;
  const _RecentTransactions({required this.items});

  static (Color, Color) _tone(TxCategory c) => switch (c) {
    TxCategory.sales || TxCategory.otherIncome => (
      const Color(0xFF15803D),
      const Color(0xFFE3F5E9),
    ),
    TxCategory.supplies => (const Color(0xFFB7791F), const Color(0xFFFFF3D6)),
    _ => (const Color(0xFFC0392B), const Color(0xFFFDE8E6)),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final head = TextStyle(color: cs.onSurfaceVariant, fontSize: 15);
    Widget row(List<Widget> cells, {Color? color, bool line = true}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: color == null ? null : BorderRadius.circular(12),
            border: line && color == null
                ? Border(bottom: BorderSide(color: cs.outlineVariant))
                : null,
          ),
          child: Row(
            children: [
              for (final (i, c) in cells.indexed)
                Expanded(
                  flex: i == 1 ? 3 : 2,
                  child: Align(alignment: Alignment.center, child: c),
                ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'آخر المعاملات',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ShellNav.maybeOf(context)?.go(ShellPage.transactions),
                  icon: const Text('عرض الكل'),
                  label: const Icon(Icons.chevron_left),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const EmptyState(message: 'لا توجد معاملات بعد')
            else ...[
              row([
                Text('التاريخ', style: head),
                Text('الوصف', style: head),
                Text('النوع', style: head),
                Text('المبلغ', style: head),
              ], color: const Color(0xFFF1F3F5)),
              for (final (i, t) in items.indexed)
                row(line: i < items.length - 1, [
                  Text(fmt.date(t.date)),
                  Text(
                    t.note.isEmpty ? t.category.label : t.note,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _tone(t.category).$2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t.category.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _tone(t.category).$1),
                    ),
                  ),
                  Text(
                    fmt.money(t.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}
