import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/device_model.dart';
import '../models/food_models.dart';

/// Singleton wrapper around the `health` package.
/// Handles Apple Health (iOS) and Google Health Connect (Android).
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _configured = false;

  // _hasPerms caches the permission state in memory after the first load.
  // It starts as false and is lazily loaded from SharedPreferences on first use.
  bool _hasPerms = false;
  bool _permsLoaded = false;

  static const String _prefsKey      = 'health_connected';
  static const String _lastSyncKey   = 'health_last_sync';

  // ── Data types ─────────────────────────────────────────────────────────────

  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.WEIGHT,
    HealthDataType.WATER,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.WORKOUT,
  ];

  static const _writeTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthDataType.DIETARY_PROTEIN_CONSUMED,
    HealthDataType.DIETARY_CARBS_CONSUMED,
    HealthDataType.DIETARY_FATS_CONSUMED,
    HealthDataType.DIETARY_FIBER,
    HealthDataType.DIETARY_SODIUM,
  ];

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('HealthService configure error: $e');
    }
  }

  /// Lazily loads cached permission state from SharedPreferences.
  /// This fixes the bug where _hasPerms is always false after an app restart,
  /// causing all sync methods to silently no-op.
  Future<bool> _ensurePermsLoaded() async {
    if (_permsLoaded) return _hasPerms;
    final prefs = await SharedPreferences.getInstance();
    _hasPerms = prefs.getBool(_prefsKey) ?? false;
    _permsLoaded = true;
    return _hasPerms;
  }

  // ── Public state ───────────────────────────────────────────────────────────

  Future<bool> get isConnected async => _ensurePermsLoaded();

  /// Returns when the last successful health sync happened, or null if never.
  Future<DateTime?> get lastSyncTime async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastSyncKey);
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  /// Requests health permissions from the OS health platform.
  ///
  /// iOS quirk: Apple HealthKit NEVER tells apps whether READ permissions were
  /// granted — hasPermissions() for read types always returns null (by design,
  /// to protect user privacy). We therefore trust that requestAuthorization()
  /// completing without an error means the user went through the sheet, and we
  /// mark the app as connected. Individual reads degrade to 0/empty if the
  /// user denied specific types.
  ///
  /// Android: requestAuthorization always returns false by Health Connect design.
  /// hasPermissions() returns true/false/null. null means can't determine
  /// (common for sideloaded/dev builds). We treat null as connected and rely on
  /// graceful degradation for individual reads.
  Future<bool> requestPermissions() async {
    await _configure();

    final types = [..._readTypes, ..._writeTypes];
    final perms = [
      ...List.filled(_readTypes.length, HealthDataAccess.READ),
      ...List.filled(_writeTypes.length, HealthDataAccess.WRITE),
    ];

    bool authorized = false;
    try {
      authorized = await _health.requestAuthorization(types, permissions: perms);
    } catch (e) {
      debugPrint('HealthService: requestAuthorization error — $e');
      await _persist(false);
      return false;
    }

    bool connected;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS: requestAuthorization returns true when the permission sheet was
      // successfully presented. hasPermissions() for READ types always returns
      // null on iOS — Apple hides this deliberately. We trust the dialog result.
      connected = authorized;
    } else {
      // Android: authorized is always false (Health Connect design).
      // Check hasPermissions() instead — null means can't determine (sideload).
      bool? verified;
      try {
        verified = await _health.hasPermissions(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
      } catch (e) {
        debugPrint('HealthService: hasPermissions check failed — $e');
      }
      // null = can't verify (sideload restriction) → treat as connected.
      // false = user explicitly denied → not connected.
      connected = verified != false;
    }

    await _persist(connected);
    return connected;
  }

  /// Re-checks whether OS-level permissions are still granted.
  /// Useful when the user returns from system Settings or the Health app.
  Future<bool> checkPermissions() async {
    await _configure();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS cannot determine read permission status — return cached state.
      // If user revoked in Settings, reads will simply return empty data.
      return await _ensurePermsLoaded();
    }

    // Android: hasPermissions() is reliable.
    bool? result;
    try {
      result = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {}

    if (result == null) {
      // Can't determine — keep cached state.
      return await _ensurePermsLoaded();
    }

    await _persist(result);
    return result;
  }

  /// Clears cached permission state. Does not revoke OS-level permissions.
  Future<void> disconnect() async => _persist(false);

  Future<void> _persist(bool value) async {
    _hasPerms = value;
    _permsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Opens the platform health app so the user can review permissions.
  /// iOS: opens the Health app. Android: opens Health Connect settings.
  Future<void> openHealthApp() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final uri = Uri.parse('x-apple-health://');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else {
        // Open Health Connect app on Android
        final uri = Uri.parse(
            'intent://com.google.android.apps.healthdata#Intent;scheme=https;package=com.google.android.apps.healthdata;end');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          // Fallback: open Play Store page for Health Connect
          await launchUrl(
            Uri.parse(
                'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      debugPrint('HealthService: openHealthApp error — $e');
    }
  }

  // ── WRITE ──────────────────────────────────────────────────────────────────

  /// Pushes a FitDays body-fat scale reading to Apple Health / Health Connect.
  Future<void> syncScaleReading(WeightMeasurement m) async {
    if (!await _ensurePermsLoaded()) return;
    final now = DateTime.now();
    await _safeWrite(m.weight, HealthDataType.WEIGHT, now, HealthDataUnit.KILOGRAM);
    if (m.bodyFat != null) {
      await _safeWrite(m.bodyFat!, HealthDataType.BODY_FAT_PERCENTAGE, now, HealthDataUnit.PERCENT);
    }
    if (m.bmi != null) {
      await _safeWrite(m.bmi!, HealthDataType.BODY_MASS_INDEX, now, HealthDataUnit.NO_UNIT);
    }
    await _updateLastSync();
  }

  /// Pushes a logged meal's nutrition to Apple Health / Health Connect.
  Future<void> syncMealEntry(MealEntry entry) async {
    if (!await _ensurePermsLoaded()) return;
    final now = DateTime.now();
    await _safeWrite(entry.nutrition.calories, HealthDataType.DIETARY_ENERGY_CONSUMED, now, HealthDataUnit.KILOCALORIE);
    await _safeWrite(entry.nutrition.protein,  HealthDataType.DIETARY_PROTEIN_CONSUMED, now, HealthDataUnit.GRAM);
    await _safeWrite(entry.nutrition.carbs,    HealthDataType.DIETARY_CARBS_CONSUMED,   now, HealthDataUnit.GRAM);
    await _safeWrite(entry.nutrition.fat,      HealthDataType.DIETARY_FATS_CONSUMED,    now, HealthDataUnit.GRAM);
    if (entry.nutrition.fiber > 0) {
      await _safeWrite(entry.nutrition.fiber, HealthDataType.DIETARY_FIBER, now, HealthDataUnit.GRAM);
    }
    if ((entry.nutrition.sodium ?? 0) > 0) {
      await _safeWrite(entry.nutrition.sodium!, HealthDataType.DIETARY_SODIUM, now, HealthDataUnit.GRAM);
    }
    await _updateLastSync();
  }

  Future<void> _safeWrite(
      double value, HealthDataType type, DateTime time, HealthDataUnit unit) async {
    try {
      await _health.writeHealthData(
        value: value,
        type: type,
        startTime: time,
        endTime: time,
        unit: unit,
      );
    } catch (e) {
      debugPrint('HealthService write $type error: $e');
    }
  }

  // ── READ ───────────────────────────────────────────────────────────────────

  /// Today's total step count. Returns 0 on error or no permission.
  Future<int> fetchTodaySteps({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return 0;
    try {
      final d        = date ?? DateTime.now();
      final midnight = DateTime(d.year, d.month, d.day);
      final end      = date != null ? midnight.add(const Duration(days: 1)) : DateTime.now();
      return await _health.getTotalStepsInInterval(midnight, end) ?? 0;
    } catch (e) {
      debugPrint('HealthService fetchTodaySteps error: $e');
      return 0;
    }
  }

  /// Active calories burned for a given date (defaults to today).
  Future<double> fetchTodayActiveCalories({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return 0;
    try {
      final d        = date ?? DateTime.now();
      final midnight = DateTime(d.year, d.month, d.day);
      final end      = date != null ? midnight.add(const Duration(days: 1)) : DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime:   end,
        types:     [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double total = 0.0;
      for (final p in data) {
        total += (p.value as NumericHealthValue).numericValue.toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('HealthService fetchTodayActiveCalories error: $e');
      return 0;
    }
  }

  /// Weight readings in a date range — used to fill the trend chart.
  Future<List<Map<String, dynamic>>> fetchWeightHistory(DateTime from) async {
    if (!await _ensurePermsLoaded()) return [];
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime:   DateTime.now(),
        types:     [HealthDataType.WEIGHT],
      );
      return data.map((d) => {
        'weight':    (d.value as NumericHealthValue).numericValue.toDouble(),
        'timestamp': d.dateFrom,
      }).toList();
    } catch (e) {
      debugPrint('HealthService fetchWeightHistory error: $e');
      return [];
    }
  }

  /// Most recent resting heart rate reading (7 days ending on [date]). Null if no data.
  Future<double?> fetchRestingHeartRate({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return null;
    try {
      final end     = date != null
          ? DateTime(date.year, date.month, date.day).add(const Duration(days: 1))
          : DateTime.now();
      final weekAgo = end.subtract(const Duration(days: 7));
      final data = await _health.getHealthDataFromTypes(
        startTime: weekAgo, endTime: end,
        types: [HealthDataType.RESTING_HEART_RATE],
      );
      if (data.isEmpty) return null;
      data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      return (data.first.value as NumericHealthValue).numericValue.toDouble();
    } catch (e) {
      debugPrint('fetchRestingHeartRate error: $e');
      return null;
    }
  }

  /// HRV (SDNN) daily average for 7 days ending on [date].
  Future<List<double?>> fetchHRV7Days({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return List.filled(7, null);
    final anchor  = date ?? DateTime.now();
    final results = <double?>[];
    for (int i = 6; i >= 0; i--) {
      final day   = anchor.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end   = start.add(const Duration(days: 1));
      final cap   = date == null ? DateTime.now() : end;
      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: start,
          endTime:   end.isBefore(cap) ? end : cap,
          types:     [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        );
        if (data.isEmpty) { results.add(null); continue; }
        final avg = data
            .map((d) => (d.value as NumericHealthValue).numericValue.toDouble())
            .reduce((a, b) => a + b) / data.length;
        results.add(avg);
      } catch (_) { results.add(null); }
    }
    return results;
  }

  /// Sleep stage breakdown for the night of [date] (defaults to last night).
  Future<Map<String, double>> fetchSleepStagesLastNight({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return {};
    final anchor    = date ?? DateTime.now();
    final dayStart  = DateTime(anchor.year, anchor.month, anchor.day);
    final nightStart = dayStart.subtract(const Duration(hours: 8));
    final nightEnd   = dayStart.add(const Duration(hours: 14));
    final result    = <String, double>{};
    final stageMap  = {
      'rem':   HealthDataType.SLEEP_REM,
      'deep':  HealthDataType.SLEEP_DEEP,
      'light': HealthDataType.SLEEP_LIGHT,
      'awake': HealthDataType.SLEEP_AWAKE,
    };
    for (final entry in stageMap.entries) {
      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: nightStart, endTime: nightEnd, types: [entry.value],
        );
        final mins = data.fold(
            0, (s, d) => s + d.dateTo.difference(d.dateFrom).inMinutes);
        if (mins > 0) result[entry.key] = mins.toDouble();
      } catch (_) {}
    }
    return result;
  }

  /// Step count for 7 days ending on [date] (index 0 = 6 days ago, index 6 = selected day).
  Future<List<int>> fetchWeeklySteps({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return List.filled(7, 0);
    final anchor  = date ?? DateTime.now();
    final results = <int>[];
    for (int i = 6; i >= 0; i--) {
      final day   = anchor.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end   = start.add(const Duration(days: 1));
      final cap   = date == null ? DateTime.now() : end;
      try {
        final s = await _health.getTotalStepsInInterval(
            start, end.isBefore(cap) ? end : cap) ?? 0;
        results.add(s);
      } catch (_) { results.add(0); }
    }
    return results;
  }

  /// Walking + running distance for [date] in kilometres.
  Future<double?> fetchTodayDistance({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return null;
    try {
      final d        = date ?? DateTime.now();
      final midnight = DateTime(d.year, d.month, d.day);
      final end      = date != null ? midnight.add(const Duration(days: 1)) : DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight, endTime: end,
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
      );
      if (data.isEmpty) return null;
      double total = 0;
      for (final p in data) {
        total += (p.value as NumericHealthValue).numericValue.toDouble();
      }
      return total / 1000;
    } catch (e) {
      debugPrint('fetchTodayDistance error: $e');
      return null;
    }
  }

  /// Total workout minutes for [date].
  Future<int?> fetchTodayWorkoutMinutes({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return null;
    try {
      final d        = date ?? DateTime.now();
      final midnight = DateTime(d.year, d.month, d.day);
      final end      = date != null ? midnight.add(const Duration(days: 1)) : DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight, endTime: end,
        types: [HealthDataType.WORKOUT],
      );
      if (data.isEmpty) return null;
      final total = data.fold(
          0, (s, d) => s + d.dateTo.difference(d.dateFrom).inMinutes);
      return total;
    } catch (e) {
      debugPrint('fetchTodayWorkoutMinutes error: $e');
      return null;
    }
  }

  /// Sleep duration for the night of [date] (defaults to last night).
  Future<Duration> fetchSleepLastNight({DateTime? date}) async {
    if (!await _ensurePermsLoaded()) return Duration.zero;
    try {
      final anchor     = date ?? DateTime.now();
      final dayStart   = DateTime(anchor.year, anchor.month, anchor.day);
      final nightStart = dayStart.subtract(const Duration(hours: 8));
      final nightEnd   = dayStart.add(const Duration(hours: 14));
      final data = await _health.getHealthDataFromTypes(
        startTime: nightStart,
        endTime:   nightEnd,
        types:     [HealthDataType.SLEEP_ASLEEP],
      );
      final minutes = data.fold(
          0, (sum, d) => sum + d.dateTo.difference(d.dateFrom).inMinutes);
      return Duration(minutes: minutes);
    } catch (e) {
      debugPrint('HealthService fetchSleepLastNight error: $e');
      return Duration.zero;
    }
  }
}
