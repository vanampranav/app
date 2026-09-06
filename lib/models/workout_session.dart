import 'exercise.dart';

/// One logged set of an exercise.
class SetLog {
  int reps;
  double? weightKg;
  bool done;

  SetLog({this.reps = 0, this.weightKg, this.done = false});

  Map<String, dynamic> toJson() =>
      {'reps': reps, 'weightKg': weightKg, 'done': done};

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        done: j['done'] == true,
      );
}

/// An exercise added to a day's routine, with its target and per-set log.
class RoutineExercise {
  final String exerciseId;
  final String name;
  final String? thumbnailUrl;
  final List<String> primaryMuscles;
  int targetSets;
  int targetReps;
  List<SetLog> sets;

  RoutineExercise({
    required this.exerciseId,
    required this.name,
    this.thumbnailUrl,
    this.primaryMuscles = const [],
    this.targetSets = 3,
    this.targetReps = 10,
    List<SetLog>? sets,
  }) : sets = sets ?? [];

  /// Build a routine entry from a catalog [Exercise] with a target.
  factory RoutineExercise.fromExercise(
    Exercise e, {
    int sets = 3,
    int reps = 10,
    double? weightKg,
  }) {
    return RoutineExercise(
      exerciseId: e.id,
      name: e.name,
      thumbnailUrl: e.thumbnailUrl,
      primaryMuscles: e.primaryMuscles,
      targetSets: sets,
      targetReps: reps,
      sets: List.generate(
          sets, (_) => SetLog(reps: reps, weightKg: weightKg, done: false)),
    );
  }

  bool get completed => sets.isNotEmpty && sets.every((s) => s.done);
  int get doneSets => sets.where((s) => s.done).length;
  String get muscleLabel {
    if (primaryMuscles.isEmpty) return '';
    final m = primaryMuscles.first;
    return m.isEmpty ? m : m[0].toUpperCase() + m.substring(1);
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'thumbnailUrl': thumbnailUrl,
        'primaryMuscles': primaryMuscles,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory RoutineExercise.fromJson(Map<String, dynamic> j) => RoutineExercise(
        exerciseId: (j['exerciseId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        thumbnailUrl: j['thumbnailUrl'] as String?,
        primaryMuscles:
            (j['primaryMuscles'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: (j['targetReps'] as num?)?.toInt() ?? 10,
        sets: (j['sets'] as List?)
                ?.map((e) => SetLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// A single day's workout (its routine of exercises).
class WorkoutDay {
  final String date; // yyyy-MM-dd
  final List<RoutineExercise> exercises;

  WorkoutDay({required this.date, List<RoutineExercise>? exercises})
      : exercises = exercises ?? [];

  int get total => exercises.length;
  int get completedCount => exercises.where((e) => e.completed).length;
  double get progress => total == 0 ? 0 : completedCount / total;
  bool get allDone => total > 0 && completedCount == total;

  /// Total volume = Σ(reps × weight) over completed sets — for history charts.
  double get volume {
    double v = 0;
    for (final ex in exercises) {
      for (final s in ex.sets) {
        if (s.done) v += s.reps * (s.weightKg ?? 0);
      }
    }
    return v;
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> j) => WorkoutDay(
        date: (j['date'] ?? '').toString(),
        exercises: (j['exercises'] as List?)
                ?.map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
