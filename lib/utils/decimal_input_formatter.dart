import 'package:flutter/services.dart';

/// Restricts a text field to a plain decimal number with at most [decimalRange]
/// digits after the point (e.g. "69.9") and, optionally, at most
/// [maxIntegerDigits] digits before it (so "69848484848484" is impossible).
/// Rejects a second dot, extra decimals, and any non-numeric character. Used on
/// challenge weight / body-fat / muscle inputs so measurements stay sane instead
/// of accepting raw sensor precision or absurd magnitudes.
class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;
  final int? maxIntegerDigits;

  DecimalTextInputFormatter({this.decimalRange = 1, this.maxIntegerDigits})
      : assert(decimalRange >= 0),
        assert(maxIntegerDigits == null || maxIntegerDigits > 0);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final intPart = maxIntegerDigits == null ? '\\d*' : '\\d{0,$maxIntegerDigits}';
    // Decimals are only allowed after a literal dot, so the integer-digit cap
    // can't be bypassed by a trailing digit without a decimal point.
    final regex = RegExp('^$intPart(\\.\\d{0,$decimalRange})?\$');
    if (!regex.hasMatch(text)) return oldValue;
    return newValue;
  }
}

/// Formats a numeric measurement for display in a text field: trims raw float
/// precision to at most 1 decimal and drops a trailing ".0" (70.0 → "70").
///
/// Accepts a raw dynamic value (num, numeric String, or null) because Firestore
/// docs written by the REST / AI-Coach flow sometimes store numbers as Strings —
/// a hard `as num` cast on those would crash the screen. Anything unparseable
/// yields an empty string.
String formatMeasurement(dynamic value) {
  final num? n = value is num
      ? value
      : (value is String ? num.tryParse(value) : null);
  if (n == null) return '';
  final s = n.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
