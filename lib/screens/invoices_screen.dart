import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/inventory.dart';
import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/invoice_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';
import '../widgets/product_thumb.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  InvoiceType? _type;
  DateTimeRange? _range;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      helpText: 'اختر فترة الفواتير',
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final thisMonth = Period.month(now);
    final lastMonth = Period.month(DateTime(now.year, now.month - 1));

    double sum(InvoiceType t, Period p) => s.invoices
        .where((i) => i.type == t && p.contains(i.date))
        .fold(0, (a, i) => a + i.total);
    int count(Period p) => s.invoices.where((i) => p.contains(i.date)).length;

    final q = _search.text.trim().toLowerCase();
    final items = s.invoices.where((i) {
      if (_type != null && i.type != _type) return false;
      if (_range != null &&
          !Period(_range!.start, _range!.end).contains(i.date)) {
        return false;
      }
      if (q.isEmpty) return true;
      final products = i.lines.map((l) => s.productById(l.productId)?.name);
      return [
        i.number,
        i.partyName,
        i.partyPhone,
        ...products.whereType<String>(),
      ].any((x) => x.toLowerCase().contains(q));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InvoicesHeader(
          onSale: () => openInvoiceEditor(context, InvoiceType.sale),
          onPurchase: () => openInvoiceEditor(context, InvoiceType.purchase),
        ),
        const SizedBox(height: 16),
        StatGrid(
          children: [
            _TrendCard(
              label: 'إجمالي المخزون',
              value: fmt.number(s.totalStockQty()),
              unit: 'وحدة',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFB7791F),
              tint: const Color(0xFFFFF8E6),
              current: s.totalStockQty(),
              previous: s.totalStockQty(at: lastMonth.end),
            ),
            _TrendCard(
              label: 'مبيعات الشهر (فواتير)',
              value: fmt.number(sum(InvoiceType.sale, thisMonth)),
              icon: Icons.point_of_sale,
              color: AppColors.income.last,
              tint: const Color(0xFFEAF7F0),
              current: sum(InvoiceType.sale, thisMonth),
              previous: sum(InvoiceType.sale, lastMonth),
            ),
            _TrendCard(
              label: 'مشتريات الشهر (فواتير)',
              value: fmt.number(sum(InvoiceType.purchase, thisMonth)),
              icon: Icons.shopping_cart_outlined,
              color: AppColors.expense.last,
              tint: const Color(0xFFFDEEEE),
              current: sum(InvoiceType.purchase, thisMonth),
              previous: sum(InvoiceType.purchase, lastMonth),
              // ارتفاع المشتريات ليس خبراً جيداً بالضرورة: نلوّنه بالأحمر.
              upIsGood: false,
            ),
            _TrendCard(
              label: 'عدد الفواتير',
              value: '${count(thisMonth)}',
              icon: Icons.description_outlined,
              color: const Color(0xFF5B3E96),
              tint: const Color(0xFFF2EEFB),
              current: count(thisMonth).toDouble(),
              previous: count(lastMonth).toDouble(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث في الفواتير...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SegmentedButton<InvoiceType?>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.brand,
                selectedForegroundColor: Colors.white,
                backgroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment(
                  value: null,
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('الكل'),
                ),
                ButtonSegment(
                  value: InvoiceType.sale,
                  icon: Icon(Icons.shopping_cart_outlined),
                  label: Text('بيع'),
                ),
                ButtonSegment(
                  value: InvoiceType.purchase,
                  icon: Icon(Icons.add_shopping_cart),
                  label: Text('شراء'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _pickRange,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _range == null
                    ? 'اختر التاريخ'
                    : '${fmt.date(_range!.start)} - ${fmt.date(_range!.end)}',
              ),
            ),
            if (_range != null)
              IconButton(
                tooltip: 'كل التواريخ',
                onPressed: () => setState(() => _range = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _InvoiceTable(
          invoices: items,
          warehouseName: (id) => s.warehouseById(id)?.name ?? '-',
          onPdf: (i) => openInvoicePdf(context, i),
          onEdit: (i) => openInvoiceEditor(context, i.type, existing: i),
          onDelete: (i) async {
            if (!await confirmDelete(context, '${i.type.label} ${i.number}')) {
              return;
            }
            try {
              await s.deleteInvoice(i.id);
            } on StateError catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message)));
              }
            }
          },
        ),
      ],
    );
  }
}

