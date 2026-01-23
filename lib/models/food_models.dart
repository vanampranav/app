class FoodItem {
  final String fdcId;
  final String name;
  final String? imageUrl;
  final double caloriesPer100g;
  final String servingSize;

  FoodItem({
    required this.fdcId,
    required this.name,
    this.imageUrl,
    required this.caloriesPer100g,
    required this.servingSize,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      fdcId: json['fdcId'].toString(),
      name: json['description'] ?? json['name'] ?? 'Unknown Food',
      imageUrl: json['imageUrl'],
      caloriesPer100g: (json['caloriesPer100g'] ?? 0).toDouble(),
      servingSize: json['servingSize'] ?? '100g',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fdcId': fdcId,
      'name': name,
      'imageUrl': imageUrl,
      'caloriesPer100g': caloriesPer100g,
      'servingSize': servingSize,
    };
  }
}

class NutritionData {
  final double calories;
  final double fat;
  final double carbs;
  final double protein;
  final double fiber;
  final double sugar;
  
  // Vitamins
  final double? vitaminA;
  final double? vitaminB1;
  final double? vitaminB2;
  final double? vitaminC;
  final double? vitaminE;
  
  // Minerals
  final double? calcium;
  final double? iron;
  final double? magnesium;
  final double? potassium;
  final double? sodium;
  final double? zinc;
  
  // Other nutrients
  final double? cholesterol;
  final double? carotene;
  final double? retinol;

  NutritionData({
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    this.fiber = 0,
    this.sugar = 0,
    this.vitaminA,
    this.vitaminB1,
    this.vitaminB2,
    this.vitaminC,
    this.vitaminE,
    this.calcium,
    this.iron,
    this.magnesium,
    this.potassium,
    this.sodium,
    this.zinc,
    this.cholesterol,
    this.carotene,
    this.retinol,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    // Helper to extract amount from nested structure or direct value
    double extractAmount(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is Map) return (value['amount'] ?? 0).toDouble();
      return 0;
    }

    return NutritionData(
      calories: extractAmount(json['Calories'] ?? json['calories']),
      fat: extractAmount(json['Fat'] ?? json['fat']),
      carbs: extractAmount(json['Carbs'] ?? json['carbs']),
      protein: extractAmount(json['Protein'] ?? json['protein']),
      fiber: extractAmount(json['Dietary Fiber'] ?? json['fiber']),
      sugar: extractAmount(json['sugar']),
      vitaminA: json['vitaminA'] != null ? extractAmount(json['vitaminA']) : null,
      vitaminB1: json['vitaminB1'] != null ? extractAmount(json['vitaminB1']) : null,
      vitaminB2: json['vitaminB2'] != null ? extractAmount(json['vitaminB2']) : null,
      vitaminC: json['vitaminC'] != null ? extractAmount(json['vitaminC']) : null,
      vitaminE: json['vitaminE'] != null ? extractAmount(json['vitaminE']) : null,
      calcium: json['Ca'] != null ? extractAmount(json['Ca']) : (json['calcium'] != null ? extractAmount(json['calcium']) : null),
      iron: json['Fe'] != null ? extractAmount(json['Fe']) : (json['iron'] != null ? extractAmount(json['iron']) : null),
      magnesium: json['magnesium'] != null ? extractAmount(json['magnesium']) : null,
      potassium: json['potassium'] != null ? extractAmount(json['potassium']) : null,
      sodium: json['Na'] != null ? extractAmount(json['Na']) : (json['sodium'] != null ? extractAmount(json['sodium']) : null),
      zinc: json['zinc'] != null ? extractAmount(json['zinc']) : null,
      cholesterol: json['Cholesterol'] != null ? extractAmount(json['Cholesterol']) : (json['cholesterol'] != null ? extractAmount(json['cholesterol']) : null),
      carotene: json['carotene'] != null ? extractAmount(json['carotene']) : null,
      retinol: json['retinol'] != null ? extractAmount(json['retinol']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'fat': fat,
      'carbs': carbs,
      'protein': protein,
      'fiber': fiber,
      'sugar': sugar,
      'vitaminA': vitaminA,
      'vitaminB1': vitaminB1,
      'vitaminB2': vitaminB2,
      'vitaminC': vitaminC,
      'vitaminE': vitaminE,
      'calcium': calcium,
      'iron': iron,
      'magnesium': magnesium,
      'potassium': potassium,
      'sodium': sodium,
      'zinc': zinc,
      'cholesterol': cholesterol,
      'carotene': carotene,
      'retinol': retinol,
    };
  }
}

enum MealType { breakfast, lunch, dinner, snacks }

class MealEntry {
  final String id;
  final String foodName;
  final String fdcId;
  final double weight; // in grams
  final NutritionData nutrition;
  final MealType meal;
  final DateTime timestamp;
  final String? imageUrl;

  MealEntry({
    required this.id,
    required this.foodName,
    required this.fdcId,
    required this.weight,
    required this.nutrition,
    required this.meal,
    required this.timestamp,
    this.imageUrl,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'],
      foodName: json['foodName'],
      fdcId: json['fdcId'],
      weight: (json['weight'] ?? 0).toDouble(),
      nutrition: NutritionData.fromJson(json['nutrition']),
      meal: MealType.values.firstWhere(
        (e) => e.toString() == 'MealType.${json['meal']}',
        orElse: () => MealType.snacks,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodName': foodName,
      'fdcId': fdcId,
      'weight': weight,
      'nutrition': nutrition.toJson(),
      'meal': meal.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }
}

class DailySummary {
  final DateTime date;
  final List<MealEntry> entries;
  final double targetCalories;

  DailySummary({
    required this.date,
    required this.entries,
    this.targetCalories = 2067,
  });

  double get totalCalories => entries.fold(0, (sum, entry) => sum + entry.nutrition.calories);
  double get totalFat => entries.fold(0, (sum, entry) => sum + entry.nutrition.fat);
  double get totalCarbs => entries.fold(0, (sum, entry) => sum + entry.nutrition.carbs);
  double get totalProtein => entries.fold(0, (sum, entry) => sum + entry.nutrition.protein);

  List<MealEntry> getMealEntries(MealType meal) {
    return entries.where((e) => e.meal == meal).toList();
  }

  double getMealCalories(MealType meal) {
    return getMealEntries(meal).fold(0, (sum, entry) => sum + entry.nutrition.calories);
  }
}
