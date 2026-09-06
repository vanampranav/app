import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/exercise_catalog_service.dart';
import '../../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

/// Browse / search / filter the free-exercise-db catalog.
class ExerciseLibraryScreen extends StatefulWidget {
  /// When true, tapping an exercise returns it (Navigator.pop) instead of
  /// opening the detail screen — used to pick an exercise for a routine.
  final bool pickMode;
  const ExerciseLibraryScreen({Key? key, this.pickMode = false})
      : super(key: key);

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _catalog = ExerciseCatalog.instance;
  List<Exercise> _all = [];
  List<String> _muscles = [];
  bool _loading = true;
  String _query = '';
  String? _muscle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _catalog.loadAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _muscles = _catalog.muscles(all);
      _loading = false;
    });
  }

  List<Exercise> get _filtered =>
      _catalog.filter(_all, query: _query, muscle: _muscle);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Add exercise' : 'Exercise Library',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
          : Column(
              children: [
                _searchBar(),
                _muscleChips(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.md, 4, AppTheme.md, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_filtered.length} exercises',
                        style: AppTheme.bodySM
                            .copyWith(color: AppTheme.textTertiary)),
                  ),
                ),
                Expanded(child: _grid()),
              ],
            ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Search exercises…',
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          isDense: true,
        ),
      ),
    );
  }

  Widget _muscleChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 8),
        itemCount: _muscles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
        itemBuilder: (_, i) {
          if (i == 0) return _chip('All', _muscle == null, () => setState(() => _muscle = null));
          final m = _muscles[i - 1];
          return _chip(_cap(m), _muscle == m,
              () => setState(() => _muscle = _muscle == m ? null : m));
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.lime : AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: selected
                    ? AppTheme.lime
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(label,
              style: AppTheme.labelMD.copyWith(
                  color: selected ? Colors.black : AppTheme.textSecondary)),
        ),
      ),
    );
  }

  Widget _grid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text('No exercises match your search.',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.md, 0, AppTheme.md, AppTheme.xl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppTheme.md,
        crossAxisSpacing: AppTheme.md,
        childAspectRatio: 0.74,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i]),
    );
  }

  Widget _card(Exercise e) {
    return GestureDetector(
      onTap: () {
        if (widget.pickMode) {
          Navigator.pop(context, e);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: e)),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Container(
                color: Colors.white,
                child: e.thumbnailUrl == null
                    ? const Icon(Icons.fitness_center,
                        color: Colors.black26, size: 36)
                    : CachedNetworkImage(
                        imageUrl: e.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(
                            color: Color(0xFFECECEC)),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.fitness_center,
                            color: Colors.black26,
                            size: 36),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelLG.copyWith(
                          color: AppTheme.textPrimary, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(e.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySM
                          .copyWith(color: AppTheme.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