/// رأس الصفحة: أيقونة وعنوان ووصف، وزرا الفاتورة الجديدة.
class _InvoicesHeader extends StatelessWidget {
  final VoidCallback onSale;
  final VoidCallback onPurchase;
  const _InvoicesHeader({required this.onSale, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final content = _content(context, t);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFBF6EA), Color(0xFFF1EBDD)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 24),
                const _HeaderArt(),
              ],
            )
          : content,
    );
  }

  Widget _content(BuildContext context, TextTheme t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E3B5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 34,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الفواتير',
                  style: t.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إدارة فواتير البيع والشراء والمخزون بشكل سهل وآمن',
                  style: t.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(240, 54),
            ),
            onPressed: onSale,
            icon: const Icon(Icons.point_of_sale),
            label: const Text('فاتورة بيع جديدة'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand,
              minimumSize: const Size(240, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onPurchase,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('فاتورة شراء جديدة'),
          ),
        ],
      ),
    ],
  );
}

/// رسم زخرفي في رأس الصفحة على الشاشات العريضة: صناديق وحافظة أوراق ونبتة.
class _HeaderArt extends StatelessWidget {
  const _HeaderArt();

  Widget _box(double size, Color color) => Container(
    width: size,
    height: size * 0.8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: size * 0.16,
        height: size * 0.8,
        color: const Color(0x22000000),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 150,
    child: Stack(
      children: [
        PositionedDirectional(
          end: 150,
          bottom: 0,
          child: _box(80, const Color(0xFFD9A066)),
        ),
        PositionedDirectional(
          end: 205,
          bottom: 0,
          child: _box(70, const Color(0xFFC98F55)),
        ),
        PositionedDirectional(
          end: 175,
          bottom: 60,
          child: _box(62, const Color(0xFFE2B07A)),
        ),
        PositionedDirectional(
          end: 230,
          bottom: 52,
          child: _box(50, AppColors.brand),
        ),
        PositionedDirectional(
          end: 70,
          bottom: 0,
          child: Container(
            width: 92,
            height: 124,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 54,
                color: Color(0xFF9DB7A9),
              ),
            ),
          ),
        ),
        const PositionedDirectional(
          end: 10,
          bottom: 0,
          child: Icon(Icons.local_florist, size: 64, color: Color(0xFF4F8A5B)),
        ),
      ],
    ),
  );
}

/// بطاقة رقم بلون خفيف ومقارنة بالشهر الماضي.
class _TrendCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final Color tint;
  final double current;
  final double previous;
  final bool upIsGood;

  const _TrendCard({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
    required this.tint,
    required this.current,
    required this.previous,
    this.upIsGood = true,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final change = previous == 0
        ? null
        : ((current - previous) / previous * 100).round();
    final up = (change ?? 0) >= 0;
    final good = up == upIsGood;
    final trendColor = change == null
        ? muted
        : good
        ? AppColors.income.last
        : AppColors.expense.last;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(unit!, style: TextStyle(color: color)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'مقارنة بالشهر الماضي',
                  style: TextStyle(color: muted, fontSize: 12),
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
      ),
    );
  }
}

/// جدول الفواتير برأس أخضر وأزرار ملونة للإجراءات.
class _InvoiceTable extends StatelessWidget {
  final List<Invoice> invoices;
  final String Function(String) warehouseName;
  final void Function(Invoice) onPdf;
  final void Function(Invoice) onEdit;
  final void Function(Invoice) onDelete;

  const _InvoiceTable({
    required this.invoices,
    required this.warehouseName,
    required this.onPdf,
    required this.onEdit,
    required this.onDelete,
  });

