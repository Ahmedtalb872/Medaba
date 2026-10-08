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
import '../widgets/data_table_card.dart';
import '../widgets/product_thumb.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  InvoiceType? _type;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final month = Period.month(DateTime.now());
    double monthTotal(InvoiceType t) => s.invoices
        .where((i) => i.type == t && month.contains(i.date))
        .fold(0, (sum, i) => sum + i.total);
    final items = s.invoices
        .where((i) => _type == null || i.type == _type)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'الفواتير',
          subtitle: 'فواتير البيع والشراء؛ كل فاتورة تحرّك المخزون وتُسجَّل في الحسابات',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => openInvoiceEditor(context, InvoiceType.sale),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('فاتورة بيع جديدة'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => openInvoiceEditor(context, InvoiceType.purchase),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('فاتورة شراء جديدة'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatGrid(
          children: [
            StatCard(
              label: 'مبيعات الشهر (فواتير)',
              value: fmt.money(monthTotal(InvoiceType.sale)),
              icon: Icons.point_of_sale,
              colors: AppColors.income,
            ),
            StatCard(
              label: 'مشتريات الشهر (فواتير)',
              value: fmt.money(monthTotal(InvoiceType.purchase)),
              icon: Icons.shopping_cart_outlined,
              colors: AppColors.expense,
            ),
            StatCard(
              label: 'عدد الفواتير',
              value: '${s.invoices.length}',
              icon: Icons.receipt_long_outlined,
              colors: AppColors.capital,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<InvoiceType?>(
          segments: const [
            ButtonSegment(value: null, label: Text('الكل')),
            ButtonSegment(value: InvoiceType.sale, label: Text('بيع')),
            ButtonSegment(value: InvoiceType.purchase, label: Text('شراء')),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() => _type = v.first),
        ),
        const SizedBox(height: 12),
        DataTableCard<Invoice>(
          columns: const [
            'الرقم',
            'النوع',
            'التاريخ',
            'العميل / المورد',
            'المخزن',
            'الأصناف',
            'الإجمالي',
          ],
          items: items,
          emptyMessage: 'لا توجد فواتير بعد',
          cells: (i) => [
            Text(i.number, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              i.type.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: i.type == InvoiceType.sale
                    ? AppColors.income.last
                    : AppColors.expense.last,
              ),
            ),
            Text(fmt.date(i.date)),
            Text(i.partyName.isEmpty ? '-' : i.partyName),
            Text(s.warehouseById(i.warehouseId)?.name ?? '-'),
            Text('${i.lines.length}'),
            Text(
              fmt.money(i.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          extraActions: (i) => [
            IconButton(
              tooltip: 'عرض وطباعة PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              color: AppColors.expense.last,
              onPressed: () => openInvoicePdf(context, i),
            ),
          ],
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
class InvoicePdfPage extends StatelessWidget {
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

  String get fileName => '${invoice.number}.pdf';

  Future<Uint8List> _build() => buildInvoicePdf(
    invoice: invoice,
    company: company,
    productOf: productOf,
    warehouseName: warehouseName,
    remainingDebt: remainingDebt,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${invoice.type.label} ${invoice.number}'),
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
