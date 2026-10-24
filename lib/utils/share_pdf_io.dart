import 'dart:typed_data';

import 'package:printing/printing.dart';

/// على الأجهزة: قائمة المشاركة/الحفظ الخاصة بالنظام.
Future<void> sharePdfFile(Uint8List bytes, String filename) =>
    Printing.sharePdf(bytes: bytes, filename: filename);
