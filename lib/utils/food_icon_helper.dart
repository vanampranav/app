import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../theme/app_theme.dart';

/// Returns the best Material icon + accent colour for a food item.
///
/// Priority:
///   1. If [nutrition] is available, derive from dominant macro.
///   2. Fall back to keyword matching on [foodName].
///   3. Default: restaurant icon in lime.
///
/// Usage:
///   final fi = FoodIconHelper.get(foodName: entry.foodName, nutrition: entry.nutrition);
///   Icon(fi.icon, color: fi.color)
class FoodIconHelper {
  FoodIconHelper._();

  static FoodIconData get({
    required String foodName,
    NutritionData? nutrition,
  }) {
    if (nutrition != null && nutrition.calories > 5) {
      return _fromMacros(nutrition, foodName);
    }
    return _fromName(foodName);
  }

  // ── Macro-based (most accurate) ──────────────────────────────────────────
  static FoodIconData _fromMacros(NutritionData n, String name) {
    final cal = n.calories;
    if (cal <= 0) return _fromName(name);

    final proteinPct = (n.protein * 4) / cal;
    final carbPct    = (n.carbs   * 4) / cal;
    final fatPct     = (n.fat     * 9) / cal;

    // Strongly protein-dominant (≥30% kcal from protein)
    if (proteinPct >= 0.30) return FoodIconData(Icons.fitness_center,   const Color(0xFFFF6B6B));
    // Strongly carb-dominant (≥55% kcal from carbs)
    if (carbPct    >= 0.55) return FoodIconData(Icons.grain,             const Color(0xFF4ECDC4));
    // Strongly fat-dominant (≥45% kcal from fat)
    if (fatPct     >= 0.45) return FoodIconData(Icons.water_drop,        const Color(0xFFFFD93D));
    // Balanced — fall through to name matching for a better icon
    return _fromName(name);
  }

  // ── Name-based keyword matching (fallback) ────────────────────────────────
  static FoodIconData _fromName(String foodName) {
    final n = foodName.toLowerCase();

    if (_has(n, _beverageKw))  return FoodIconData(Icons.local_cafe,       const Color(0xFF3B9EFF));
    if (_has(n, _veggieKw))    return FoodIconData(Icons.eco,               const Color(0xFF6BCB77));
    if (_has(n, _fruitKw))     return FoodIconData(Icons.local_florist,     const Color(0xFFFF8C42));
    if (_has(n, _proteinKw))   return FoodIconData(Icons.fitness_center,    const Color(0xFFFF6B6B));
    if (_has(n, _dairyKw))     return FoodIconData(Icons.local_drink,       const Color(0xFFFFD93D));
    if (_has(n, _grainKw))     return FoodIconData(Icons.grain,             const Color(0xFF4ECDC4));
    if (_has(n, _sweetKw))     return FoodIconData(Icons.cake,              const Color(0xFFFF8C42));
    if (_has(n, _nutKw))       return FoodIconData(Icons.spa,               const Color(0xFF8B5CF6));
    if (_has(n, _supplementKw))return FoodIconData(Icons.science,           const Color(0xFF8B5CF6));

    return FoodIconData(Icons.restaurant, AppTheme.lime);
  }

  static bool _has(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Keyword lists ─────────────────────────────────────────────────────────
  static const _beverageKw   = ['water','juice','tea','coffee','milk drink','smoothie',
                                  'shake','soda','cola','beer','wine','latte','espresso',
                                  'cappuccino','americano','kombucha','lassi','lemonade',
                                  'energy drink','sports drink','protein shake'];
  static const _veggieKw     = ['salad','spinach','broccoli','kale','lettuce','veggie',
                                  'vegetable','cabbage','celery','carrot','cucumber',
                                  'zucchini','tomato','capsicum','pea','dal','lentil',
                                  'chickpea','soybean','edamame','okra','asparagus',
                                  'cauliflower','eggplant','onion','garlic','mushroom'];
  static const _fruitKw      = ['apple','banana','orange','berry','mango','fruit',
                                  'grape','peach','pear','kiwi','melon','watermelon',
                                  'pineapple','cherry','coconut','avocado','pomegranate',
                                  'papaya','guava','lychee','fig','date','plum'];
  static const _proteinKw    = ['chicken','beef','fish','salmon','tuna','shrimp','prawn',
                                  'crab','lobster','egg','steak','lamb','mutton','pork',
                                  'turkey','duck','tofu','tempeh','meat','seafood','squid',
                                  'sardine','anchovy','whey protein','protein powder'];
  static const _dairyKw      = ['cheese','yogurt','curd','butter','cream','ghee','paneer',
                                  'milk','kefir','ricotta','mozzarella','parmesan','cheddar'];
  static const _grainKw      = ['rice','bread','pasta','oat','cereal','noodle','roti',
                                  'naan','tortilla','chapati','wheat','flour','bagel',
                                  'croissant','muffin','waffle','pancake','biryani','pulao',
                                  'quinoa','barley','millet','dosa','idli','vermicelli'];
  static const _sweetKw      = ['chocolate','cake','cookie','candy','sweet','ice cream',
                                  'dessert','donut','brownie','cupcake','tart','pudding',
                                  'custard','halwa','ladoo','barfi','gulab jamun','kheer',
                                  'macaron','eclair','cheesecake','pie','toffee','caramel'];
  static const _nutKw        = ['almond','peanut','cashew','walnut','pistachio','hazelnut',
                                  'macadamia','pecan','seed','nut butter','trail mix'];
  static const _supplementKw = ['protein bar','protein powder','whey','creatine','bcaa',
                                  'supplement','vitamin','probiotic','collagen','mass gainer'];
}

/// Returned by [FoodIconHelper.get].
class FoodIconData {
  final IconData icon;
  final Color    color;
  const FoodIconData(this.icon, this.color);
}

/// Material icon for each meal type.
class MealIconHelper {
  MealIconHelper._();

  static IconData icon(MealType meal) {
    switch (meal) {
      case MealType.breakfast: return Icons.breakfast_dining;
      case MealType.lunch:     return Icons.lunch_dining;
      case MealType.snacks:    return Icons.cookie;
      case MealType.dinner:    return Icons.dinner_dining;
    }
  }

  static Color color(MealType meal) {
    switch (meal) {
      case MealType.breakfast: return const Color(0xFFFF8C42);
      case MealType.lunch:     return const Color(0xFF3B9EFF);
      case MealType.snacks:    return const Color(0xFF4ECDC4);
      case MealType.dinner:    return const Color(0xFF8B5CF6);
    }
  }

  static String label(MealType meal) {
    switch (meal) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.snacks:    return 'Snacks';
      case MealType.dinner:    return 'Dinner';
    }
  }
}
