import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_coach_models.dart';
import 'package:flutter/foundation.dart';
import 'ai_coach_parser.dart';

class AiCoachTarget {
  final int tdee;
  final int dailyCalories;
  final Map<String, int> macros;
  final String? workoutFocus;
  final bool capped;
  final String? personalizedInsight;

  AiCoachTarget({
    required this.tdee,
    required this.dailyCalories,
    required this.macros,
    this.workoutFocus,
    this.capped = false,
    this.personalizedInsight,
  });
}

class AiCoachService {
  static const String _baseUrl = 'https://yantraprise.com';

  /// Step 1: Call /user endpoint to get calorie targets + macros
  /// Matches the Next.js calories page fetchInitialTargets()
  Future<AiCoachTarget> getUserTargets(AiCoachProfile profile, AiCoachPreferences preferences) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'elefit_flutter_secure_key_2025', // Matches backend EC2 config
        },
        body: jsonEncode({
          'userDetails': {
            'age': profile.age.toString(),
            'weight': profile.currentWeight.toString(),
            'height': profile.height.toString(),
            'gender': profile.gender,
            'activityLevel': preferences.activityLevel,
            'healthGoals': profile.name, // goal text
            'targetWeight': profile.targetWeight.toString(),
            'timelineWeeks': profile.timelineWeeks,
          },
          'prompt': profile.name, // goal prompt
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to calculate targets: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return AiCoachTarget(
        tdee: data['tdee'] ?? 0,
        dailyCalories: data['targetCalories'] ?? 2000,
        macros: {
          'protein': data['macros']?['protein_g'] ?? 0,
          'carbs': data['macros']?['carbs_g'] ?? 0,
          'fat': data['macros']?['fat_g'] ?? 0,
        },
        workoutFocus: data['WorkoutFocus'],
        capped: data['capped'] == true,
        personalizedInsight: data['personalizedInsight'],
      );
    } catch (e) {
      // Fallback to local Harris-Benedict calculation if backend is unavailable
      return _localFallbackTargets(profile, preferences);
    }
  }

  /// Step 2: Generate full 7-day plan by calling /mealplan and /workoutplan
  /// Matches the Next.js calories page handleContinue()
  Future<FitnessPlan> generateFullPlan({
    required AiCoachTarget target,
    required AiCoachProfile profile,
    required AiCoachPreferences preferences,
    required String goal,
  }) async {
    List<DayMeals> weeklyMeals = [];
    List<DayWorkout> weeklyWorkouts = [];

    // 1. Generate Meal Plan (if needed)
    if (preferences.helpType == 'meal' || preferences.helpType == 'both') {
      try {
        final mealText = await _streamEndpoint('$_baseUrl/mealplan', {
          'targetCalories': target.dailyCalories,
          'dietaryRestrictions': preferences.dietaryPreferences,
          'healthGoals': goal,
          'prompt': goal,
          'targetWeight': profile.targetWeight,
          'timelineWeeks': profile.timelineWeeks,
          'weight': profile.currentWeight,
          'capped': target.capped,
        });
        weeklyMeals = AiCoachParser.parseMealPlan(mealText);
        // Verify parser produced unique days; if not, use varied fallback
        if (weeklyMeals.every((d) => d.mealsByTime.isEmpty)) {
          debugPrint('[AI Coach] Parser returned empty days, falling back to templates');
          weeklyMeals = _fallbackMeals(target.dailyCalories);
        }
      } catch (e) {
        debugPrint('[AI Coach] Meal plan API failed: $e');
        weeklyMeals = _fallbackMeals(target.dailyCalories);
      }
    } else {
      weeklyMeals = List.generate(7, (_) => DayMeals(mealsByTime: {}));
    }

    // 2. Generate Workout Plan (if needed)
    if (preferences.helpType == 'workout' || preferences.helpType == 'both') {
      try {
        final workoutText = await _streamEndpoint('$_baseUrl/workoutplan', {
          'goal': goal,
          'workoutFocus': target.workoutFocus ?? 'Mixed',
          'days': preferences.workoutDays,
          'targetWeight': profile.targetWeight,
          'timelineWeeks': profile.timelineWeeks,
          'prompt': goal,
        });
        weeklyWorkouts = AiCoachParser.parseWorkoutPlan(workoutText);
        if (weeklyWorkouts.every((d) => d.isRestDay)) {
          debugPrint('[AI Coach] Parser returned all rest days, falling back to templates');
          weeklyWorkouts = _fallbackWorkouts(preferences.workoutDays);
        }
      } catch (e) {
        debugPrint('[AI Coach] Workout plan API failed: $e');
        weeklyWorkouts = _fallbackWorkouts(preferences.workoutDays);
      }
    } else {
      weeklyWorkouts = List.generate(7, (_) => DayWorkout(name: 'Rest Day', isRestDay: true));
    }

    return FitnessPlan(
      dailyCalories: target.dailyCalories,
      macros: target.macros,
      goal: goal,
      workoutFocus: target.workoutFocus ?? 'MIXED CARDIO AND STRENGTH',
      generatedDate: DateTime.now(),
      weeklyMeals: weeklyMeals,
      weeklyWorkouts: weeklyWorkouts,
    );
  }

  /// Read a streaming endpoint and collect all text
  Future<String> _streamEndpoint(String url, Map<String, dynamic> body) async {
    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-API-Key'] = 'elefit_flutter_secure_key_2025'; // Matches backend EC2 config
    request.body = jsonEncode(body);

    debugPrint('[AI Coach] POST $url');
    final streamedResponse = await http.Client().send(request);
    debugPrint('[AI Coach] Response status: ${streamedResponse.statusCode}');

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      debugPrint('[AI Coach] Error body: $errorBody');
      throw Exception('API error ${streamedResponse.statusCode}: $errorBody');
    }

    final fullText = await streamedResponse.stream.bytesToString();
    debugPrint('[AI Coach] Response length: ${fullText.length} chars, preview: ${fullText.substring(0, fullText.length > 200 ? 200 : fullText.length)}');
    return fullText;
  }

  // --- Fallback calculations (used when backend is unreachable) ---

  AiCoachTarget _localFallbackTargets(AiCoachProfile profile, AiCoachPreferences preferences) {
    double bmr;
    if (profile.gender == 'male') {
      bmr = 88.362 + (13.397 * profile.currentWeight) + (4.799 * profile.height) - (5.677 * profile.age);
    } else if (profile.gender == 'female') {
      bmr = 447.593 + (9.247 * profile.currentWeight) + (3.098 * profile.height) - (4.33 * profile.age);
    } else {
      double mBmr = 88.362 + (13.397 * profile.currentWeight) + (4.799 * profile.height) - (5.677 * profile.age);
      double fBmr = 447.593 + (9.247 * profile.currentWeight) + (3.098 * profile.height) - (4.33 * profile.age);
      bmr = (mBmr + fBmr) / 2;
    }

    Map<String, double> activityMultipliers = {
      'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725, 'extra': 1.9,
    };
    double multiplier = activityMultipliers[preferences.activityLevel] ?? 1.55;
    int tdee = (bmr * multiplier).round();

    double weightDiff = (profile.currentWeight - profile.targetWeight).abs();
    double weeklyChange = profile.timelineWeeks > 0 ? weightDiff / profile.timelineWeeks : 0;
    double calorieAdjustment = weeklyChange * 500;

    int adjustedCalories;
    if (profile.currentWeight > profile.targetWeight) {
      adjustedCalories = (tdee - calorieAdjustment).round();
    } else {
      adjustedCalories = (tdee + calorieAdjustment).round();
    }

    return AiCoachTarget(
      tdee: tdee,
      dailyCalories: adjustedCalories,
      macros: {
        'protein': ((adjustedCalories * 0.3) / 4).round(),
        'carbs': ((adjustedCalories * 0.4) / 4).round(),
        'fat': ((adjustedCalories * 0.3) / 9).round(),
      },
    );
  }

  /// 7 unique daily meal fallback templates (used when backend is unreachable)
  List<DayMeals> _fallbackMeals(int cal) {
    final b = (cal * 0.25).round(), l = (cal * 0.35).round(), s = (cal * 0.10).round(), d = (cal * 0.30).round();

    return [
      // Day 1
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Oatmeal Bowl', quantity: '50g oats + berries', calories: (b * 0.4).round(), macro: 'P: 8g • C: 35g • F: 5g'),
          MealItem(name: 'Greek Yogurt', quantity: '150g', calories: (b * 0.3).round(), macro: 'P: 15g • C: 6g • F: 3g'),
          MealItem(name: 'Honey Drizzle', quantity: '1 tbsp', calories: (b * 0.3).round(), macro: 'P: 0g • C: 17g • F: 0g'),
        ],
        'Lunch': [
          MealItem(name: 'Grilled Chicken Breast', quantity: '150g', calories: (l * 0.4).round(), macro: 'P: 35g • C: 0g • F: 4g'),
          MealItem(name: 'Brown Rice', quantity: '100g', calories: (l * 0.3).round(), macro: 'P: 3g • C: 25g • F: 1g'),
          MealItem(name: 'Mixed Salad', quantity: '1 bowl', calories: (l * 0.3).round(), macro: 'P: 2g • C: 5g • F: 14g'),
        ],
        'Snacks': [
          MealItem(name: 'Almonds', quantity: '30g', calories: (s * 0.5).round(), macro: 'P: 6g • C: 3g • F: 14g'),
          MealItem(name: 'Banana', quantity: '1 medium', calories: (s * 0.5).round(), macro: 'P: 1g • C: 27g • F: 0g'),
        ],
        'Dinner': [
          MealItem(name: 'Baked Salmon', quantity: '150g', calories: (d * 0.4).round(), macro: 'P: 30g • C: 0g • F: 12g'),
          MealItem(name: 'Sweet Potato Mash', quantity: '150g', calories: (d * 0.3).round(), macro: 'P: 2g • C: 30g • F: 0g'),
          MealItem(name: 'Sautéed Spinach', quantity: '100g', calories: (d * 0.3).round(), macro: 'P: 3g • C: 4g • F: 3g'),
        ],
      }),
      // Day 2
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Scrambled Eggs', quantity: '3 eggs', calories: (b * 0.4).round(), macro: 'P: 18g • C: 2g • F: 15g'),
          MealItem(name: 'Whole Wheat Toast', quantity: '2 slices', calories: (b * 0.3).round(), macro: 'P: 6g • C: 24g • F: 2g'),
          MealItem(name: 'Avocado Slices', quantity: '½ avocado', calories: (b * 0.3).round(), macro: 'P: 1g • C: 4g • F: 12g'),
        ],
        'Lunch': [
          MealItem(name: 'Turkey Wrap', quantity: '1 large wrap', calories: (l * 0.4).round(), macro: 'P: 28g • C: 30g • F: 8g'),
          MealItem(name: 'Hummus & Veggies', quantity: '2 tbsp + sticks', calories: (l * 0.3).round(), macro: 'P: 3g • C: 6g • F: 5g'),
          MealItem(name: 'Fresh Orange Juice', quantity: '200ml', calories: (l * 0.3).round(), macro: 'P: 1g • C: 22g • F: 0g'),
        ],
        'Snacks': [
          MealItem(name: 'Protein Bar', quantity: '1 bar', calories: (s * 0.6).round(), macro: 'P: 20g • C: 18g • F: 6g'),
          MealItem(name: 'Apple', quantity: '1 medium', calories: (s * 0.4).round(), macro: 'P: 0g • C: 25g • F: 0g'),
        ],
        'Dinner': [
          MealItem(name: 'Chicken Stir Fry', quantity: '200g', calories: (d * 0.4).round(), macro: 'P: 30g • C: 15g • F: 10g'),
          MealItem(name: 'Jasmine Rice', quantity: '100g', calories: (d * 0.3).round(), macro: 'P: 4g • C: 45g • F: 0g'),
          MealItem(name: 'Miso Soup', quantity: '1 bowl', calories: (d * 0.3).round(), macro: 'P: 3g • C: 5g • F: 1g'),
        ],
      }),
      // Day 3
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Smoothie Bowl', quantity: 'Banana + mango', calories: (b * 0.5).round(), macro: 'P: 5g • C: 40g • F: 3g'),
          MealItem(name: 'Granola', quantity: '30g', calories: (b * 0.25).round(), macro: 'P: 4g • C: 20g • F: 6g'),
          MealItem(name: 'Chia Seeds', quantity: '1 tbsp', calories: (b * 0.25).round(), macro: 'P: 2g • C: 6g • F: 4g'),
        ],
        'Lunch': [
          MealItem(name: 'Paneer Tikka', quantity: '150g grilled', calories: (l * 0.35).round(), macro: 'P: 25g • C: 8g • F: 18g'),
          MealItem(name: 'Toor Dal', quantity: '1 bowl', calories: (l * 0.3).round(), macro: 'P: 10g • C: 20g • F: 2g'),
          MealItem(name: 'Roti', quantity: '2 pieces', calories: (l * 0.35).round(), macro: 'P: 6g • C: 30g • F: 2g'),
        ],
        'Snacks': [
          MealItem(name: 'Apple & Peanut Butter', quantity: '1 apple + 1 tbsp', calories: s, macro: 'P: 4g • C: 30g • F: 8g'),
        ],
        'Dinner': [
          MealItem(name: 'Grilled Fish', quantity: '150g', calories: (d * 0.4).round(), macro: 'P: 32g • C: 0g • F: 4g'),
          MealItem(name: 'Quinoa Salad', quantity: '100g', calories: (d * 0.35).round(), macro: 'P: 5g • C: 22g • F: 2g'),
          MealItem(name: 'Grilled Zucchini', quantity: '100g', calories: (d * 0.25).round(), macro: 'P: 1g • C: 3g • F: 3g'),
        ],
      }),
      // Day 4
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Poha', quantity: '1 plate with peanuts', calories: (b * 0.5).round(), macro: 'P: 5g • C: 40g • F: 8g'),
          MealItem(name: 'Masala Chai', quantity: '1 cup', calories: (b * 0.2).round(), macro: 'P: 2g • C: 10g • F: 2g'),
          MealItem(name: 'Papaya', quantity: '1 serving', calories: (b * 0.3).round(), macro: 'P: 1g • C: 20g • F: 0g'),
        ],
        'Lunch': [
          MealItem(name: 'Chicken Biryani', quantity: '1 plate', calories: (l * 0.5).round(), macro: 'P: 28g • C: 50g • F: 12g'),
          MealItem(name: 'Raita', quantity: '1 bowl', calories: (l * 0.2).round(), macro: 'P: 5g • C: 8g • F: 4g'),
          MealItem(name: 'Buttermilk', quantity: '1 glass', calories: (l * 0.3).round(), macro: 'P: 4g • C: 6g • F: 2g'),
        ],
        'Snacks': [
          MealItem(name: 'Mixed Nuts & Seeds', quantity: '30g', calories: (s * 0.55).round(), macro: 'P: 5g • C: 8g • F: 14g'),
          MealItem(name: 'Dates', quantity: '3 pieces', calories: (s * 0.45).round(), macro: 'P: 1g • C: 18g • F: 0g'),
        ],
        'Dinner': [
          MealItem(name: 'Egg Curry', quantity: '3 eggs in gravy', calories: (d * 0.4).round(), macro: 'P: 20g • C: 8g • F: 15g'),
          MealItem(name: 'Jeera Rice', quantity: '100g', calories: (d * 0.3).round(), macro: 'P: 3g • C: 30g • F: 2g'),
          MealItem(name: 'Chapati', quantity: '2 pieces', calories: (d * 0.3).round(), macro: 'P: 4g • C: 22g • F: 2g'),
        ],
      }),
      // Day 5
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Idli', quantity: '4 pieces', calories: (b * 0.4).round(), macro: 'P: 6g • C: 32g • F: 1g'),
          MealItem(name: 'Sambar', quantity: '1 bowl', calories: (b * 0.3).round(), macro: 'P: 5g • C: 15g • F: 2g'),
          MealItem(name: 'Coconut Chutney', quantity: '2 tbsp', calories: (b * 0.3).round(), macro: 'P: 1g • C: 4g • F: 6g'),
        ],
        'Lunch': [
          MealItem(name: 'Fish Curry', quantity: '150g', calories: (l * 0.35).round(), macro: 'P: 30g • C: 5g • F: 10g'),
          MealItem(name: 'Steamed Rice', quantity: '100g', calories: (l * 0.3).round(), macro: 'P: 3g • C: 28g • F: 0g'),
          MealItem(name: 'Bhindi Fry', quantity: '100g', calories: (l * 0.35).round(), macro: 'P: 2g • C: 8g • F: 5g'),
        ],
        'Snacks': [
          MealItem(name: 'Roasted Chana', quantity: '40g', calories: (s * 0.55).round(), macro: 'P: 8g • C: 20g • F: 3g'),
          MealItem(name: 'Coconut Water', quantity: '200ml', calories: (s * 0.45).round(), macro: 'P: 0g • C: 10g • F: 0g'),
        ],
        'Dinner': [
          MealItem(name: 'Tofu Stir-Fry', quantity: '200g', calories: (d * 0.35).round(), macro: 'P: 20g • C: 10g • F: 12g'),
          MealItem(name: 'Multigrain Roti', quantity: '2 pieces', calories: (d * 0.35).round(), macro: 'P: 6g • C: 30g • F: 3g'),
          MealItem(name: 'Palak Soup', quantity: '1 bowl', calories: (d * 0.3).round(), macro: 'P: 4g • C: 6g • F: 2g'),
        ],
      }),
      // Day 6
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Protein Pancakes', quantity: '3 pancakes', calories: (b * 0.5).round(), macro: 'P: 22g • C: 28g • F: 6g'),
          MealItem(name: 'Maple Syrup', quantity: '1 tbsp', calories: (b * 0.2).round(), macro: 'P: 0g • C: 13g • F: 0g'),
          MealItem(name: 'Fresh Strawberries', quantity: '1 cup', calories: (b * 0.3).round(), macro: 'P: 1g • C: 12g • F: 0g'),
        ],
        'Lunch': [
          MealItem(name: 'Rajma Curry', quantity: '1 bowl', calories: (l * 0.35).round(), macro: 'P: 12g • C: 30g • F: 3g'),
          MealItem(name: 'Steamed Rice', quantity: '100g', calories: (l * 0.3).round(), macro: 'P: 3g • C: 28g • F: 0g'),
          MealItem(name: 'Aloo Gobi', quantity: '100g', calories: (l * 0.35).round(), macro: 'P: 3g • C: 15g • F: 5g'),
        ],
        'Snacks': [
          MealItem(name: 'Fruit Salad', quantity: '1 bowl', calories: (s * 0.5).round(), macro: 'P: 2g • C: 25g • F: 0g'),
          MealItem(name: 'Dark Chocolate', quantity: '20g', calories: (s * 0.5).round(), macro: 'P: 2g • C: 8g • F: 8g'),
        ],
        'Dinner': [
          MealItem(name: 'Grilled Chicken Salad', quantity: '200g', calories: (d * 0.4).round(), macro: 'P: 32g • C: 8g • F: 10g'),
          MealItem(name: 'Garlic Bread', quantity: '2 slices', calories: (d * 0.3).round(), macro: 'P: 4g • C: 20g • F: 6g'),
          MealItem(name: 'Minestrone Soup', quantity: '1 bowl', calories: (d * 0.3).round(), macro: 'P: 5g • C: 15g • F: 3g'),
        ],
      }),
      // Day 7
      DayMeals(mealsByTime: {
        'Breakfast': [
          MealItem(name: 'Masala Dosa', quantity: '2 dosas', calories: (b * 0.45).round(), macro: 'P: 5g • C: 38g • F: 8g'),
          MealItem(name: 'Coconut Chutney', quantity: '2 tbsp', calories: (b * 0.25).round(), macro: 'P: 1g • C: 4g • F: 5g'),
          MealItem(name: 'Filter Coffee', quantity: '1 cup', calories: (b * 0.3).round(), macro: 'P: 1g • C: 6g • F: 2g'),
        ],
        'Lunch': [
          MealItem(name: 'Chole Bhature', quantity: '1 plate', calories: (l * 0.5).round(), macro: 'P: 14g • C: 50g • F: 15g'),
          MealItem(name: 'Lassi', quantity: '1 glass', calories: (l * 0.25).round(), macro: 'P: 5g • C: 15g • F: 3g'),
          MealItem(name: 'Green Salad', quantity: '1 bowl', calories: (l * 0.25).round(), macro: 'P: 1g • C: 5g • F: 0g'),
        ],
        'Snacks': [
          MealItem(name: 'Makhana', quantity: '30g roasted', calories: (s * 0.5).round(), macro: 'P: 5g • C: 20g • F: 1g'),
          MealItem(name: 'Herbal Tea', quantity: '1 cup with honey', calories: (s * 0.5).round(), macro: 'P: 0g • C: 10g • F: 0g'),
        ],
        'Dinner': [
          MealItem(name: 'Palak Paneer', quantity: '1 bowl', calories: (d * 0.35).round(), macro: 'P: 15g • C: 8g • F: 12g'),
          MealItem(name: 'Tandoori Roti', quantity: '2 pieces', calories: (d * 0.3).round(), macro: 'P: 5g • C: 28g • F: 2g'),
          MealItem(name: 'Dal Tadka', quantity: '1 bowl', calories: (d * 0.35).round(), macro: 'P: 8g • C: 15g • F: 4g'),
        ],
      }),
    ];
  }

  List<DayWorkout> _fallbackWorkouts(int days) {
    final workouts = [
      DayWorkout(name: 'Chest & Triceps', duration: '60 mins', exercises: ['Bench Press — 4×8', 'Incline Dumbbell Press — 3×10', 'Cable Flyes — 3×12', 'Tricep Dips — 3×8', 'Skull Crushers — 3×10']),
      DayWorkout(name: 'Back & Biceps', duration: '60 mins', exercises: ['Deadlifts — 4×6', 'Bent-over Rows — 4×8', 'Lat Pulldown — 3×10', 'Barbell Curls — 3×10', 'Hammer Curls — 3×12']),
      DayWorkout(name: 'Legs & Glutes', duration: '75 mins', exercises: ['Squats — 4×8', 'Leg Press — 3×10', 'Romanian Deadlifts — 3×10', 'Leg Curls — 3×10', 'Calf Raises — 4×15']),
      DayWorkout(name: 'Active Recovery', duration: '45 mins', exercises: ['Light Jog — 20 mins', 'Yoga Flow — 15 mins', 'Foam Rolling — 10 mins']),
      DayWorkout(name: 'Shoulders & Core', duration: '60 mins', exercises: ['Overhead Press — 4×8', 'Lateral Raises — 3×12', 'Front Raises — 3×12', 'Plank Hold — 3×60s', 'Russian Twists — 3×20']),
      DayWorkout(name: 'Full Body HIIT', duration: '45 mins', exercises: ['Burpees — 3×15', 'Kettlebell Swings — 4×12', 'Box Jumps — 3×10', 'Battle Ropes — 3×30s', 'Mountain Climbers — 3×20']),
      DayWorkout(name: 'Rest Day', duration: '0 mins', exercises: [], isRestDay: true),
    ];
    return List.generate(7, (i) => i < days ? workouts[i % workouts.length] : DayWorkout(name: 'Rest Day', duration: '0 mins', exercises: [], isRestDay: true));
  }
}
