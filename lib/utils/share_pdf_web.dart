import 'dart:js_interop';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

/// في المتصفح: على الهاتف والجهاز اللوحي تُفتح قائمة المشاركة بالملف وحده
/// (بدون رابط blob الذي كان يظهر مع الفاتورة في واتساب)، وعلى الحاسوب
/// يُنزَّل الملف.
Future<void> sharePdfFile(Uint8List bytes, String filename) async {
  if (_isPhone) {
    final file = web.File(
      [bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: 'application/pdf'),
    );
    final data = web.ShareData(files: [file].toJS);
    bool canShare;
    try {
      canShare = web.window.navigator.canShare(data);
    } catch (_) {
      // متصفحات قديمة بدون Web Share: ننزّل الملف.
      canShare = false;
    }
    if (canShare) {
      try {
        await web.window.navigator.share(data).toDart;
        return;
      } catch (e) {
        // أغلق المستخدم قائمة المشاركة.
        if ('$e'.contains('AbortError')) return;
        // رفض المتصفح المشاركة (مثلاً انتهت مهلة الضغطة): ننزّل الملف.
      }
    }
  }
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

/// هاتف أو جهاز لوحي. الأجهزة اللوحية تفتح المواقع غالباً بوضع الحاسوب
/// فلا يظهر نوعها في userAgent، فنعتمد أيضاً على شاشة اللمس.
bool get _isPhone {
  final nav = web.window.navigator;
  if (RegExp(
    'Android|iPhone|iPad|iPod|Mobile',
    caseSensitive: false,
  ).hasMatch(nav.userAgent)) {
    return true;
  }
  // iPad بلوحة مفاتيح وفأرة يُظهر نفسه حاسوباً (Macintosh) ومؤشره «دقيق»،
  // لكن شاشته تبقى شاشة لمس، فيكفي وجود اللمس.
  try {
    return nav.maxTouchPoints > 0;
  } catch (_) {
    return false;
  }
}
