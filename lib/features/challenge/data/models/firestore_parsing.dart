import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses a date that may be a Firestore Timestamp, an ISO-8601 String,
/// epoch millis (int), or a DateTime. Returns null if unparseable/absent.
///
/// This exists because some docs are written by the REST/AI-Coach flow as ISO
/// strings while the SDK writes Timestamps — a raw `as Timestamp` cast crashes.
DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Non-null date parse with a fallback (for required date fields).
DateTime parseFirestoreDateOr(dynamic value, DateTime fallback) =>
    parseFirestoreDate(value) ?? fallback;

/// Robust int parse (handles int, double/num, numeric String).
int parseIntOr(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Robust double parse (handles double, int/num, numeric String).
double parseDoubleOr(dynamic value, double fallback) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
