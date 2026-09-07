class LoggedMealSummary {
  final String foodName;
  final double weightGrams;
  final int calories;
  final int proteinGrams;
  final String mealType;

  LoggedMealSummary({
    required this.foodName,
    required this.weightGrams,
    required this.calories,
    required this.proteinGrams,
    required this.mealType,
  });

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'weightGrams': weightGrams,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'mealType': mealType,
      };

  factory LoggedMealSummary.fromJson(Map<String, dynamic> json) =>
      LoggedMealSummary(
        foodName: json['foodName'] ?? 'Food',
        weightGrams: (json['weightGrams'] ?? 0).toDouble(),
        calories: (json['calories'] ?? 0).toInt(),
        proteinGrams: (json['proteinGrams'] ?? 0).toInt(),
        mealType: json['mealType'] ?? 'snack',
      );
}

class PlannedMealSummary {
  final String mealType;
  final List<String> plannedItems;
  final int totalCalories;

  PlannedMealSummary({
    required this.mealType,
    required this.plannedItems,
    required this.totalCalories,
  });

  Map<String, dynamic> toJson() => {
        'mealType': mealType,
        'plannedItems': plannedItems,
        'totalCalories': totalCalories,
      };

  factory PlannedMealSummary.fromJson(Map<String, dynamic> json) =>
      PlannedMealSummary(
        mealType: json['mealType'] ?? 'Snacks',
        plannedItems: (json['plannedItems'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        totalCalories: (json['totalCalories'] ?? 0).toInt(),
      );
}

class PlannedWorkoutSummary {
  final String name;
  final String duration;
  final List<String> exercises;
  final bool isRestDay;

  PlannedWorkoutSummary({
    required this.name,
    required this.duration,
    required this.exercises,
    required this.isRestDay,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'duration': duration,
        'exercises': exercises,
        'isRestDay': isRestDay,
      };

  factory PlannedWorkoutSummary.fromJson(Map<String, dynamic> json) =>
      PlannedWorkoutSummary(
        name: json['name'] ?? 'Rest Day',
        duration: json['duration'] ?? '0 mins',
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isRestDay: json['isRestDay'] ?? false,
      );
}

class ActivePlanContext {
  final String planId;
  final String planName;
  final String goal;
  final String startDate;
  final int dayNumber;
  final List<PlannedMealSummary> plannedMeals;
  final PlannedWorkoutSummary? plannedWorkout;

  ActivePlanContext({
    required this.planId,
    required this.planName,
    required this.goal,
    required this.startDate,
    required this.dayNumber,
    required this.plannedMeals,
    this.plannedWorkout,
  });

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'planName': planName,
        'goal': goal,
        'startDate': startDate,
        'dayNumber': dayNumber,
        'plannedMeals': plannedMeals.map((m) => m.toJson()).toList(),
        if (plannedWorkout != null) 'plannedWorkout': plannedWorkout!.toJson(),
      };

  factory ActivePlanContext.fromJson(Map<String, dynamic> json) =>
      ActivePlanContext(
        planId: json['planId'] ?? '',
        planName: json['planName'] ?? 'Fitness Plan',
        goal: json['goal'] ?? '',
        startDate: json['startDate'] ?? '',
        dayNumber: (json['dayNumber'] ?? 1).toInt(),
        plannedMeals: (json['plannedMeals'] as List<dynamic>?)
                ?.map((e) =>
                    PlannedMealSummary.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        plannedWorkout: json['plannedWorkout'] is Map<String, dynamic>
            ? PlannedWorkoutSummary.fromJson(
                Map<String, dynamic>.from(json['plannedWorkout'] as Map))
            : null,
      );
}

class TodayContext {
  final String firstName;

  final int? calorieTarget;
  final int? proteinTarget;
  final int? carbTarget;
  final int? fatTarget;

  final int caloriesConsumed;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;

  final int? caloriesRemaining;
  final int? proteinRemaining;
  final int? carbsRemaining;
  final int? fatRemaining;

  final int steps;

  final List<LoggedMealSummary> mealsLogged;
  final ActivePlanContext? activePlan;

  TodayContext({
    required this.firstName,
    this.calorieTarget,
    this.proteinTarget,
    this.carbTarget,
    this.fatTarget,
    required this.caloriesConsumed,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    this.caloriesRemaining,
    this.proteinRemaining,
    this.carbsRemaining,
    this.fatRemaining,
    required this.steps,
    required this.mealsLogged,
    this.activePlan,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        if (calorieTarget != null) 'calorieTarget': calorieTarget,
        if (proteinTarget != null) 'proteinTarget': proteinTarget,
        if (carbTarget != null) 'carbTarget': carbTarget,
        if (fatTarget != null) 'fatTarget': fatTarget,
        'caloriesConsumed': caloriesConsumed,
        'proteinConsumed': proteinConsumed,
        'carbsConsumed': carbsConsumed,
        'fatConsumed': fatConsumed,
        if (caloriesRemaining != null) 'caloriesRemaining': caloriesRemaining,
        if (proteinRemaining != null) 'proteinRemaining': proteinRemaining,
        if (carbsRemaining != null) 'carbsRemaining': carbsRemaining,
        if (fatRemaining != null) 'fatRemaining': fatRemaining,
        'steps': steps,
        'mealsLogged': mealsLogged.map((m) => m.toJson()).toList(),
        if (activePlan != null) 'activePlan': activePlan!.toJson(),
      };
}
