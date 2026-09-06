import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../theme/app_theme.dart';

/// Exercise detail: an animated 2-frame demo (start ↔ end position) plus target
/// muscles, equipment/difficulty, and step-by-step instructions.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({Key? key, required this.exercise}) : super(key: key);

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.exercise.hasAnimation) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (!mounted) return;
        setState(() => _frame = _frame == 0 ? 1 : 0);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Exercise get e => widget.exercise;

  @override
  Widget build(BuildContext context) {
    final urls = e.imageUrls;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(e.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.xl),
        children: [
          _demo(urls),
          const SizedBox(height: AppTheme.lg),
          _tags(),
          const SizedBox(height: AppTheme.lg),
          if (e.primaryMuscles.isNotEmpty || e.secondaryMuscles.isNotEmpty) ...[
            _sectionTitle('Target muscles'),
            const SizedBox(height: AppTheme.sm),
            _muscles(),
            const SizedBox(height: AppTheme.lg),
          ],
          if (e.instructions.isNotEmpty) ...[
            _sectionTitle('Instructions'),
            const SizedBox(height: AppTheme.sm),
            ..._instructions(),
          ],
        ],
      ),
    );
  }

  Widget _demo(List<String> urls) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.2,
        child: urls.isEmpty
            ? const Icon(Icons.fitness_center, size: 48, color: Colors.black26)
            : Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: CachedNetworkImage(
                      key: ValueKey(_frame),
                      imageUrl: urls[_frame.clamp(0, urls.length - 1)],
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFECECEC)),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.fitness_center,
                          size: 48,
                          color: Colors.black26),
                    ),
                  ),
                  if (e.hasAnimation)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.play_circle_fill_rounded,
                              size: 13, color: AppTheme.lime),
                          const SizedBox(width: 4),
                          Text('${_frame + 1}/${urls.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _tags() {
    final tags = <String>[
      if (e.level != null) _cap(e.level!),
      if (e.equipment != null) _cap(e.equipment!),
      if (e.mechanic != null) _cap(e.mechanic!),
      if (e.category != null) _cap(e.category!),
      if (e.force != null) '${_cap(e.force!)} force',
    ];
    return Wrap(
      spacing: AppTheme.sm,
      runSpacing: AppTheme.sm,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(t,
                style: AppTheme.labelMD.copyWith(color: AppTheme.textSecondary)),
          ),
      ],
    );
  }

  Widget _muscles() {
    Widget pill(String m, bool primary) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: primary
                ? AppTheme.lime.withValues(alpha: 0.15)
                : AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: primary
                    ? AppTheme.lime.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(_cap(m),
              style: AppTheme.labelMD.copyWith(
                  color: primary ? AppTheme.lime : AppTheme.textSecondary)),
        );
    return Wrap(
      spacing: AppTheme.sm,
      runSpacing: AppTheme.sm,
      children: [
        for (final m in e.primaryMuscles) pill(m, true),
        for (final m in e.secondaryMuscles) pill(m, false),
      ],
    );
  }

  List<Widget> _instructions() {
    return [
      for (int i = 0; i < e.instructions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppTheme.lime, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(e.instructions[i],
                    style: AppTheme.bodyLG.copyWith(
                        color: AppTheme.textSecondary, height: 1.45)),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _sectionTitle(String t) => Text(t, style: AppTheme.headingSM);

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
