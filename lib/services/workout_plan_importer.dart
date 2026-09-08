import '../models/ai_coach_models.dart' show FitnessPlan;
import '../models/exercise.dart';
import '../models/workout_session.dart';
import 'exercise_catalog_service.dart';
import 'workout_service.dart';

/// Result of importing an AI-Coach plan into the workout log.
class WorkoutImportResult {
  final int daysImported;
  final int exercisesTotal;
  final int matchedToCatalog; // resolved to a catalog exercise (has a demo)
  final int custom; // no catalog match → kept as a name-only custom entry
  const WorkoutImportResult({
    this.daysImported = 0,
    this.exercisesTotal = 0,
    this.matchedToCatalog = 0,
    this.custom = 0,
  });

  double get matchRate =>
      exercisesTotal == 0 ? 0 : matchedToCatalog / exercisesTotal;
}

class _Parsed {
  final String name;
  final int sets;
  final int reps;
  const _Parsed(this.name, this.sets, this.reps);
}

/// Converts an AI-Coach [FitnessPlan]'s 7 workout days into dated workout-log
/// days, resolving each free-text exercise to a catalog exercise (so it gets a
/// demo) where possible, or keeping it as a custom entry otherwise.
class WorkoutPlanImporter {
  WorkoutPlanImporter._();
  static final WorkoutPlanImporter instance = WorkoutPlanImporter._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Materialize [plan]'s workouts into the workout log, dated from the plan's
  /// effective start date. Days the user has already logged are left untouched
  /// unless [overwrite] is true. Rest days are skipped.
  Future<WorkoutImportResult> importPlan(FitnessPlan plan,
      {bool overwrite = false}) async {
    final catalog = await ExerciseCatalog.instance.loadAll();
    final start = _dateOnly(plan.effectiveStartDate);

    int days = 0, total = 0, matched = 0, custom = 0;

    for (int i = 0; i < plan.weeklyWorkouts.length && i < 7; i++) {
      final dw = plan.weeklyWorkouts[i];
      final date = start.add(Duration(days: i));
      if (dw.isRestDay || dw.exercises.isEmpty) continue;

      final existing = await WorkoutService.instance.getDay(date);
      if (existing.exercises.isNotEmpty && !overwrite) continue;

      final routine = <RoutineExercise>[];
      for (final raw in dw.exercises) {
        total++;
        final p = _parseExercise(raw);
        final match = resolveExercise(p.name, catalog);
        if (match != null) {
          matched++;
          routine.add(RoutineExercise.fromExercise(match,
              sets: p.sets, reps: p.reps));
        } else {
          custom++;
          routine.add(RoutineExercise(
            exerciseId: 'plan_${WorkoutDay.keyFor(date)}_${routine.length}',
            name: p.name,
            primaryMuscles: const [],
            targetSets: p.sets,
            targetReps: p.reps,
            sets: List.generate(p.sets, (_) => SetLog(reps: p.reps)),
          ));
        }
      }

      if (routine.isNotEmpty) {
        await WorkoutService.instance.saveDay(
            WorkoutDay(date: WorkoutDay.keyFor(date), exercises: routine));
        days++;
      }
    }

    return WorkoutImportResult(
      daysImported: days,
      exercisesTotal: total,
      matchedToCatalog: matched,
      custom: custom,
    );
  }

  /// Parse an exercise string like "Bench Press — 4×8", "Squat 3x12", or just
  /// "Deadlift" into a name + sets/reps (defaults 3×10 when absent).
  static _Parsed _parseExercise(String raw) {
    var s = raw.trim();
    int sets = 3, reps = 10;
    final m = RegExp(r'(\d+)\s*[x×X]\s*(\d+)').firstMatch(s);
    if (m != null) {
      sets = (int.tryParse(m.group(1)!) ?? 3).clamp(1, 20);
      reps = (int.tryParse(m.group(2)!) ?? 10).clamp(1, 100);
      s = s.substring(0, m.start); // name is the part before the sets×reps
    }
    // Strip leading "1. " numbering and trailing separators/qualifiers.
    s = s.replaceAll(RegExp(r'^\s*\d+[.)]\s*'), '');
    s = s.replaceAll(RegExp(r'[—–\-–—:(]+.*$'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _Parsed(s.isEmpty ? raw.trim() : s, sets, reps);
  }

  // ── Name resolution ────────────────────────────────────────────────────────
  static const _stop = {'the', 'a', 'an', 'with', 'and', 'of', 'for', 'to'};
  static const _goodEquip = {
    'barbell', 'dumbbell', 'body only', 'cable', 'machine', 'kettlebells'
  };

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Light stemming so "biceps"/"bicep", "curls"/"curl", "raises"/"raise" match.
  static String _stem(String t) {
    if (t.length > 4 && t.endsWith('es')) return t.substring(0, t.length - 2);
    if (t.length > 3 && t.endsWith('s')) return t.substring(0, t.length - 1);
    return t;
  }

  static Set<String> _tokens(String s) => _normalize(s)
      .split(' ')
      .where((t) => t.length > 1 && !_stop.contains(t))
      .map(_stem)
      .toSet();

  /// Resolve a free-text exercise name to a catalog [Exercise], or null.
  /// Confident rule: every meaningful token of the query must appear in the
  /// catalog name; ties broken by common equipment + conciseness.
  static Exercise? resolveExercise(String name, List<Exercise> catalog) {
    final q = _normalize(name);
    if (q.isEmpty) return null;

    // 1) exact normalized name.
    for (final e in catalog) {
      if (_normalize(e.name) == q) return e;
    }

    final qTokens = _tokens(name);
    if (qTokens.isEmpty) return null;

    Exercise? best;
    double bestScore = -1;
    for (final e in catalog) {
      final eTokens = _tokens(e.name);
      if (eTokens.isEmpty) continue;
      // Require ALL query tokens present in the catalog name (high precision).
      if (!qTokens.every(eTokens.contains)) continue;
      double score = 1.0;
      if (e.equipment != null && _goodEquip.contains(e.equipment)) score += 0.15;
      // Prefer the most concise catalog name (closest to the generic query).
      score -= eTokens.length * 0.02;
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }
}
