import 'dart:async';

import 'package:flutter/foundation.dart';

import 'storage.dart';

/// مخزن البيانات على الإنترنت: كل مفتاح يُحفظ كقائمة JSON كاملة.
abstract class RemoteStore {
  /// كل المفاتيح المحفوظة وقوائمها.
  Future<Map<String, List<Map<String, dynamic>>>> fetchAll();

  /// يستبدل قائمة المفتاح بالكامل.
  Future<void> put(String key, List<Map<String, dynamic>> items);
}

enum SyncStatus {
  synced('محفوظ في قاعدة البيانات'),
  syncing('جارٍ الحفظ...'),
  offline('لا يوجد اتصال: البيانات محفوظة على الجهاز وستُرفع تلقائياً');

  final String label;
  const SyncStatus(this.label);
}

/// تخزين محلي أولاً ثم رفع إلى قاعدة البيانات في الخلفية.
///
/// كل حفظ يُكتب فوراً على الجهاز ثم يُرفع؛ عند انقطاع الإنترنت تبقى التغييرات
/// في قائمة انتظار محفوظة على الجهاز وتُعاد محاولة رفعها تلقائياً.
class SyncedStorage implements Storage {
  final Storage local;
  final RemoteStore remote;
  final Duration retryDelay;

  final status = ValueNotifier(SyncStatus.syncing);

  /// المفاتيح التي تغيرت ولم تُرفع بعد.
  final Set<String> _dirty = {};
  Future<void>? _flushing;
  Timer? _retry;

  static const _pendingKey = '__sync_pending';

  SyncedStorage({
    required this.local,
    required this.remote,
    this.retryDelay = const Duration(seconds: 15),
  });

  /// يجلب البيانات من قاعدة البيانات إلى الجهاز قبل تحميل التطبيق.
  ///
  /// - التغييرات التي لم تُرفع من جلسة سابقة تبقى وتُرفع.
  /// - إذا كانت قاعدة البيانات فارغة (أول ربط) تُرفع بيانات الجهاز إليها.
  /// - بدون اتصال يعمل التطبيق بآخر نسخة على الجهاز.
  Future<void> init(List<String> keys) async {
    _dirty.addAll(
      (await local.readList(_pendingKey)).map((e) => e['key'] as String),
    );
    try {
      final all = await remote.fetchAll();
      if (all.isEmpty) {
        for (final k in keys) {
          if ((await local.readList(k)).isNotEmpty) _dirty.add(k);
        }
      } else {
        for (final k in keys) {
          if (_dirty.contains(k)) continue;
          await local.writeList(k, all[k] ?? const []);
        }
      }
      await _savePending();
      status.value = SyncStatus.synced;
    } catch (e) {
      debugPrint('sync init failed: $e');
      status.value = SyncStatus.offline;
    }
    if (_dirty.isNotEmpty) unawaited(flush());
  }

  @override
  Future<List<Map<String, dynamic>>> readList(String key) =>
      local.readList(key);

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    await local.writeList(key, items);
    _dirty.add(key);
    await _savePending();
    unawaited(flush());
  }

  bool get hasPending => _dirty.isNotEmpty;

  /// يرفع كل ما تغيّر؛ ينتظر الرفع الجاري إن وُجد.
  Future<void> flush() async {
    while (_flushing != null) {
      await _flushing;
    }
    if (_dirty.isEmpty) return;
    final done = Completer<void>();
    _flushing = done.future;
    _retry?.cancel();
    status.value = SyncStatus.syncing;
    try {
      while (_dirty.isNotEmpty) {
        final key = _dirty.first;
        _dirty.remove(key);
        try {
          await remote.put(key, await local.readList(key));
        } catch (e) {
          debugPrint('sync put $key failed: $e');
          _dirty.add(key);
          status.value = SyncStatus.offline;
          _retry = Timer(retryDelay, () => unawaited(flush()));
          return;
        }
      }
      status.value = SyncStatus.synced;
    } finally {
      await _savePending();
      _flushing = null;
      done.complete();
    }
  }

  Future<void> _savePending() => local.writeList(_pendingKey, [
    for (final k in _dirty) {'key': k},
  ]);

  void dispose() {
    _retry?.cancel();
    status.dispose();
  }
}
