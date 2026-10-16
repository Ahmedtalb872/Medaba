import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'common.dart';

/// جدول بيانات داخل بطاقة برأس أخضر وصفوف متناوبة وأزرار ملونة لكل صف.
/// يمرَّر أفقياً على الشاشات الضيقة.
class DataTableCard<T> extends StatelessWidget {
  final List<String> columns;
  final List<T> items;
  final List<Widget> Function(T item) cells;
  final void Function(T item)? onEdit;
  final void Function(T item)? onDelete;
  final List<Widget> Function(T item)? extraActions;
  final String emptyMessage;

  const DataTableCard({
    super.key,
    required this.columns,
    required this.items,
    required this.cells,
    this.onEdit,
    this.onDelete,
    this.extraActions,
    this.emptyMessage = 'لا توجد بيانات بعد',
  });

  static const _head = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(child: EmptyState(message: emptyMessage));
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final hasActions =
        onEdit != null || onDelete != null || extraActions != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(AppColors.brand),
              headingRowHeight: 54,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              columnSpacing: 28,
              columns: [
                for (final col in columns)
                  DataColumn(label: Text(col, style: _head)),
                if (hasActions)
                  const DataColumn(label: Text('إجراءات', style: _head)),
              ],
              rows: [
                for (final (n, item) in items.indexed)
                  DataRow(
                    color: WidgetStatePropertyAll(
                      n.isOdd
                          ? (dark
                                ? cs.surfaceContainerHigh
                                : const Color(0xFFF7F8FA))
                          : null,
                    ),
                    cells: [
                      for (final cell in cells(item)) DataCell(cell),
                      if (hasActions)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...?extraActions?.call(item),
                              if (onEdit != null)
                                TableAction(
                                  tooltip: 'تعديل',
                                  icon: Icons.edit_outlined,
                                  color: const Color(0xFF1D4ED8),
                                  onTap: () => onEdit!(item),
                                ),
                              if (onDelete != null)
                                TableAction(
                                  tooltip: 'حذف',
                                  icon: Icons.delete_outline,
                                  color: AppColors.expense.last,
                                  onTap: () => onDelete!(item),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر إجراء صغير بخلفية ملونة خفيفة داخل صفوف الجداول.
class TableAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const TableAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: Material(
      color: color.withValues(alpha: onTap == null ? 0.04 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 36,
            child: Icon(
              icon,
              color: onTap == null ? color.withValues(alpha: 0.35) : color,
              size: 20,
            ),
          ),
        ),
      ),
    ),
  );
}