  static const _head = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  Widget _action(
    String tooltip,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 36,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Card(child: EmptyState(message: 'لا توجد فواتير هنا'));
    }
    DataColumn col(String label, IconData icon) => DataColumn(
      label: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: _head),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(AppColors.brand),
              headingRowHeight: 58,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 60,
              columnSpacing: 28,
              columns: [
                const DataColumn(label: Text('#', style: _head)),
                col('التاريخ', Icons.calendar_today_outlined),
                col('العميل / المورد', Icons.person_outline),
                col('المخزن', Icons.warehouse_outlined),
                col('الأصناف', Icons.layers_outlined),
                col('الإجمالي', Icons.payments_outlined),
                col('إجراءات', Icons.settings_outlined),
              ],
              rows: [
                for (final (n, i) in invoices.indexed)
                  DataRow(
                    color: WidgetStatePropertyAll(
                      n.isOdd ? const Color(0xFFF7F8FA) : Colors.white,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          i.number,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: i.type == InvoiceType.sale
                                ? AppColors.income.last
                                : AppColors.expense.last,
                          ),
                        ),
                      ),
                      DataCell(Text(fmt.date(i.date))),
                      DataCell(Text(i.partyName.isEmpty ? '-' : i.partyName)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            warehouseName(i.warehouseId),
                            style: const TextStyle(color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ),
                      DataCell(Text('${i.lines.length}')),
                      DataCell(
                        Text(
                          fmt.money(i.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _action(
                              'عرض وطباعة PDF',
                              Icons.picture_as_pdf_outlined,
                              AppColors.expense.last,
                              () => onPdf(i),
                            ),
                            _action(
                              'تعديل',
                              Icons.edit_outlined,
                              const Color(0xFF1D4ED8),
                              () => onEdit(i),
                            ),
                            _action(
                              'حذف',
                              Icons.delete_outline,
                              AppColors.expense.last,
                              () => onDelete(i),
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

Future<void> openInvoiceEditor(
  BuildContext context,
  InvoiceType type, {
  Invoice? existing,
}) async {
  final s = context.read<AppState>();
  if (s.products.isEmpty || s.warehouses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('أضف مخزناً وصنفاً من شاشة المخازن قبل إنشاء فاتورة'),
      ),
    );
    return;
  }
  final saved = await Navigator.of(context).push<Invoice>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: s,
        child: InvoiceEditorPage(type: type, existing: existing),
      ),
    ),
  );
  if (saved != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ ${saved.type.label} ${saved.number}'),
        action: SnackBarAction(
          label: 'عرض PDF',
          onPressed: () => openInvoicePdf(context, saved),
        ),
      ),
    );
  }
}

Future<void> openInvoicePdf(BuildContext context, Invoice invoice) {
  final s = context.read<AppState>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => InvoicePdfPage(
        invoice: invoice,
        company: s.company,
        productOf: s.productById,
        warehouseName: s.warehouseById(invoice.warehouseId)?.name ?? '-',
        remainingDebt: s.debtForInvoice(invoice.id)?.remaining ?? 0,
      ),
    ),
  );
}

/// معاينة الفاتورة كملف PDF مع أزرار الطباعة والتنزيل/المشاركة.
class InvoicePdfPage extends StatefulWidget {
  final Invoice invoice;
  final CompanyInfo company;
  final Product? Function(String) productOf;
  final String warehouseName;
  final double remainingDebt;

  const InvoicePdfPage({
    super.key,
    required this.invoice,
    required this.company,
    required this.productOf,
    required this.warehouseName,
    this.remainingDebt = 0,
  });

  @override
  State<InvoicePdfPage> createState() => _InvoicePdfPageState();
}

class _InvoicePdfPageState extends State<InvoicePdfPage> {
  /// آخر لغة اختارها المستخدم، تبقى للفاتورة التالية خلال الجلسة.
  static InvoiceLanguage _lastLanguage = InvoiceLanguage.ar;
  InvoiceLanguage _language = _lastLanguage;

  Invoice get invoice => widget.invoice;

  /// اسم الملف يحمل رمز اللغة لغير العربية، مثل S-0001-fr.pdf.
  String get fileName => _language == InvoiceLanguage.ar
      ? '${invoice.number}.pdf'
      : '${invoice.number}-${_language.name}.pdf';

