import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/models.dart';
import '../pdf/deal_statement_pdf.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' as fmt;
import '../utils/share_pdf.dart';
import '../widgets/common.dart';

Future<void> openDealStatement(BuildContext context, Partner p) {
  final s = context.read<AppState>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: s,
        child: DealStatementPage(partnerId: p.id),
      ),
    ),
  );
}

/// كشف الصفقة: مصروفاتها ومداخيلها وشركاؤها، مع إرسالها للشريك PDF.
class DealStatementPage extends StatelessWidget {
  final String partnerId;
  const DealStatementPage({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.partners.where((x) => x.id == partnerId).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('الشريك محذوف')),
      );
    }
    final deal = s.dealStatement(p);
    final share = s.dealShareOf(p);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget line(DealLine e, Color color) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(e.label.isEmpty ? '-' : e.label),
      subtitle: e.date == null ? null : Text(fmt.date(e.date!)),
      trailing: Text(
        fmt.money(e.amount),
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف ${deal.title}'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF للشريك'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _DealPdfPage(
                    deal: deal,
                    partner: p,
                    withdrawn: s.withdrawnBy(p.id),
                    company: s.company,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExpense(context, s, p),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: ListView(
        padding: pagePadding.copyWith(top: 16, bottom: 120),
        children: [
          StatGrid(
            children: [
              StatCard(
                label: 'المصروفات',
                value: fmt.money(deal.expensesTotal),
                icon: Icons.receipt_long_outlined,
                colors: AppColors.expense,
              ),
              StatCard(
                label: 'ربح الصفقة',
                value: deal.profit == null
                    ? 'لم تنتهِ بعد'
                    : fmt.money(deal.profit!),
                icon: Icons.trending_up,
                colors: (deal.profit ?? 0) >= 0 ? AppColors.ok : AppColors.loss,
              ),
              StatCard(
                label: 'نصيب ${p.name} (${fmt.percent(p.sharePercent)})',
                value: share == null ? '-' : fmt.money(share),
                icon: Icons.handshake_outlined,
                colors: AppColors.income,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'المصروفات',
            icon: Icons.receipt_long_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (deal.expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'لا توجد مصروفات مسجلة. اضغط «إضافة مصروف».',
                      style: TextStyle(color: muted),
                    ),
                  ),
                for (final e in deal.expenses) line(e, AppColors.expense.last),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'إجمالي المصروفات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      fmt.money(deal.expensesTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (deal.income.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'المداخيل',
              icon: Icons.payments_outlined,
              child: Column(
                children: [
                  for (final e in deal.income) line(e, AppColors.income.last),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'الشركاء في الصفقة',
            icon: Icons.groups_outlined,
            child: Column(
              children: [
                for (final x in deal.partners)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(x.name),
                    subtitle: Text(
                      'دفع ${fmt.money(x.capital)} • ${fmt.percent(x.sharePercent)}',
                    ),
                    trailing: Text(
                      s.dealShareOf(x) == null
                          ? '-'
                          : fmt.money(s.dealShareOf(x)!),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, AppState s, Partner p) {
    final key = GlobalKey<FormState>();
    final label = TextEditingController();
    final amount = TextEditingController();
    var date = DateTime.now();
    return showFormDialog(
      context: context,
      formKey: key,
      title: 'مصروف على ${s.dealLabel(p)}',
      fields: (setState) => [
        TextFormField(
          controller: label,
          decoration: const InputDecoration(
            labelText: 'البيان (نقل، جمارك، إصلاح...)',
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? 'هذا الحقل مطلوب' : null,
        ),
        TextFormField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: numberValidator(min: 0.01),
        ),
        DateField(
          label: 'التاريخ',
          value: date,
          onChanged: (d) => setState(() => date = d),
        ),
      ],
      onSave: () async {
        try {
          await s.addDealExpense(
            p,
            label: label.text.trim(),
            amount: fmt.parseNumber(amount.text) ?? 0,
            date: date,
          );
        } on StateError catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
    );
  }
}

class _DealPdfPage extends StatefulWidget {
  final DealStatement deal;
  final Partner partner;
  final double withdrawn;
  final CompanyInfo company;
  const _DealPdfPage({
    required this.deal,
    required this.partner,
    required this.withdrawn,
    required this.company,
  });

  @override
  State<_DealPdfPage> createState() => _DealPdfPageState();
}

class _DealPdfPageState extends State<_DealPdfPage> {
  /// يُبنى الملف مرة واحدة فيكون جاهزاً للمشاركة مباشرة على الهاتف.
  late final Future<Uint8List> _pdf = buildDealStatementPdf(
    deal: widget.deal,
    partner: widget.partner,
    withdrawn: widget.withdrawn,
    company: widget.company,
  );

  String get fileName => 'كشف-${widget.partner.name}.pdf';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('كشف ${widget.partner.name}'),
      actions: [
        IconButton(
          tooltip: 'طباعة',
          icon: const Icon(Icons.print_outlined),
          onPressed: () =>
              Printing.layoutPdf(name: fileName, onLayout: (_) => _pdf),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('إرسال / تنزيل'),
            onPressed: () async => sharePdfFile(await _pdf, fileName),
          ),
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) => _pdf,
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
            'استخدم زر «إرسال / تنزيل» أو «طباعة» في الأعلى.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
