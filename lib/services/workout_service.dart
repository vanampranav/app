import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_session.dart';

/// Local (SharedPreferences) store for workout days, keyed by date.
/// Mirrors the pattern used by MemberService for weight measurements.
class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  static const String _dayPrefix = 'workout_day_';
  static const String _indexKey = 'workout_dates';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<WorkoutDay> getDay(DateTime date) async {
    final p = await _p;
    final key = WorkoutDay.keyFor(date);
    final raw = p.getString('$_dayPrefix$key');
    if (raw == null) return WorkoutDay(date: key);
    try {
      return WorkoutDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WorkoutDay(date: key);
    }
  }

  /// Saves (or, if empty, deletes) a day and keeps the date index in sync.
  Future<void> saveDay(WorkoutDay day) async {
    final p = await _p;
    final key = '$_dayPrefix${day.date}';
    if (day.exercises.isEmpty) {
      await p.remove(key);
      await _removeFromIndex(day.date);
      return;
    }
    await p.setString(key, jsonEncode(day.toJson()));
    await _addToIndex(day.date);
  }

  /// All dates that have a logged workout, newest first.
  Future<List<String>> loggedDates() async {
    final p = await _p;
    final list = List<String>.from(p.getStringList(_indexKey) ?? const []);
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<List<WorkoutDay>> recentDays({int limit = 30}) async {
    final dates = await loggedDates();
    final out = <WorkoutDay>[];
    for (final d in dates.take(limit)) {
      final parts = d.split('-');
      if (parts.length != 3) continue;
      final dt = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      out.add(await getDay(dt));
    }
    return out;
  }

  Future<void> _addToIndex(String date) async {
    final p = await _p;
    final list = List<String>.from(p.getStringList(_indexKey) ?? const []);
    if (!list.contains(date)) {
      list.add(date);
      await p.setStringList(_indexKey, list);
    }
  }

  Future<void> _removeFromIndex(String date) async {
    final p = await _p;
    final list = List<String>.from(p.getStringList(_indexKey) ?? const []);
    if (list.remove(date)) {
      await p.setStringList(_indexKey, list);
    }
  }
}
