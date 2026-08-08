import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elefit_app/utils/decimal_input_formatter.dart';

TextEditingValue _v(String s) => TextEditingValue(text: s);

void main() {
  group('DecimalTextInputFormatter (decimals=1, maxIntegerDigits=3)', () {
    final f = DecimalTextInputFormatter(decimalRange: 1, maxIntegerDigits: 3);

    String apply(String oldText, String newText) =>
        f.formatEditUpdate(_v(oldText), _v(newText)).text;

    test('accepts up to 3 integer digits and 1 decimal', () {
      expect(apply('99', '999'), '999');
      expect(apply('99.', '99.9'), '99.9');
      expect(apply('6', '69'), '69');
    });

    test('rejects a 4th integer digit (no bypass without a dot)', () {
      // "9999" must be rejected → keeps the old value.
      expect(apply('999', '9999'), '999');
    });

    test('rejects a second decimal place', () {
      expect(apply('69.9', '69.95'), '69.9');
    });

    test('rejects letters and a second dot', () {
      expect(apply('69', '69a'), '69');
      expect(apply('69.9', '69.9.'), '69.9');
    });

    test('allows a trailing dot mid-entry and empty', () {
      expect(apply('69', '69.'), '69.');
      expect(apply('6', ''), '');
    });
  });

  group('formatMeasurement', () {
    test('trims raw sensor precision to 1 decimal', () {
      expect(formatMeasurement(69.94999694824219), '69.9');
      expect(formatMeasurement(28.76824951171875), '28.8');
    });

    test('drops a trailing .0', () {
      expect(formatMeasurement(70.0), '70');
      expect(formatMeasurement(70), '70');
    });

    test('null → empty string', () {
      expect(formatMeasurement(null), '');
    });
  });
}
