import 'package:shared_preferences/shared_preferences.dart';

/// Central place that tracks the user's daily activity streak.
///
/// A "streak" measures consecutive calendar days on which the user did
/// *something* meaningful in the app — logging a meal, recording a weight /
/// body measurement, logging water, etc. Any of those calls
/// [recordActivity], which bumps the streak at most once per day.
///
/// Keys (`streak`, `streak_last_date`) are shared with the home screen and the
/// nutrition log, and the date format (`yyyy-MM-dd`) matches the value that was
/// already being written, so existing streaks carry over unchanged.
class StreakService {
  static const String streakKey = 'streak';
  static const String lastDateKey = 'streak_last_date';

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Records a streak-qualifying activity for today.
  ///
  /// - If today was already counted, the streak is left unchanged.
  /// - If the last activity was yesterday, the streak increments by one.
  /// - Otherwise (gap of 2+ days, or first ever activity) it resets to 1.
  ///
  /// Returns the current streak value after the update.
  static Future<int> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final lastLogged = prefs.getString(lastDateKey) ?? '';

    // Already counted today — don't increment again.
    if (lastLogged == todayKey) {
      return prefs.getInt(streakKey) ?? 0;
    }

    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final current = prefs.getInt(streakKey) ?? 0;
    final newStreak = lastLogged == yesterday ? current + 1 : 1;

    await prefs.setInt(streakKey, newStreak);
    await prefs.setString(lastDateKey, todayKey);
    return newStreak;
  }

  /// Returns the current streak without modifying it.
  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(lastDateKey) ?? '';
    if (last.isEmpty) return 0;

    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

    // Streak is only "alive" if the last activity was today or yesterday.
    if (last == today || last == yesterday) {
      return prefs.getInt(streakKey) ?? 0;
    }
    return 0;
  }
}