  Future<Uint8List> _build() => buildInvoicePdf(
    invoice: invoice,
    company: widget.company,
    productOf: widget.productOf,
    warehouseName: widget.warehouseName,
    remainingDebt: widget.remainingDebt,
    language: _language,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${invoice.type.label} ${invoice.number}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.translate, size: 20),
                const SizedBox(width: 8),
                const Text('لغة الفاتورة'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<InvoiceLanguage>(
                    showSelectedIcon: false,
                    segments: [
                      for (final l in InvoiceLanguage.values)
                        ButtonSegment(value: l, label: Text(l.label)),
                    ],
                    selected: {_language},
                    onSelectionChanged: (v) =>
                        setState(() => _language = _lastLanguage = v.first),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'طباعة',
            icon: const Icon(Icons.print_outlined),
            onPressed: () =>
                Printing.layoutPdf(name: fileName, onLayout: (_) => _build()),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('تنزيل PDF'),
              onPressed: () async =>
                  Printing.sharePdf(bytes: await _build(), filename: fileName),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        // مفتاح باللغة حتى تُعاد المعاينة عند تغييرها.
        key: ValueKey(_language),
        build: (_) => _build(),
        pdfFileName: fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        onError: (context, error) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'تعذّر عرض المعاينة في هذا المتصفح.\n'
              'استخدم زر «تنزيل PDF» أو «طباعة» في الأعلى.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحة إنشاء وتعديل فاتورة بعدة أصناف.
class InvoiceEditorPage extends StatefulWidget {
  final InvoiceType type;
  final Invoice? existing;
  const InvoiceEditorPage({super.key, required this.type, this.existing});

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _LineDraft {
  String productId;
  final TextEditingController qty;
  final TextEditingController price;
  _LineDraft(this.productId, {String qty = '', String price = ''})
    : qty = TextEditingController(text: qty),
      price = TextEditingController(text: price);

  double get total =>
      (fmt.parseNumber(qty.text) ?? 0) * (fmt.parseNumber(price.text) ?? 0);

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _form = GlobalKey<FormState>();
  late final AppState s = context.read<AppState>();
  late final String _number;
  late String _warehouseId;
  late DateTime _date;
  late final TextEditingController _party;
  late final TextEditingController _phone;
  late final TextEditingController _discount;
  late final TextEditingController _notes;

  /// الدفع بالدين: ما يُدفع الآن، والباقي يُسجَّل ديناً.
  late bool _onDebt;
  late final TextEditingController _paidNow;
  final List<_LineDraft> _lines = [];
  bool _saving = false;

  bool get _isSale => widget.type == InvoiceType.sale;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _number = e?.number ?? s.nextInvoiceNumber(widget.type);
    _warehouseId = e?.warehouseId ?? s.warehouses.first.id;
    _date = e?.date ?? DateTime.now();
    _party = TextEditingController(text: e?.partyName);
    _phone = TextEditingController(text: e?.partyPhone);
    _discount = TextEditingController(
      text: e == null || e.discount == 0 ? '' : fmt.number(e.discount),
    );
    _notes = TextEditingController(text: e?.notes);
    _onDebt = (e?.debt ?? 0) > 0;
    final paid = e == null ? 0.0 : e.total - e.debt;
    _paidNow = TextEditingController(
      text: _onDebt && paid > 0 ? fmt.number(paid) : '',
    );
    if (e != null) {
      for (final l in e.lines) {
        _lines.add(
          _LineDraft(
            l.productId,
            qty: fmt.number(l.qty),
            price: fmt.number(l.unitPrice),
          ),
        );
      }
    } else {
      _addLine();
    }
  }

  @override
  void dispose() {
    for (final c in [_party, _phone, _discount, _notes, _paidNow]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _defaultPrice(String productId) {
    final p = s.productById(productId);
    return p == null ? '' : fmt.number(_isSale ? p.salePrice : p.costPrice);
  }

  void _addLine() {
    final id = s.products.first.id;
    setState(() => _lines.add(_LineDraft(id, price: _defaultPrice(id))));
  }

  Invoice _draft() {
    final inv = _draftWithoutDebt();
    if (!_onDebt) return inv;
    final paid = fmt.parseNumber(_paidNow.text) ?? 0;
    final debt = (inv.total - paid).clamp(0.0, inv.total);
    return Invoice.fromJson({...inv.toJson(), 'debt': debt});
  }

  Invoice _draftWithoutDebt() => Invoice(
    id: widget.existing?.id ?? newId(),
    type: widget.type,
    number: _number,
    date: _date,
    partyName: _party.text.trim(),
    partyPhone: _phone.text.trim(),
    warehouseId: _warehouseId,
    lines: [
      for (final l in _lines)
        InvoiceLine(
          productId: l.productId,
          qty: fmt.parseNumber(l.qty.text) ?? 0,
          unitPrice: fmt.parseNumber(l.price.text) ?? 0,
        ),
    ],
    discount: fmt.parseNumber(_discount.text) ?? 0,
    notes: _notes.text.trim(),
    txId: widget.existing?.txId,
  );

  Future<void> _save() async {
    if (_lines.isEmpty) {
      _snack('أضف صنفاً واحداً على الأقل');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final inv = _draft();
    if (inv.total < 0) {
      _snack('الخصم أكبر من مجموع الفاتورة');
      return;
    }
    setState(() => _saving = true);
    try {
      await s.saveInvoice(inv);
      if (mounted) Navigator.pop(context, s.invoiceById(inv.id));
    } on StateError catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    // إعادة الرسم عند تغيّر البيانات (مثل رفع صورة صنف من هذه الصفحة).
    context.watch<AppState>();
    final inv = _draft();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    final header = SectionCard(
      title: 'بيانات الفاتورة',
      trailing: Chip(label: Text(_number)),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _field(
            TextFormField(
              controller: _party,
              decoration: InputDecoration(labelText: widget.type.partyLabel),
              // الدين يُسجَّل باسم العميل أو المورد.
              validator: (v) => _onDebt && (v ?? '').trim().isEmpty
                  ? 'اكتب الاسم لتسجيل الدين'
                  : null,
            ),
          ),
          _field(
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'الهاتف'),
              keyboardType: TextInputType.phone,
            ),
          ),
          _field(
            DropdownButtonFormField<String>(
              initialValue: _warehouseId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isSale ? 'البيع من مخزن' : 'الاستلام في مخزن',
              ),
              items: [
                for (final w in s.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _warehouseId = v!),
            ),
          ),
          _field(
            DateField(
              label: 'التاريخ',
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
        ],
      ),
    );

    final lines = SectionCard(
      title: 'الأصناف',
      trailing: TextButton.icon(
        onPressed: _addLine,
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'اضغط على صورة الصنف لرفعها أو تغييرها قبل حفظ الفاتورة',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final (i, l) in _lines.indexed) _lineRow(i, l, decimal),
          if (_lines.isEmpty) const EmptyState(message: 'أضف أصناف الفاتورة'),
        ],
      ),
    );

    final totals = SectionCard(
      title: 'الإجمالي',
      child: Column(
        children: [
          TextFormField(
            controller: _discount,
            decoration: const InputDecoration(labelText: 'الخصم (مبلغ)'),
            keyboardType: decimal,
            validator: numberValidator(required: false),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'طريقة الدفع',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.payments_outlined),
                label: Text('مدفوعة كاملة'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: Text('دين'),
              ),
            ],
            selected: {_onDebt},
            onSelectionChanged: (v) => setState(() => _onDebt = v.first),
          ),
          if (_onDebt) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _paidNow,
              decoration: const InputDecoration(
                labelText: 'المدفوع الآن (اتركه فارغاً إن لم يُدفع شيء)',
              ),
              keyboardType: decimal,
              validator: numberValidator(required: false, max: inv.total),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          _totalRow('المجموع', inv.subtotal),
          if (inv.discount > 0) _totalRow('الخصم', -inv.discount),
          const Divider(),
          _totalRow('الإجمالي المستحق', inv.total, strong: true),
          _totalRow('المدفوع', inv.total - inv.debt),
          _totalRow(
            'الدين',
            inv.debt,
            strong: true,
            color: inv.debt > 0 ? AppColors.expense.last : null,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? '${widget.type.label} جديدة'
              : 'تعديل ${widget.type.label} $_number',
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.gradient(
              _isSale ? AppColors.income : AppColors.expense,
            ),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            header,
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: lines),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: totals),
                ],
              )
            else ...[
              lines,
              const SizedBox(height: 12),
              totals,
            ],
            // مساحة تحت المحتوى حتى لا يغطي زر الحفظ العائم آخر سطر.
            const SizedBox(height: 120),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('حفظ الفاتورة'),
      ),
    );
  }

  Widget _field(Widget child) => SizedBox(width: 260, child: child);

  Widget _lineRow(int i, _LineDraft l, TextInputType decimal) {
    final product = s.productById(l.productId);
    final available = s.stockOf(
      l.productId,
      warehouseId: _warehouseId,
      excludeInvoiceId: widget.existing?.id,
    );
    return Padding(
      key: ObjectKey(l),
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ProductThumb(
            product: product,
            onTap: product == null
                ? null
                : () => uploadProductImage(context, product),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: l.productId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'الصنف ${i + 1}',
                helperText: _isSale
                    ? 'المتاح: ${fmt.number(available)} ${product?.unit ?? ''}'
                    : null,
              ),
              items: [
                for (final p in s.products)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                l.productId = v!;
                l.price.text = _defaultPrice(v);
              }),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: l.qty,
              decoration: InputDecoration(
                labelText: 'الكمية',
                suffixText: product?.unit,
              ),
              keyboardType: decimal,
              validator: numberValidator(min: 0.001),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: l.price,
              decoration: const InputDecoration(labelText: 'سعر الفرد'),
              keyboardType: decimal,
              validator: numberValidator(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              fmt.money(l.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'حذف السطر',
            icon: Icon(
              Icons.remove_circle_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              setState(() => _lines.removeAt(i));
              // التخلص من وحدات التحكم بعد إزالة حقولها من الشجرة.
              WidgetsBinding.instance.addPostFrameCallback((_) => l.dispose());
            },
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool strong = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.bold : null,
      fontSize: strong ? 18 : null,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(fmt.money(value), style: style),
        ],
      ),
    );
  }
}
