import 'package:flutter/foundation.dart';

class AiCoachProfile {
  String name;
  int age;
  String gender;
  double currentWeight;
  double targetWeight;
  double height;
  int timelineWeeks;

  AiCoachProfile({
    this.name = '',
    this.age = 25,
    this.gender = 'male',
    this.currentWeight = 70.0,
    this.targetWeight = 65.0,
    this.height = 170.0,
    this.timelineWeeks = 4,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'height': height,
      'timelineWeeks': timelineWeeks,
    };
  }
}

class AiCoachPreferences {
  String helpType; // 'meal', 'workout', 'both'
  String activityLevel;
  int workoutDays;
  List<String> dietaryPreferences;

  AiCoachPreferences({
    this.helpType = 'both',
    this.activityLevel = 'moderate',
    this.workoutDays = 3,
    this.dietaryPreferences = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'helpType': helpType,
      'activityLevel': activityLevel,
      'workoutDays': workoutDays,
      'dietaryPreferences': dietaryPreferences,
    };
  }
}

/// A single meal item (e.g. "Oatmeal Bowl")
class MealItem {
  final String name;
  final String quantity;
  final int calories;
  final String macro;

  MealItem({
    required this.name,
    this.quantity = '1 serving',
    this.calories = 0,
    this.macro = 'Modified',
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? '1 serving',
      calories: json['calories'] ?? 0,
      macro: json['macro'] ?? 'Modified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'calories': calories,
      'macro': macro,
    };
  }
}

/// A day's meals grouped by meal time (Breakfast, Lunch, Snacks, Dinner)
class DayMeals {
  final Map<String, List<MealItem>> mealsByTime; // key = 'Breakfast', 'Lunch', 'Snacks', 'Dinner'

  DayMeals({required this.mealsByTime});

  List<MealItem> get breakfast => mealsByTime['Breakfast'] ?? [];
  List<MealItem> get lunch => mealsByTime['Lunch'] ?? [];
  List<MealItem> get snacks => mealsByTime['Snacks'] ?? [];
  List<MealItem> get dinner => mealsByTime['Dinner'] ?? [];

  Map<String, dynamic> toJson() {
    return {
      'mealsByTime': mealsByTime.map((key, value) => MapEntry(key, value.map((m) => m.toJson()).toList())),
    };
  }

  factory DayMeals.fromJson(Map<String, dynamic> json) {
    final map = json['mealsByTime'] as Map<String, dynamic>? ?? {};
    return DayMeals(
      mealsByTime: map.map((key, value) {
        return MapEntry(
          key,
          (value as List).map((m) => MealItem.fromJson(m as Map<String, dynamic>)).toList(),
        );
      }),
    );
  }
}

/// A day's workout
class DayWorkout {
  final String name;
  final String duration;
  final List<String> exercises;
  final bool isRestDay;

  DayWorkout({
    required this.name,
    this.duration = '0 mins',
    this.exercises = const [],
    this.isRestDay = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration': duration,
      'exercises': exercises,
      'isRestDay': isRestDay,
    };
  }

  factory DayWorkout.fromJson(Map<String, dynamic> json) {
    return DayWorkout(
      name: json['name'] ?? '',
      duration: json['duration'] ?? '0 mins',
      exercises: List<String>.from(json['exercises'] ?? []),
      isRestDay: json['isRestDay'] ?? false,
    );
  }
}

/// Summary of a saved plan — used in the "My Plans" list
class FitnessPlanSummary {
  final String id;
  final String name;
  final String goal;
  final int dailyCalories;
  final String workoutFocus;
  final DateTime generatedDate;

  FitnessPlanSummary({
    required this.id,
    required this.name,
    required this.goal,
    required this.dailyCalories,
    required this.workoutFocus,
    required this.generatedDate,
  });
}

/// The complete 7-day fitness plan, mirroring Next.js structure exactly
class FitnessPlan {
  final String id;           // Firestore document ID (empty for unsaved plans)
  final String name;         // Auto-generated plan name
  final int dailyCalories;
  final Map<String, int> macros;
  final String goal;
  final String workoutFocus;
  final DateTime generatedDate;
  final List<DayMeals> weeklyMeals;     // index 0-6 = Day 1-7
  final List<DayWorkout> weeklyWorkouts; // index 0-6 = Day 1-7

  FitnessPlan({
    this.id = '',
    this.name = '',
    required this.dailyCalories,
    required this.macros,
    this.goal = 'Get Fit',
    this.workoutFocus = 'MIXED CARDIO AND STRENGTH',
    DateTime? generatedDate,
    required this.weeklyMeals,
    required this.weeklyWorkouts,
  }) : generatedDate = generatedDate ?? DateTime.now();

  FitnessPlan copyWith({String? id, String? name}) {
    return FitnessPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyCalories: dailyCalories,
      macros: macros,
      goal: goal,
      workoutFocus: workoutFocus,
      generatedDate: generatedDate,
      weeklyMeals: weeklyMeals,
      weeklyWorkouts: weeklyWorkouts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dailyCalories': dailyCalories,
      'macros': macros,
      'goal': goal,
      'workoutFocus': workoutFocus,
      'generatedDate': generatedDate.toIso8601String(),
      'weeklyMeals': weeklyMeals.map((m) => m.toJson()).toList(),
      'weeklyWorkouts': weeklyWorkouts.map((w) => w.toJson()).toList(),
    };
  }

  factory FitnessPlan.fromJson(Map<String, dynamic> json) {
    return FitnessPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dailyCalories: (json['dailyCalories'] as num?)?.toInt() ?? 0,
      macros: (json['macros'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
      goal: json['goal']?.toString() ?? '',
      workoutFocus: json['workoutFocus']?.toString() ?? '',
      generatedDate: DateTime.tryParse(json['generatedDate']?.toString() ?? '') ?? DateTime.now(),
      weeklyMeals: (json['weeklyMeals'] as List?)?.map((m) => DayMeals.fromJson(m)).toList() ?? [],
      weeklyWorkouts: (json['weeklyWorkouts'] as List?)?.map((w) => DayWorkout.fromJson(w)).toList() ?? [],
    );
  }
}

// --- Legacy models kept for backward compat with OpenAI JSON parsing ---

class Meal {
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final String instructions;

  Meal({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    required this.instructions,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: json['instructions'] ?? '',
    );
  }
}

class Workout {
  final String day;
  final String name;
  final int duration;
  final List<Exercise> exercises;

  Workout({
    required this.day,
    required this.name,
    required this.duration,
    required this.exercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      day: json['day'] ?? '',
      name: json['name'] ?? '',
      duration: json['duration'] ?? 0,
      exercises: (json['exercises'] as List?)?.map((e) => Exercise.fromJson(e)).toList() ?? [],
    );
  }
}

class Exercise {
  final String name;
  final int sets;
  final int reps;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] ?? '',
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? 0,
    );
  }
}
