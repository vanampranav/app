import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_models.dart';
import '../models/today_context.dart';
import 'firebase_rest_service.dart';
import 'health_service.dart';

class AskEleContextService {
  final HealthService _healthService = HealthService();

  /// Assembles a fresh, up-to-date TodayContext from current SharedPreferences,
  /// HealthService, and active plan data.
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

    // PART A: Optional Targets — return null if user has not configured targets
    final int? calorieTarget = prefs.containsKey('cal_goal')
        ? prefs.getInt('cal_goal')
        : (prefs.containsKey('user_daily_calories')
            ? prefs.getInt('user_daily_calories')
            : null);
    final int? proteinTarget =
        prefs.containsKey('protein_goal') ? prefs.getInt('protein_goal') : null;
    final int? carbTarget =
        prefs.containsKey('carbs_goal') ? prefs.getInt('carbs_goal') : null;
    final int? fatTarget =
        prefs.containsKey('fat_goal') ? prefs.getInt('fat_goal') : null;

    // Consumed
    final caloriesConsumed = prefs.getInt('cal_consumed_$todayKey') ?? 0;
    final proteinConsumed = prefs.getInt('protein_$todayKey') ?? 0;
    final carbsConsumed = prefs.getInt('carbs_$todayKey') ?? 0;
    final fatConsumed = prefs.getInt('fat_$todayKey') ?? 0;

    // Remaining (calculated ONLY if target exists)
    final int? caloriesRemaining =
        calorieTarget != null ? calorieTarget - caloriesConsumed : null;
    final int? proteinRemaining =
        proteinTarget != null ? proteinTarget - proteinConsumed : null;
    final int? carbsRemaining =
        carbTarget != null ? carbTarget - carbsConsumed : null;
    final int? fatRemaining =
        fatTarget != null ? fatTarget - fatConsumed : null;

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

    // PARTS D & E & F: Active Plan Context Mapping
    ActivePlanContext? activePlanContext;
    try {
      final fbService = FirebaseRestService();
      await fbService.init();
      final plan = await fbService.getActivePlan();
      if (plan != null) {
        final startDate = plan.effectiveStartDate;
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final startMidnight =
            DateTime(startDate.year, startDate.month, startDate.day);
        final daysDiff = todayMidnight.difference(startMidnight).inDays;

        // PART D: Applicable ONLY if 0 <= daysDiff <= 6 (no modulo 7)
        if (daysDiff >= 0 && daysDiff <= 6) {
          final dayIndex = daysDiff;
          final dayNumber = dayIndex + 1;

          // Map today's planned meals
          final List<PlannedMealSummary> plannedMeals = [];
          if (dayIndex < plan.weeklyMeals.length) {
            final dayMeals = plan.weeklyMeals[dayIndex];
            for (final entry in dayMeals.mealsByTime.entries) {
              final mealType = entry.key;
              final items = entry.value;
              final itemDescriptions = items
                  .map((i) => i.quantity.isNotEmpty
                      ? '${i.name} (${i.quantity})'
                      : i.name)
                  .toList();
              final totalCals = items.fold(0, (sum, i) => sum + i.calories);
              if (itemDescriptions.isNotEmpty) {
                plannedMeals.add(
                  PlannedMealSummary(
                    mealType: mealType,
                    plannedItems: itemDescriptions,
                    totalCalories: totalCals,
                  ),
                );
              }
            }
          }

          // Map today's planned workout
          PlannedWorkoutSummary? plannedWorkout;
          if (dayIndex < plan.weeklyWorkouts.length) {
            final w = plan.weeklyWorkouts[dayIndex];
            plannedWorkout = PlannedWorkoutSummary(
              name: w.name,
              duration: w.duration,
              exercises: w.exercises,
              isRestDay: w.isRestDay,
            );
          }

          activePlanContext = ActivePlanContext(
            planId: plan.id,
            planName: plan.name.isNotEmpty ? plan.name : 'Fitness Plan',
            goal: plan.goal,
            startDate:
                '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
            dayNumber: dayNumber,
            plannedMeals: plannedMeals,
            plannedWorkout: plannedWorkout,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading active plan for TodayContext: $e');
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
      activePlan: activePlanContext,
    );
  }
}
