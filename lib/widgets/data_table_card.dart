import 'package:flutter/material.dart';

import 'common.dart';

/// جدول بيانات داخل بطاقة مع أزرار تعديل وحذف لكل صف.
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(child: EmptyState(message: emptyMessage));
    }
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
              columnSpacing: 28,
              columns: [
                for (final col in columns) DataColumn(label: Text(col)),
                if (hasActions) const DataColumn(label: Text('إجراءات')),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    cells: [
                      for (final cell in cells(item)) DataCell(cell),
                      if (hasActions)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...?extraActions?.call(item),
                              if (onEdit != null)
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => onEdit!(item),
                                ),
                              if (onDelete != null)
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () => onDelete!(item),
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
