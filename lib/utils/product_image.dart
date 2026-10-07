import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// أقصى طول لضلع صورة الصنف بعد التصغير.
const productImageMaxSide = 320;

/// يصغّر الصورة ويحوّلها إلى JPEG بترميز base64 لتُحفظ مع الصنف.
/// يُرجع null إذا لم تكن البيانات صورة صالحة.
String? encodeProductImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // بعض الملفات التالفة تجعل المكتبة ترمي استثناءً بدل إرجاع null.
    return null;
  }
  if (decoded == null) return null;
  final resized =
      decoded.width > productImageMaxSide ||
          decoded.height > productImageMaxSide
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? productImageMaxSide : null,
          height: decoded.height > decoded.width ? productImageMaxSide : null,
        )
      : decoded;
  return base64Encode(img.encodeJpg(resized, quality: 75));
}

/// يفتح اختيار صورة من الجهاز ويُرجعها مصغّرة، أو null إذا ألغى المستخدم.
/// يرمي [FormatException] إذا لم يكن الملف صورة يمكن قراءتها.
Future<String?> pickProductImage() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final encoded = encodeProductImage(await file.readAsBytes());
  if (encoded == null) {
    throw const FormatException('تعذّر قراءة الصورة، جرّب صورة JPG أو PNG');
  }
  return encoded;
}

final _cache = <String, Uint8List>{};

/// بايتات الصورة بعد فك الترميز، مع ذاكرة مؤقتة حتى لا تُفك في كل إعادة رسم.
Uint8List productImageBytes(String base64Image) {
  if (_cache.length > 200) _cache.clear();
  return _cache[base64Image] ??= base64Decode(base64Image);
}
