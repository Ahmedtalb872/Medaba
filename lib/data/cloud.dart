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

SupabaseClient? _client;
SupabaseClient get cloudClient =>
    _client ??= SupabaseClient(supabaseUrl, supabaseKey);

/// اسم المستخدم وكلمة المرور كما في الجدول app_users (بدون بريد).
class CloudLogin {
  final String username;
  final String password;
  const CloudLogin(this.username, this.password);

  Map<String, dynamic> get params => {'p_user': username, 'p_pass': password};

  Map<String, dynamic> toJson() => {'u': username, 'p': password};
  static CloudLogin? fromJson(Map<String, dynamic> j) =>
      j['u'] is String && j['p'] is String
      ? CloudLogin(j['u'] as String, j['p'] as String)
      : null;
}

/// صحيح أو خطأ؛ يرمي استثناءً إذا تعذّر الاتصال.
Future<bool> checkLogin(SupabaseClient client, CloudLogin login) async =>
    await client.rpc('app_login', params: login.params) == true;

/// الدوال app_fetch و app_put في قاعدة البيانات، تتحقق من الدخول في كل طلب.
class SupabaseRemoteStore implements RemoteStore {
  final SupabaseClient client;
  final CloudLogin login;
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
