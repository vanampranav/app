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

class TodayContext {
  final String firstName;

  final int calorieTarget;
  final int proteinTarget;
  final int carbTarget;
  final int fatTarget;

  final int caloriesConsumed;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;

  final int caloriesRemaining;
  final int proteinRemaining;
  final int carbsRemaining;
  final int fatRemaining;

  final int steps;

  final List<LoggedMealSummary> mealsLogged;

  TodayContext({
    required this.firstName,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbTarget,
    required this.fatTarget,
    required this.caloriesConsumed,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    required this.caloriesRemaining,
    required this.proteinRemaining,
    required this.carbsRemaining,
    required this.fatRemaining,
    required this.steps,
    required this.mealsLogged,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'calorieTarget': calorieTarget,
        'proteinTarget': proteinTarget,
        'carbTarget': carbTarget,
        'fatTarget': fatTarget,
        'caloriesConsumed': caloriesConsumed,
        'proteinConsumed': proteinConsumed,
        'carbsConsumed': carbsConsumed,
        'fatConsumed': fatConsumed,
        'caloriesRemaining': caloriesRemaining,
        'proteinRemaining': proteinRemaining,
        'carbsRemaining': carbsRemaining,
        'fatRemaining': fatRemaining,
        'steps': steps,
        'mealsLogged': mealsLogged.map((m) => m.toJson()).toList(),
      };
}
