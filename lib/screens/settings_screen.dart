import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    void done(String msg) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(title: 'الإعدادات'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('تحميل بيانات تجريبية'),
                subtitle: const Text(
                  'يضيف شركاء وعمالاً ومخازن وأصنافاً ومعاملات لآخر 6 أشهر للعرض',
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
                  'يحذف جميع الشركاء والعمال والمخازن والأصناف والمعاملات',
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
