import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/utils/format.dart' as fmt;

void main() {
  test('numbers are read with units, currency and Arabic digits', () {
    expect(fmt.parseNumber('2300000mru'), 2300000);
    expect(fmt.parseNumber('300m'), 300);
    expect(fmt.parseNumber('300 م²'), 300);
    expect(fmt.parseNumber('1,500 أوقية'), 1500);
    expect(fmt.parseNumber('MRU 2 300 000'), 2300000);
    expect(fmt.parseNumber('٢٣٠٠'), 2300);
    expect(fmt.parseNumber('۱۲٫۵'), 12.5);
    expect(fmt.parseNumber('-40'), -40);
    expect(fmt.parseNumber(' 12.5 '), 12.5);
  });

  test('text without a number is not a number', () {
    expect(fmt.parseNumber(''), isNull);
    expect(fmt.parseNumber('mru'), isNull);
    expect(fmt.parseNumber('.'), isNull);
    expect(fmt.parseNumber(null), isNull);
  });
}
