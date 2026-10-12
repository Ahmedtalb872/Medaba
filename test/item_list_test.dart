import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/utils/item_list.dart';

void main() {
  test('a list pasted from WhatsApp becomes item names', () {
    const pasted = '''
[١٢‏/١٠، ٢١:١٣] محمد آبا: 0.66 غ
[١٢‏/١٠، ٢١:١٣] محمد آبا: 2.22غ
[١٢‏/١٠، ٢١:٢١] محمد آبا: #9.5
[١٢‏/١٠، ٢١:٢١] محمد آبا: 25#whaite

[١٢‏/١٠، ٢١:٢٢] محمد آبا: 2040# glass
[١٢‏/١٠، ٢١:٢٢] محمد آبا: #9.5
''';
    expect(parseItemList(pasted), [
      '0.66 غ',
      '2.22غ',
      '#9.5',
      '25#whaite',
      '2040# glass',
    ]);
  });

  test('plain lines are kept as they are', () {
    expect(parseItemList('أسمنت\n  حديد 12 مم \n\nأسمنت'), [
      'أسمنت',
      'حديد 12 مم',
    ]);
  });
}
