import '../models/food_models.dart';

/// Result of a nutrition sanity check.
class NutritionCheck {
  /// False only for HARD errors (negative values) that should block logging.
  final bool usable;

  /// Non-null when the data is loggable but looks suspicious — show as a warning.
  final String? warning;

  const NutritionCheck({this.usable = true, this.warning});

  bool get hasWarning => warning != null;
}

/// Shared validation for nutrition data from ANY source — FatSecret search,
/// barcode, manual entry, and AI image vision. Two layers:
///   1. Macro↔calorie consistency (Atwater): cal ≈ protein*4 + carbs*4 + fat*9
///   2. Per-100g plausibility (calories/macros can't exceed physical limits)
class NutritionValidator {
  /// True when stated calories are within a sane range of the Atwater estimate.
  /// Used to decide whether to TRUST a source (e.g. accept FatSecret over an AI
  /// estimate in the image hybrid).
  static bool macrosConsistent(NutritionData n) {
    if (n.calories <= 0) return false;
    final expected = n.protein * 4 + n.carbs * 4 + n.fat * 9;
    if (expected <= 0) return false;
    final ratio = n.calories / expected;
    return ratio >= 0.6 && ratio <= 1.6;
  }

  /// Full check for a logged portion. Hard errors set usable=false (block);
  /// implausible-but-loggable cases set a warning (allow, but flag to the user).
  static NutritionCheck validate(NutritionData n, double weightGrams) {
    if (weightGrams <= 0) {
      return const NutritionCheck(usable: false, warning: 'Weight must be greater than 0.');
    }
    if (n.calories < 0 || n.protein < 0 || n.carbs < 0 || n.fat < 0) {
      return const NutritionCheck(usable: false, warning: "Nutrition values can't be negative.");
    }

    // Per-100g plausibility — scale the portion back to 100g.
    final per100 = 100 / weightGrams;
    final cal100 = n.calories * per100;
    final macroG100 = (n.protein + n.carbs + n.fat) * per100;
    if (cal100 > 950) {
      // Pure fat is ~900 kcal/100g; anything above is physically impossible.
      return const NutritionCheck(warning: 'Calories look too high for this portion — double-check.');
    }
    if (macroG100 > 105) {
      // Macros can't weigh more than the food itself.
      return const NutritionCheck(warning: 'Macros exceed the food weight — double-check.');
    }

    // Only flag when stated calories are well BELOW what the macros imply — that
    // signals a parse/scaling error. Calories ABOVE the macro sum is normal and
    // must NOT warn: alcohol (~7 kcal/g) and sugar alcohols add energy that isn't
    // captured by protein/carbs/fat (e.g. beer, wine).
    final expected = n.protein * 4 + n.carbs * 4 + n.fat * 9;
    if (expected > 0 && n.calories < expected * 0.6) {
      return const NutritionCheck(warning: 'Calories look too low for the macros — double-check.');
    }
    return const NutritionCheck();
  }
}
