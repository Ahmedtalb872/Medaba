import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'synced_storage.dart';

/// رابط مشروع Supabase ومفتاحه العام (publishable). المفتاح العام مصمَّم ليكون
/// داخل التطبيق؛ حماية البيانات تأتي من تسجيل الدخول وسياسات RLS في
/// supabase/schema.sql. يمكن تغييرهما عند البناء بـ --dart-define، والقيمة
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

/// الجدول app_data: صف لكل مفتاح، وعمود value يحمل القائمة.
class SupabaseRemoteStore implements RemoteStore {
  final SupabaseClient client;
  SupabaseRemoteStore(this.client);

  static const table = 'app_data';

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchAll() async {
    final rows = await client.from(table).select('key, value');
    return {
      for (final r in rows)
        r['key'] as String: [
          for (final e in (r['value'] as List? ?? const []))
            Map<String, dynamic>.from(e as Map),
        ],
    };
  }

  @override
  Future<void> put(String key, List<Map<String, dynamic>> items) =>
      client.from(table).upsert({
        'key': key,
        'value': items,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}
