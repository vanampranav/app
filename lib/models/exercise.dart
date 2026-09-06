/// A single exercise from the bundled free-exercise-db catalog
/// (public domain / Unlicense — https://github.com/yuhonas/free-exercise-db).
///
/// Images aren't bundled — only their relative paths are. The full image URLs
/// are built on demand against the jsDelivr CDN and loaded with
/// cached_network_image, so they're fetched once and cached on device.
class Exercise {
  final String id;
  final String name;
  final String? force; // push / pull / static
  final String? level; // beginner / intermediate / expert
  final String? mechanic; // compound / isolation
  final String? equipment; // barbell / dumbbell / body only ...
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? category; // strength / stretching / cardio ...
  final List<String> images; // relative paths, e.g. "3_4_Sit-Up/0.jpg"

  const Exercise({
    required this.id,
    required this.name,
    this.force,
    this.level,
    this.mechanic,
    this.equipment,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.category,
    this.images = const [],
  });

  factory Exercise.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Exercise(
      id: (j['id'] ?? j['name'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      force: j['force'] as String?,
      level: j['level'] as String?,
      mechanic: j['mechanic'] as String?,
      equipment: j['equipment'] as String?,
      primaryMuscles: strList(j['primaryMuscles']),
      secondaryMuscles: strList(j['secondaryMuscles']),
      instructions: strList(j['instructions']),
      category: j['category'] as String?,
      images: strList(j['images']),
    );
  }

  static const String _cdnBase =
      'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/';

  /// Full CDN URLs for every frame (usually 2: start + end position).
  List<String> get imageUrls => images.map((p) => '$_cdnBase$p').toList();

  /// First frame — used as the library thumbnail.
  String? get thumbnailUrl =>
      images.isNotEmpty ? '$_cdnBase${images.first}' : null;

  bool get hasAnimation => images.length >= 2;

  /// A short one-line descriptor for cards, e.g. "Barbell · Compound".
  String get subtitle {
    final parts = <String>[
      if (equipment != null && equipment!.isNotEmpty) _cap(equipment!),
      if (primaryMuscles.isNotEmpty) _cap(primaryMuscles.first),
    ];
    return parts.join(' · ');
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
