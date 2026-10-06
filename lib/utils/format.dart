import 'package:intl/intl.dart';

/// رمز العملة المعروض. غيّره حسب بلد الزبون.
const currencySymbol = 'ر.س';

final _money = NumberFormat('#,##0.##', 'en');
final _date = DateFormat('yyyy/MM/dd', 'en_US');
final _month = DateFormat('MM/yyyy', 'en_US');

String money(num v) => '${_money.format(v)} $currencySymbol';
String number(num v) => _money.format(v);
String percent(num v) => '${_money.format(v)}%';
String date(DateTime d) => _date.format(d);
String month(DateTime d) => _month.format(d);

/// يحوّل نصاً مُدخلاً إلى رقم، ويقبل الأرقام العربية الهندية.
double? parseNumber(String? s) {
  if (s == null) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var t = s.trim().replaceAll(',', '').replaceAll('٬', '').replaceAll('٫', '.');
  for (var i = 0; i < arabic.length; i++) {
    t = t.replaceAll(arabic[i], '$i');
  }
  return double.tryParse(t);
}
