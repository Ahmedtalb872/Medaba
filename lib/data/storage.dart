import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// طبقة تخزين بسيطة: كل مجموعة تُحفظ كقائمة JSON تحت مفتاح.
/// يمكن لاحقاً استبدالها بقاعدة بيانات أو خادم (Firebase / REST) دون تغيير الواجهات.
abstract class Storage {
  Future<List<Map<String, dynamic>>> readList(String key);
  Future<void> writeList(String key, List<Map<String, dynamic>> items);
}

class PrefsStorage implements Storage {
  final SharedPreferences _prefs;
  PrefsStorage(this._prefs);

  static Future<PrefsStorage> create() async =>
      PrefsStorage(await SharedPreferences.getInstance());

  @override
  Future<List<Map<String, dynamic>>> readList(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items));
}

/// تخزين في الذاكرة، يُستخدم في الاختبارات.
class MemoryStorage implements Storage {
  final Map<String, List<Map<String, dynamic>>> data = {};

  @override
  Future<List<Map<String, dynamic>>> readList(String key) async =>
      List.of(data[key] ?? const []);

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> items) async =>
      data[key] = List.of(items);
}
