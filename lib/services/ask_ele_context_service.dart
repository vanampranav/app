import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_models.dart';
import '../models/today_context.dart';
import 'health_service.dart';

class AskEleContextService {
  final HealthService _healthService = HealthService();

  /// Assembles a fresh, up-to-date TodayContext from current SharedPreferences
  /// and HealthService data matching Home & Today's Summary sources.
  Future<TodayContext> getTodayContext() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final todayKey = '${now.year}_${now.month}_${now.day}';
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // First Name
    String rawName = prefs.getString('user_name') ?? '';
    if (rawName.trim().isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      rawName = user?.displayName ?? '';
    }
    final firstName = rawName.trim().isNotEmpty
        ? rawName.trim().split(' ').first
        : 'Friend';

    // Targets
    final calorieTarget = prefs.getInt('cal_goal') ??
        prefs.getInt('user_daily_calories') ??
        2000;
    final proteinTarget = prefs.getInt('protein_goal') ?? 150;
    final carbTarget = prefs.getInt('carbs_goal') ?? 200;
    final fatTarget = prefs.getInt('fat_goal') ?? 65;

    // Consumed
    final caloriesConsumed = prefs.getInt('cal_consumed_$todayKey') ?? 0;
    final proteinConsumed = prefs.getInt('protein_$todayKey') ?? 0;
    final carbsConsumed = prefs.getInt('carbs_$todayKey') ?? 0;
    final fatConsumed = prefs.getInt('fat_$todayKey') ?? 0;

    // Remaining
    final caloriesRemaining = calorieTarget - caloriesConsumed;
    final proteinRemaining = proteinTarget - proteinConsumed;
    final carbsRemaining = carbTarget - carbsConsumed;
    final fatRemaining = fatTarget - fatConsumed;

    // Steps
    int steps = 0;
    try {
      steps = await _healthService.fetchTodaySteps();
    } catch (e) {
      debugPrint('Error fetching steps for TodayContext: $e');
    }

    // Today's Logged Meals
    final List<LoggedMealSummary> mealsLogged = [];
    try {
      final rawJson = prefs.getString('meal_entries_$dateKey');
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawJson);
        for (final item in list) {
          final entry =
              MealEntry.fromJson(Map<String, dynamic>.from(item as Map));
          mealsLogged.add(
            LoggedMealSummary(
              foodName: entry.foodName,
              weightGrams: entry.weight,
              calories: entry.nutrition.calories?.round() ?? 0,
              proteinGrams: entry.nutrition.protein?.round() ?? 0,
              mealType: entry.meal.toString().split('.').last,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error reading today meals for TodayContext: $e');
    }

    return TodayContext(
      firstName: firstName,
      calorieTarget: calorieTarget,
      proteinTarget: proteinTarget,
      carbTarget: carbTarget,
      fatTarget: fatTarget,
      caloriesConsumed: caloriesConsumed,
      proteinConsumed: proteinConsumed,
      carbsConsumed: carbsConsumed,
      fatConsumed: fatConsumed,
      caloriesRemaining: caloriesRemaining,
      proteinRemaining: proteinRemaining,
      carbsRemaining: carbsRemaining,
      fatRemaining: fatRemaining,
      steps: steps,
      mealsLogged: mealsLogged,
    );
  }
}
