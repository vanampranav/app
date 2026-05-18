import '../models/ai_coach_models.dart';

/// Parser for AI Coach meal and workout plan text responses.
/// Ported from the-elefit-nextjs/lib/ai-coach-parser.ts
class AiCoachParser {
  /// Parse streamed meal plan text into 7-day DayMeals list
  static List<DayMeals> parseMealPlan(String text) {
    final List<DayMeals> weeklyMeals = [];

    // Split by "Day X" markers
    final dayRegex = RegExp(r'(?=Day\s*\d+[:\s\u2013\u2014-])', caseSensitive: false);
    final segments = text.split(dayRegex).where((d) {
      final trimmed = d.trim();
      return trimmed.isNotEmpty &&
          (RegExp(r'^Day\s*\d+', caseSensitive: false).hasMatch(trimmed) ||
           RegExp(r'Breakfast|Lunch|Dinner|Snack', caseSensitive: false).hasMatch(trimmed));
    }).toList();

    for (int idx = 0; idx < segments.length && idx < 7; idx++) {
      final dayText = segments[idx];
      final dayMeals = <String, List<MealItem>>{};

      // Split by meal section headers: "— Breakfast (XXX kcal):"
      final mealRegex = RegExp(
        r'[\u2014\u2013\-–—]\s*(Breakfast|Lunch|Snack|Dinner|Snacks)\s*\((\d+)[^)]*\)\s*:',
        caseSensitive: false,
      );

      final matches = mealRegex.allMatches(dayText).toList();

      for (int m = 0; m < matches.length; m++) {
        String mealType = matches[m].group(1)!.trim();
        if (mealType.toLowerCase() == 'snack') mealType = 'Snacks';

        // Get text between this match and the next
        final startPos = matches[m].end;
        final endPos = (m + 1 < matches.length) ? matches[m + 1].start : dayText.length;
        final itemsText = dayText.substring(startPos, endPos);

        final items = <MealItem>[];
        final lines = itemsText.split('\n');

        for (final line in lines) {
          // Full match: "1. Name — Quantity — 200 kcal — P: 10g / C: 20g / F: 5g"
          final fullMatch = RegExp(
            r'^\s*\d+\.\s*(.*?)\s*[\u2014\u2013\-–—]+\s*(.*?)\s*[\u2014\u2013\-–—]+\s*(\d+(?:\.\d+)?)\s*kcal\s*[\u2014\u2013\-–—]+\s*(.*)$',
            caseSensitive: false,
          ).firstMatch(line);

          if (fullMatch != null) {
            items.add(MealItem(
              name: fullMatch.group(1)!.trim(),
              quantity: fullMatch.group(2)!.trim(),
              calories: int.parse(fullMatch.group(3)!),
              macro: fullMatch.group(4)!.trim().replaceAll('/', ' • '),
            ));
            continue;
          }

          // Simple match: "1. Name — Quantity — 200 kcal"
          final simpleMatch = RegExp(
            r'^\s*\d+\.\s*(.*?)\s*[\u2014\u2013\-–—]+\s*(.*?)\s*[\u2014\u2013\-–—]+\s*(\d+(?:\.\d+)?)\s*kcal',
            caseSensitive: false,
          ).firstMatch(line);

          if (simpleMatch != null) {
            items.add(MealItem(
              name: simpleMatch.group(1)!.trim(),
              quantity: simpleMatch.group(2)!.trim(),
              calories: int.parse(simpleMatch.group(3)!),
              macro: 'Modified',
            ));
            continue;
          }

          // Very simple: "1. Name — 200 kcal"
          final verySimple = RegExp(
            r'^\s*\d+\.\s*(.*?)\s*[\u2014\u2013\-–—]+\s*(\d+(?:\.\d+)?)\s*kcal',
            caseSensitive: false,
          ).firstMatch(line);

          if (verySimple != null) {
            items.add(MealItem(
              name: verySimple.group(1)!.trim(),
              quantity: 'As specified',
              calories: int.parse(verySimple.group(2)!),
              macro: 'Modified',
            ));
          }
        }

        if (items.isNotEmpty) {
          dayMeals[mealType] = items;
        }
      }

      weeklyMeals.add(DayMeals(mealsByTime: dayMeals));
    }

    // Ensure 7 days
    while (weeklyMeals.length < 7) {
      weeklyMeals.add(DayMeals(mealsByTime: {}));
    }

    return weeklyMeals;
  }

  /// Parse streamed workout plan text into 7-day DayWorkout list
  static List<DayWorkout> parseWorkoutPlan(String text) {
    final List<DayWorkout> weeklyWorkouts = [];

    final dayRegex = RegExp(r'(?=Day\s*\d+[:\s\u2013\u2014-])', caseSensitive: false);
    final segments = text.split(dayRegex).where((d) {
      final trimmed = d.trim();
      return trimmed.isNotEmpty &&
          (RegExp(r'^Day\s*\d+', caseSensitive: false).hasMatch(trimmed) ||
           RegExp(r'Workout|Exercise', caseSensitive: false).hasMatch(trimmed));
    }).toList();

    for (int idx = 0; idx < segments.length && idx < 7; idx++) {
      final dayText = segments[idx];

      // Extract focus name after "Day X – [Focus]:"
      final headerMatch = RegExp(r'Day\s*\d+.*?[\u2014\u2013\-–—]\s*(.*?):', caseSensitive: false).firstMatch(dayText);
      String name = headerMatch?.group(1)?.trim() ?? '';

      // Fallback: "Workout: Name (Duration)"
      if (name.isEmpty || name.toLowerCase().contains('day')) {
        final workoutMatch = RegExp(r'Workout:\s*(.*?)\s*(?:\((.*?)\))?\n', caseSensitive: false).firstMatch(dayText);
        if (workoutMatch != null) {
          name = workoutMatch.group(1)?.trim() ?? '';
        }
      }
      if (name.isEmpty) name = 'Rest Day';

      // Duration
      final durationMatch = RegExp(r'\((.*?mins?)\)', caseSensitive: false).firstMatch(dayText);
      final duration = durationMatch?.group(1)?.trim() ?? '0 mins';

      // Exercises (numbered items)
      final exercises = <String>[];
      for (final line in dayText.split('\n')) {
        final exMatch = RegExp(r'^\s*\d+\.\s*(.*?)(?:\s*[\u2014\u2013\-–—]\s*.*)?$').firstMatch(line);
        if (exMatch != null &&
            !line.toLowerCase().contains('day') &&
            !line.toLowerCase().contains('workout:')) {
          exercises.add(exMatch.group(1)!.trim());
        }
      }

      final isRestDay = name.toLowerCase().contains('rest') || exercises.isEmpty;

      weeklyWorkouts.add(DayWorkout(
        name: isRestDay ? 'Rest Day' : name,
        duration: isRestDay ? '0 mins' : duration,
        exercises: exercises,
        isRestDay: isRestDay,
      ));
    }

    // Ensure 7 days
    while (weeklyWorkouts.length < 7) {
      weeklyWorkouts.add(DayWorkout(
        name: 'Rest Day',
        duration: '0 mins',
        exercises: [],
        isRestDay: true,
      ));
    }

    return weeklyWorkouts;
  }
}
