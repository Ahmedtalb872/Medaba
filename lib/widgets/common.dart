import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import 'brand.dart';

/// رأس الصفحة: لافتة ترحيب بشعار المؤسسة وعنوان الصفحة ورسم زخرفي،
/// وتحتها أزرار الإجراءات.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dashboard_outlined,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
    this.secondaryLabel,
    this.secondaryIcon = Icons.add,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final company = context.select<AppState, String>((s) => s.company.name);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final showLogo = c.maxWidth >= 1050;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: (wide ? t.headlineSmall : t.titleLarge)?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              company,
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: dark ? cs.primary : AppColors.brand,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        );
        final lead = showLogo
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 20),
                child: Container(
                  padding: const EdgeInsetsDirectional.only(end: 20),
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      end: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                  child: const BrandLogo(size: 44),
                ),
              )
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: dark ? AppColors.brand : const Color(0xFFF6E3B5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: dark ? Colors.white : AppColors.brand,
                  ),
                ),
              );
        final banner = Container(
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: wide ? 150 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: dark
                  ? [cs.surfaceContainerHigh, cs.surfaceContainer]
                  : const [Color(0xFFFFFCF5), Color(0xFFF7EEDC)],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
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
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        lead,
                        Expanded(child: text),
                      ],
                    ),
                  ),
                ),
                if (wide) BannerArt(width: math.min(440, c.maxWidth * 0.4)),
              ],
            ),
          ),
        );
        final actions = [
          if (onAction != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: Size(wide ? 280 : 0, 54),
                textStyle: const TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel ?? 'إضافة'),
            ),
          if (onSecondary != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: dark ? null : Colors.white,
                foregroundColor: dark ? cs.primary : AppColors.brand,
                side: BorderSide(
                  color: (dark ? cs.primary : AppColors.brand).withValues(
                    alpha: 0.5,
                  ),
                ),
                minimumSize: Size(wide ? 280 : 0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'ReadexPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onSecondary,
              icon: Icon(secondaryIcon),
              label: Text(secondaryLabel ?? ''),
            ),
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              banner,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// بطاقة مؤشر رقمي (KPI) بخلفية ملونة خفيفة، مع مقارنة اختيارية.
///
/// [current] و[previous] يضيفان سطر «مقارنة بالشهر الماضي» بنسبة التغير.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final double? current;
  final double? previous;

  /// وحدة صغيرة بجانب الرقم (مثل «صنف»).
  final String? unit;

  /// هل الارتفاع خبر جيد؟ (للمصروفات: لا، فيُلوَّن الارتفاع بالأحمر).
  final bool upIsGood;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.colors = AppColors.profit,
    this.current,
    this.previous,
    this.unit,
    this.upIsGood = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = dark ? colors.first : colors.last;
    final tint = dark
        ? Color.alphaBlend(tone.withValues(alpha: 0.12), cs.surfaceContainer)
        : Color.alphaBlend(tone.withValues(alpha: 0.08), Colors.white);
    final hasTrend = current != null && previous != null;
    final change = !hasTrend || previous == 0
        ? null
        : ((current! - previous!) / previous!.abs() * 100).round();
    final up = (change ?? 0) >= 0;
    final trendColor = change == null
        ? cs.onSurfaceVariant
        : up == upIsGood
        ? AppColors.income.last
        : AppColors.expense.last;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: tone, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 6),
                        Text(unit!, style: TextStyle(color: tone)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MiniBars(color: tone),
            ],
          ),
          if (hasTrend) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'مقارنة بالشهر الماضي',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  change == null ? '—' : '${change.abs()}%',
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (change != null)
                  Icon(
                    up ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: trendColor,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// أعمدة صغيرة متصاعدة تزيّن بطاقات المؤشرات.
class _MiniBars extends StatelessWidget {
  final Color color;
  const _MiniBars({required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final (i, f) in const [0.35, 0.55, 0.8, 1.0].indexed)
        Container(
          width: 10,
          height: 40 * f,
          margin: const EdgeInsetsDirectional.only(start: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18 + i * 0.22),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
    ],
  );
}

/// شبكة متجاوبة لبطاقات المؤشرات.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 950
            ? 4
            : c.maxWidth > 700
            ? 3
            : c.maxWidth > 320
            ? 2
            : 1;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: c),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: c)),
          ],
        ),
      ),
    );
  }
}

/// مخطط أعمدة بسيط للإيرادات مقابل المصروفات بدون مكتبات خارجية.
class IncomeExpenseChart extends StatelessWidget {
  final List<({DateTime month, double income, double expenses})> data;
  const IncomeExpenseChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<double>(
      1,
      (m, e) => math.max(m, math.max(e.income, e.expenses)),
    );
    const h = 180.0;
    Widget bar(double v, List<Color> c) => Tooltip(
      message: fmt.money(v),
      child: Container(
        width: 16,
        height: math.max(2, h * v / maxV),
        decoration: BoxDecoration(
          color: c.last,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Legend(color: AppColors.income.last, label: 'الإيرادات'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.expense.last, label: 'المصروفات'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: h + 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // كل شهر يأخذ حصة متساوية من العرض حتى لا يتجاوز المخطط الشاشات الضيقة.
              for (final e in data)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          bar(e.income, AppColors.income),
                          const SizedBox(width: 4),
                          bar(e.expenses, AppColors.expense),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmt.month(e.month),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

/// بطاقة بعنوان (وأيقونة اختيارية) تحيط بمحتوى.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.brand : const Color(0xFFE7F1EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: dark ? Colors.white : AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text('هل تريد حذف "$name"؟ لا يمكن التراجع عن هذه العملية.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(c).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ---------------- حقول النماذج ----------------

String? requiredText(String? v) =>
    (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

String? Function(String?) numberValidator({
  double min = 0,
  double? max,
  bool required = true,
}) => (v) {
  if (v == null || v.trim().isEmpty) {
    return required ? 'هذا الحقل مطلوب' : null;
  }
  final n = fmt.parseNumber(v);
  if (n == null) return 'أدخل رقماً صحيحاً';
  if (n < min) return 'يجب ألا يقل عن ${fmt.number(min)}';
  if (max != null && n > max) return 'يجب ألا يزيد عن ${fmt.number(max)}';
  return null;
};

class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (d != null) onChanged(d);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
      ),
      child: Text(fmt.date(value)),
    ),
  );
}

/// حوار نموذج عام: عنوان + حقول + زر حفظ يتحقق من صحة الإدخال.
Future<void> showFormDialog({
  required BuildContext context,
  required String title,
  required List<Widget> Function(StateSetter setState) fields,
  required GlobalKey<FormState> formKey,
  required Future<void> Function() onSave,
}) {
  return showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in fields(setState))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: f,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await onSave();
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
