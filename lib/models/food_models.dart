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
    // Helper to extract amount from nested structure, direct value, or string with units
    double extractAmount(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is Map) return (value['amount'] ?? 0).toDouble();
      if (value is String) {
        // Handle "20g", "150 kcal", etc.
        final numericPart = RegExp(r'(\d+\.?\d*)').firstMatch(value)?.group(1);
        return double.tryParse(numericPart ?? '0') ?? 0;
      }
      return 0;
    }

    // OpenAI sometimes returns different key names
    dynamic getVal(List<String> keys) {
      for (var k in keys) {
        if (json.containsKey(k)) return json[k];
        // Check case-insensitive
        for (var existingKey in json.keys) {
          if (existingKey.toLowerCase() == k.toLowerCase()) return json[existingKey];
        }
      }
      return null;
    }

    return NutritionData(
      calories: extractAmount(getVal(['calories', 'kcal', 'energy', 'Calories'])),
      fat: extractAmount(getVal(['fat', 'total_fat', 'fats', 'Fat'])),
      carbs: extractAmount(getVal(['carbohydrate', 'carbs', 'carbohydrates', 'Carbs'])),
      protein: extractAmount(getVal(['protein', 'proteins', 'Protein'])),
      fiber: extractAmount(getVal(['dietary_fiber', 'fiber', 'fibers', 'Dietary Fiber'])),
      sugar: extractAmount(getVal(['sugar', 'sugars', 'total_sugar'])),
      vitaminA: extractAmount(getVal(['vitamin_a', 'vit_a'])),
      vitaminB1: extractAmount(getVal(['vitamin_b1', 'thiamin'])),
      vitaminB2: extractAmount(getVal(['vitamin_b2', 'riboflavin'])),
      vitaminC: extractAmount(getVal(['vitamin_c', 'ascorbic_acid'])),
      vitaminE: extractAmount(getVal(['vitamin_e', 'tocopherol'])),
      calcium: extractAmount(getVal(['calcium', 'ca'])),
      iron: extractAmount(getVal(['iron', 'fe'])),
      magnesium: extractAmount(getVal(['magnesium', 'mg'])),
      potassium: extractAmount(getVal(['potassium', 'k'])),
      sodium: extractAmount(getVal(['sodium', 'na'])),
      zinc: extractAmount(getVal(['zinc', 'zn'])),
      cholesterol: extractAmount(getVal(['cholesterol'])),
      carotene: extractAmount(getVal(['carotene'])),
      retinol: extractAmount(getVal(['retinol'])),
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
