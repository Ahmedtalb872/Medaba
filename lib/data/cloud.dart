import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'synced_storage.dart';

/// رابط مشروع Supabase ومفتاحه العام (publishable). المفتاح العام مصمَّم ليكون
/// داخل التطبيق؛ البيانات محمية باسم المستخدم وكلمة المرور (انظر
/// supabase/schema.sql). يمكن تغييرهما عند البناء بـ --dart-define، والقيمة
/// الفارغة تعيد التطبيق إلى الحفظ على الجهاز فقط.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wlquoprzyljeskkkcwox.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_v2N10u1H9S37DLX0EiK9vg_WC_Mf2bK',
);

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

/// حالة الربط الحالية، أو null عند العمل على الجهاز فقط (والاختبارات).
final cloudSync = ValueNotifier<SyncStatus?>(null);

/// يُستدعى من زر «تسجيل الخروج»؛ يعيّنه [CloudGate].
Future<void> Function()? cloudSignOut;

/// يغيّر كلمة مرور الحساب الداخل؛ يُرجع رسالة خطأ أو null. يعيّنه [CloudGate].
Future<String?> Function(String current, String next)? cloudChangePassword;

/// الحساب الداخل حالياً، أو null عند العمل على الجهاز فقط.
CloudLogin? cloudLogin;

/// عامل المخزون يرى المخزون فقط؛ المدير يرى كل شيء.
bool get isStockWorker => cloudLogin?.role == CloudLogin.stockRole;

SupabaseClient? _client;
SupabaseClient get cloudClient =>
    _client ??= SupabaseClient(supabaseUrl, supabaseKey);

/// اسم المستخدم وكلمة المرور كما في الجدول app_users (بدون بريد).
class CloudLogin {
  static const adminRole = 'admin';
  static const stockRole = 'stock';

  final String username;
  final String password;

  /// admin أو stock (عامل المخزون).
  final String role;
  const CloudLogin(this.username, this.password, [this.role = adminRole]);

  Map<String, dynamic> get params => {'p_user': username, 'p_pass': password};

  Map<String, dynamic> toJson() => {'u': username, 'p': password, 'r': role};
  static CloudLogin? fromJson(Map<String, dynamic> j) =>
      j['u'] is String && j['p'] is String
      ? CloudLogin(
          j['u'] as String,
          j['p'] as String,
          j['r'] as String? ?? adminRole,
        )
      : null;
}

/// الحساب مع دوره، أو null إذا كان الدخول خاطئاً؛ يرمي استثناءً إذا تعذّر
/// الاتصال. قاعدة بيانات بدون أدوار (قبل تحديث SQL) تعامل الجميع كمدير.
Future<CloudLogin?> checkLogin(SupabaseClient client, CloudLogin login) async {
  try {
    final role = await client.rpc('app_role', params: login.params);
    return role is String
        ? CloudLogin(login.username, login.password, role)
        : null;
  } on PostgrestException catch (e) {
    if (e.code != 'PGRST202') rethrow;
  }
  final ok = await client.rpc('app_login', params: login.params) == true;
  return ok ? CloudLogin(login.username, login.password) : null;
}

/// يوحّد ما يُكتب في خانات الدخول: الأرقام العربية (٠١٢) والفارسية تصبح
/// 0-9 وتُحذف المسافات حول النص، حتى يتطابق ما كُتب عند إنشاء الحساب وعند
/// الدخول مهما كانت لوحة المفاتيح.
String cleanCredential(String s) {
  final out = StringBuffer();
  for (final c in s.trim().runes) {
    if (c >= 0x0660 && c <= 0x0669) {
      out.writeCharCode(0x30 + c - 0x0660);
    } else if (c >= 0x06F0 && c <= 0x06F9) {
      out.writeCharCode(0x30 + c - 0x06F0);
    } else {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// اسم المستخدم لا يفرّق بين الحروف الكبيرة والصغيرة (Med = med).
String cleanUsername(String s) => cleanCredential(s).toLowerCase();

/// حساب في قاعدة البيانات كما تعرضه صفحة «حسابات العمال».
typedef CloudUser = ({String username, String role});

/// إدارة حسابات العمال (للمدير فقط).
class CloudUsers {
  final SupabaseClient client;
  final CloudLogin admin;
  CloudUsers(this.client, this.admin);

  Future<List<CloudUser>> list() async {
    final rows =
        await client.rpc('app_users_list', params: admin.params) as List;
    return [
      for (final r in rows.cast<Map>())
        (username: r['username'] as String, role: r['role'] as String),
    ];
  }

  Future<void> save(String username, String password, String role) =>
      client.rpc(
        'app_user_save',
        params: {
          ...admin.params,
          'p_name': cleanUsername(username),
          'p_password': cleanCredential(password),
          'p_role': role,
        },
      );

  Future<void> delete(String username) => client.rpc(
    'app_user_delete',
    params: {...admin.params, 'p_name': username},
  );
}

/// الدوال app_fetch و app_put في قاعدة البيانات، تتحقق من الدخول في كل طلب.
class SupabaseRemoteStore implements RemoteStore {
  final SupabaseClient client;

  /// يتغيّر بعد تغيير كلمة المرور حتى يستمر الحفظ بدون إعادة الدخول.
  CloudLogin login;
  SupabaseRemoteStore(this.client, this.login);

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchAll() async {
    final rows = await client.rpc('app_fetch', params: login.params) as List;
    return {
      for (final r in rows.cast<Map>())
        r['key'] as String: [
          for (final e in (r['value'] as List? ?? const []))
            Map<String, dynamic>.from(e as Map),
        ],
    };
  }

  @override
  Future<void> put(String key, List<Map<String, dynamic>> items) => client.rpc(
    'app_put',
    params: {...login.params, 'p_key': key, 'p_value': items},
  );
}
