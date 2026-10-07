import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../state/app_state.dart';
import '../utils/format.dart' as fmt;
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    void done(String msg) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(title: 'الإعدادات'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('بيانات المنشأة'),
            subtitle: Text('${s.company.name} • رأس الفاتورة وحسابات الدفع'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _editCompany(context, s),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('تحميل بيانات تجريبية'),
                subtitle: const Text(
                  'يضيف شركاء وعمالاً ومخازن وأصنافاً وفواتير ومعاملات لآخر 6 أشهر للعرض',
                ),
                onTap: () async {
                  await s.seedDemoData();
                  done('تمت إضافة البيانات التجريبية');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('حذف كل البيانات'),
                subtitle: const Text(
                  'يحذف جميع الشركاء والعمال والمخازن والأصناف والفواتير والمعاملات',
                ),
                onTap: () async {
                  if (await confirmDelete(context, 'كل البيانات')) {
                    await s.clearAll();
                    done('تم حذف كل البيانات');
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _editCompany(BuildContext context, AppState s) {
  final c = s.company;
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: c.name);
  final phone = TextEditingController(text: c.phone);
  final address = TextEditingController(text: c.address);
  final taxNumber = TextEditingController(text: c.taxNumber);
  final tax = TextEditingController(text: fmt.number(c.defaultTaxPercent));
  final accounts = [
    for (final a in c.paymentAccounts)
      (
        name: TextEditingController(text: a.name),
        number: TextEditingController(text: a.number),
      ),
  ];

  return showFormDialog(
    context: context,
    formKey: key,
    title: 'بيانات المنشأة',
    fields: (setState) => [
      TextFormField(
        controller: name,
        decoration: const InputDecoration(labelText: 'اسم المنشأة'),
        validator: requiredText,
      ),
      TextFormField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'الهاتف'),
        keyboardType: TextInputType.phone,
      ),
      TextFormField(
        controller: address,
        decoration: const InputDecoration(labelText: 'العنوان'),
      ),
      TextFormField(
        controller: taxNumber,
        decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
      ),
      TextFormField(
        controller: tax,
        decoration: const InputDecoration(
          labelText: 'نسبة الضريبة الافتراضية للفواتير %',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: numberValidator(max: 100, required: false),
      ),
      const Text(
        'حسابات الدفع (تظهر أسفل فواتير البيع)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final (i, a) in accounts.indexed)
        Row(
          key: ObjectKey(a),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: a.name,
                decoration: const InputDecoration(
                  labelText: 'التطبيق أو البنك',
                ),
                validator: requiredText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: a.number,
                decoration: const InputDecoration(labelText: 'رقم الحساب'),
                textDirection: TextDirection.ltr,
                validator: requiredText,
              ),
            ),
            IconButton(
              tooltip: 'حذف الحساب',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() => accounts.removeAt(i)),
            ),
          ],
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(
            () => accounts.add((
              name: TextEditingController(),
              number: TextEditingController(),
            )),
          ),
          icon: const Icon(Icons.add),
          label: const Text('إضافة حساب دفع'),
        ),
      ),
    ],
    onSave: () => s.saveCompany(
      CompanyInfo(
        name: name.text.trim(),
        phone: phone.text.trim(),
        address: address.text.trim(),
        taxNumber: taxNumber.text.trim(),
        defaultTaxPercent: fmt.parseNumber(tax.text) ?? 0,
        paymentAccounts: [
          for (final a in accounts)
            PaymentAccount(a.name.text.trim(), a.number.text.trim()),
        ],
      ),
    ),
  );
}
