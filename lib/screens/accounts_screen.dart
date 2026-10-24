import 'package:flutter/material.dart';

import '../data/cloud.dart';
import '../widgets/common.dart';

/// حسابات الدخول: المدير يضيف حسابات لعمال المخزون ويحذفها.
/// عامل المخزون يرى صفحة المخزون وحدها.
class AccountsScreen extends StatefulWidget {
  final CloudUsers users;
  const AccountsScreen({super.key, required this.users});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late Future<List<CloudUser>> _list = widget.users.list();

  void _reload() => setState(() => _list = widget.users.list());

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _edit({CloudUser? existing}) {
    final key = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?.username);
    final password = TextEditingController();
    return showFormDialog(
      context: context,
      formKey: key,
      title: existing == null
          ? 'حساب عامل مخزون جديد'
          : 'كلمة مرور جديدة لـ ${existing.username}',
      fields: (_) => [
        TextFormField(
          controller: name,
          enabled: existing == null,
          decoration: const InputDecoration(labelText: 'اسم المستخدم'),
          validator: (v) {
            final n = v?.trim() ?? '';
            if (n.isEmpty) return 'هذا الحقل مطلوب';
            if (n == widget.users.admin.username) {
              return 'هذا اسم حساب المدير';
            }
            return null;
          },
        ),
        TextFormField(
          controller: password,
          decoration: const InputDecoration(labelText: 'كلمة المرور'),
          validator: (v) =>
              (v ?? '').length < 4 ? '4 أحرف أو أرقام على الأقل' : null,
        ),
        const Text('هذا الحساب يرى المخزون فقط: الأرصدة والأصناف والحركات.'),
      ],
      onSave: () async {
        try {
          await widget.users.save(
            name.text.trim(),
            password.text,
            CloudLogin.stockRole,
          );
          _snack('تم حفظ الحساب');
          _reload();
        } catch (_) {
          _snack('تعذّر حفظ الحساب، تحقق من الإنترنت');
        }
      },
    );
  }

  Future<void> _delete(CloudUser u) async {
    if (!await confirmDelete(context, u.username)) return;
    try {
      await widget.users.delete(u.username);
      _reload();
    } catch (_) {
      _snack('تعذّر حذف الحساب، تحقق من الإنترنت');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حسابات العمال')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('حساب عامل مخزون'),
    ),
    body: FutureBuilder<List<CloudUser>>(
      future: _list,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعذّر تحميل الحسابات. إن لم تُحدِّث كود SQL في Supabase '
                    'بعد، شغّل الملف supabase/schema.sql من جديد.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }
        final users = snap.data;
        if (users == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: pagePadding,
          children: [
            for (final u in users)
              Card(
                child: ListTile(
                  leading: Icon(
                    u.role == CloudLogin.stockRole
                        ? Icons.inventory_2_outlined
                        : Icons.admin_panel_settings_outlined,
                  ),
                  title: Text(u.username),
                  subtitle: Text(
                    u.role == CloudLogin.stockRole
                        ? 'عامل مخزون: يرى المخزون فقط'
                        : 'مدير: يرى كل شيء',
                  ),
                  trailing: u.username == widget.users.admin.username
                      ? const Text('حسابك')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (u.role == CloudLogin.stockRole)
                              IconButton(
                                tooltip: 'تغيير كلمة المرور',
                                icon: const Icon(Icons.key_outlined),
                                onPressed: () => _edit(existing: u),
                              ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(u),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
