/// يحوّل قائمة ملصوقة (من واتساب أو ملاحظات) إلى أسماء أصناف، سطر لكل صنف.
///
/// يحذف بداية رسائل واتساب مثل «[١٢‏/١٠، ٢١:١٣] محمد آبا: »، والأسطر الفارغة
/// والمكررة.
List<String> parseItemList(String text) {
  final whatsapp = RegExp(r'^\[[^\]]*\]\s*[^:\n]{1,40}:\s*');
  final seen = <String>{};
  final out = <String>[];
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    final line = raw
        .replaceAll(RegExp('[\\u200e\\u200f\\u202a-\\u202e]'), '')
        .trim()
        .replaceFirst(whatsapp, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (line.isEmpty) continue;
    if (seen.add(line.toLowerCase())) out.add(line);
  }
  return out;
}
