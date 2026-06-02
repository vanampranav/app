import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../models/food_models.dart';

/// Singleton wrapper around the `health` package.
/// Handles Apple Health (iOS) and Google Health Connect (Android).
///
/// All methods degrade gracefully — they return 0 / empty / false when
/// permissions are denied or the platform doesn't support Health.
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _configured  = false;
  bool _hasPerms    = false;

  static const String _prefsKey = 'health_connected';

  // ── Data types ──────────────────────────────────────────────────────────────

  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
    HealthDataType.WATER,
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

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('HealthService configure error: $e');
    }
  }

  /// Returns true if the user previously granted permissions (cached in prefs).
  Future<bool> get isConnected async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Request health permissions from the user.
  ///
  /// Android: `requestAuthorization()` ALWAYS returns false — this is by Google's
  /// design. The only reliable signal is whether the call completes without
  /// throwing. If it completes → Health Connect launched → user went through
  /// the screen → we mark as connected. Individual reads degrade to 0 if the
  /// user denied specific types, which the app already handles gracefully.
  ///
  /// iOS: `requestAuthorization()` returns true when granted. We trust that.
  Future<bool> requestPermissions() async {
    await _configure();
    final types = [..._readTypes, ..._writeTypes];
    final perms  = [
      ...List.filled(_readTypes.length,  HealthDataAccess.READ),
      ...List.filled(_writeTypes.length, HealthDataAccess.WRITE),
    ];

    try {
      await _health.requestAuthorization(types, permissions: perms);
    } catch (e) {
      debugPrint('HealthService: requestAuthorization error — $e');
      await _persist(false);
      return false;
    }

    // After the permission screen closes, check whether Health Connect
    // actually registered the app. hasPermissions() returns:
    //   true  → user granted at least STEPS read (Play Store or dev device)
    //   false → app not registered in Health Connect (sideloaded restriction)
    //   null  → platform can't determine (treat as not connected)
    bool? verified;
    try {
      verified = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {}

    final connected = verified == true;
    await _persist(connected);
    return connected;
  }

  /// Check whether Health Connect still has us registered.
  Future<bool> checkPermissions() async {
    await _configure();
    bool? result;
    try {
      result = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {}
    _hasPerms = result == true;
    await _persist(_hasPerms);
    return _hasPerms;
  }

  Future<void> _persist(bool value) async {
    _hasPerms = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  /// Disconnect — clears cached permission state (does not revoke OS-level perms).
  Future<void> disconnect() async => _persist(false);

  // ── WRITE ───────────────────────────────────────────────────────────────────

  /// Push a FitDays body-fat scale reading to Apple Health / Health Connect.
  Future<void> syncScaleReading(WeightMeasurement m) async {
    if (!_hasPerms) return;
    final now = DateTime.now();
    await _safeWrite(m.weight,    HealthDataType.WEIGHT,              now, HealthDataUnit.KILOGRAM);
    if (m.bodyFat  != null) await _safeWrite(m.bodyFat!,  HealthDataType.BODY_FAT_PERCENTAGE, now, HealthDataUnit.PERCENT);
    if (m.bmi      != null) await _safeWrite(m.bmi!,      HealthDataType.BODY_MASS_INDEX,     now, HealthDataUnit.NO_UNIT);
  }

  /// Push a logged meal entry's nutrition to Apple Health / Health Connect.
  Future<void> syncMealEntry(MealEntry entry) async {
    if (!_hasPerms) return;
    final now = DateTime.now();
    await _safeWrite(entry.nutrition.calories, HealthDataType.DIETARY_ENERGY_CONSUMED,   now, HealthDataUnit.KILOCALORIE);
    await _safeWrite(entry.nutrition.protein,  HealthDataType.DIETARY_PROTEIN_CONSUMED,  now, HealthDataUnit.GRAM);
    await _safeWrite(entry.nutrition.carbs,    HealthDataType.DIETARY_CARBS_CONSUMED,    now, HealthDataUnit.GRAM);
    await _safeWrite(entry.nutrition.fat,      HealthDataType.DIETARY_FATS_CONSUMED,     now, HealthDataUnit.GRAM);
    if (entry.nutrition.fiber > 0)
      await _safeWrite(entry.nutrition.fiber,  HealthDataType.DIETARY_FIBER,             now, HealthDataUnit.GRAM);
    if ((entry.nutrition.sodium ?? 0) > 0)
      await _safeWrite(entry.nutrition.sodium!, HealthDataType.DIETARY_SODIUM,           now, HealthDataUnit.GRAM);
  }

  Future<void> _safeWrite(double value, HealthDataType type,
      DateTime time, HealthDataUnit unit) async {
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

  // ── READ ────────────────────────────────────────────────────────────────────

  /// Today's total step count. Returns 0 on error or no permission.
  Future<int> fetchTodaySteps() async {
    if (!_hasPerms) return 0;
    try {
      final now      = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      return await _health.getTotalStepsInInterval(midnight, now) ?? 0;
    } catch (e) {
      debugPrint('HealthService fetchTodaySteps error: $e');
      return 0;
    }
  }

  /// Today's total active calories burned. Returns 0.0 on error.
  Future<double> fetchTodayActiveCalories() async {
    if (!_hasPerms) return 0;
    try {
      final now      = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime:   now,
        types:     [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double total = 0.0;
      for (final d in data) {
        total += (d.value as NumericHealthValue).numericValue.toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('HealthService fetchTodayActiveCalories error: $e');
      return 0;
    }
  }

  /// Weight readings from [from] until now — used to fill the trend chart.
  Future<List<Map<String, dynamic>>> fetchWeightHistory(DateTime from) async {
    if (!_hasPerms) return [];
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime:   DateTime.now(),
        types:     [HealthDataType.WEIGHT],
      );
      return data
          .map((d) => {
                'weight':    (d.value as NumericHealthValue).numericValue.toDouble(),
                'timestamp': d.dateFrom,
              })
          .toList();
    } catch (e) {
      debugPrint('HealthService fetchWeightHistory error: $e');
      return [];
    }
  }

  /// Last night's sleep duration.
  Future<Duration> fetchSleepLastNight() async {
    if (!_hasPerms) return Duration.zero;
    try {
      final now       = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final data = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime:   now,
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
