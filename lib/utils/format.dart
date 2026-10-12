import 'package:intl/intl.dart';

/// العملة: الأوقية الموريتانية (MRU).
const currencySymbol = 'أوقية';

final _money = NumberFormat('#,##0.##', 'en');
final _date = DateFormat('yyyy/MM/dd', 'en_US');
final _month = DateFormat('MM/yyyy', 'en_US');

String money(num v) => '${_money.format(v)} $currencySymbol';
String number(num v) => _money.format(v);
String percent(num v) => '${_money.format(v)}%';
String date(DateTime d) => _date.format(d);
String month(DateTime d) => _month.format(d);

/// يحوّل نصاً مُدخلاً إلى رقم، ويقبل الأرقام العربية الهندية والفارسية.
///
/// الحروف والوحدات المكتوبة مع الرقم تُتجاهل، مثل «2300000mru» أو «300m»
/// أو «150 أوقية»؛ والنص بلا أرقام يُرجع null.
double? parseNumber(String? s) {
  if (s == null) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
  var t = s.trim().replaceAll('٫', '.');
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  final negative = t.startsWith('-');
  t = t.replaceAll(RegExp(r'[^0-9.]'), '');
  if (t.isEmpty || !t.contains(RegExp(r'[0-9]'))) return null;
  final n = double.tryParse(t);
  return n == null ? null : (negative ? -n : n);
}
