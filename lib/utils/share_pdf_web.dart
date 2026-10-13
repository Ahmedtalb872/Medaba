import 'dart:js_interop';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

/// في المتصفح: على الهاتف تُفتح قائمة المشاركة بالملف وحده (بدون رابط blob
/// الذي كان يظهر مع الفاتورة في واتساب)، وعلى الحاسوب يُنزَّل الملف.
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
      } catch (_) {
        // أغلق المستخدم قائمة المشاركة.
      }
      return;
    }
  }
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

bool get _isPhone => RegExp(
  'Android|iPhone|iPad|iPod|Mobile',
  caseSensitive: false,
).hasMatch(web.window.navigator.userAgent);
