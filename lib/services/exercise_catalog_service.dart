import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise.dart';

/// Loads and searches the bundled free-exercise-db catalog (876 exercises).
/// The JSON is parsed once and cached in memory for the app's lifetime.
class ExerciseCatalog {
  ExerciseCatalog._();
  static final ExerciseCatalog instance = ExerciseCatalog._();

  List<Exercise>? _all;

  /// Loads (and caches) all exercises, sorted by name.
  Future<List<Exercise>> loadAll() async {
    if (_all != null) return _all!;
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final decoded = jsonDecode(raw);
    final List list = decoded is List
        ? decoded
        : (decoded['exercises'] as List? ?? const []);
    _all = list
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _all!;
  }

  Exercise? byId(String id) {
    final all = _all;
    if (all == null) return null;
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Filters an already-loaded list by free-text query + optional facets.
  List<Exercise> filter(
    List<Exercise> source, {
    String query = '',
    String? muscle,
    String? equipment,
    String? category,
  }) {
    final q = query.trim().toLowerCase();
    return source.where((e) {
      if (q.isNotEmpty) {
        final hay =
            '${e.name} ${e.primaryMuscles.join(' ')} ${e.equipment ?? ''} ${e.category ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (muscle != null &&
          !e.primaryMuscles.contains(muscle) &&
          !e.secondaryMuscles.contains(muscle)) {
        return false;
      }
      if (equipment != null && e.equipment != equipment) return false;
      if (category != null && e.category != category) return false;
      return true;
    }).toList();
  }

  /// Distinct primary muscles across the catalog, most common first.
  List<String> muscles(List<Exercise> all) => _facet(all, (e) => e.primaryMuscles);

  List<String> equipmentTypes(List<Exercise> all) =>
      _facet(all, (e) => e.equipment == null ? const [] : [e.equipment!]);

  List<String> categories(List<Exercise> all) =>
      _facet(all, (e) => e.category == null ? const [] : [e.category!]);

  List<String> _facet(List<Exercise> all, List<String> Function(Exercise) pick) {
    final counts = <String, int>{};
    for (final e in all) {
      for (final v in pick(e)) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys;
  }
}
