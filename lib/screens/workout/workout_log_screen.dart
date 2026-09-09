import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../services/exercise_catalog_service.dart';
import '../../services/workout_service.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'exercise_library_screen.dart';
import 'workout_history_screen.dart';

/// Today's workout: build a routine, follow it, log each set, check off what's
/// done. Embeddable (returns a Column) so it lives under the Log tab's toggle.
class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutTemplate {
  final String name;
  final IconData icon;
  final List<String> muscles;
  const _WorkoutTemplate(this.name, this.icon, this.muscles);
}

/// Chosen target when adding an exercise to the routine.
class _TargetSpec {
  final int sets;
  final int reps;
  final double? weight;
  const _TargetSpec(this.sets, this.reps, this.weight);
}

const _templates = <_WorkoutTemplate>[
  _WorkoutTemplate('Full Body', Icons.accessibility_new_rounded,
      ['chest', 'lats', 'quadriceps', 'shoulders', 'biceps']),
  _WorkoutTemplate('Push', Icons.arrow_upward_rounded,
      ['chest', 'shoulders', 'triceps']),
  _WorkoutTemplate('Pull', Icons.arrow_downward_rounded,
      ['lats', 'middle back', 'biceps']),
  _WorkoutTemplate('Legs', Icons.directions_run_rounded,
      ['quadriceps', 'hamstrings', 'glutes', 'calves']),
];

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final _service = WorkoutService.instance;
  DateTime _date = _dateOnly(DateTime.now());
  DateTime _weekAnchor = _dateOnly(DateTime.now()); // first (leftmost) day in the strip
  WorkoutDay _day = WorkoutDay(date: WorkoutDay.keyFor(DateTime.now()));
  bool _loading = true;
  final Set<int> _expanded = {};
  Set<String> _loggedDates = {}; // date keys that have a workout (week-strip dots)

  // Rest timer (between sets)
  Timer? _restTimer;
  int _restRemaining = 0;
  static const int _restDefaultSeconds = 90;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final day = await _service.getDay(_date);
    final logged = await _service.loggedDates();
    if (!mounted) return;
    setState(() {
      _day = day;
      _loggedDates = logged.toSet();
      _loading = false;
    });
  }

  Future<void> _selectDate(DateTime d) async {
    final day = await _service.getDay(d);
    final logged = await _service.loggedDates(); // refresh dots (e.g. after a plan import)
    if (!mounted) return;
    setState(() {
      _date = _dateOnly(d);
      _day = day;
      _loggedDates = logged.toSet();
      _expanded.clear();
    });
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() =>
        _weekAnchor = _weekAnchor.add(Duration(days: deltaWeeks * 7)));
  }

  Future<void> _save() async {
    await _service.saveDay(_day);
    final key = WorkoutDay.keyFor(_date);
    if (!mounted) return;
    setState(() {
      if (_day.exercises.isEmpty) {
        _loggedDates.remove(key);
      } else {
        _loggedDates.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
    }
    return Column(
      children: [
        _topBar(),
        _weekStrip(),
        if (_day.exercises.isNotEmpty) _progressBar(),
        if (_restRemaining > 0) _restBar(),
        Expanded(
          child: _day.exercises.isEmpty
              ? _emptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.md, 0, AppTheme.md, AppTheme.xl),
                  children: [
                    ..._groupedExerciseWidgets(),
                    const SizedBox(height: AppTheme.md),
                    _addButton(),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Top bar: title + calendar picker (matches the Nutrition tab) ───────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.xs, 0),
      child: Row(
        children: [
          const Text('Workout', style: AppTheme.headingLG),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppTheme.textSecondary),
            onPressed: () => _shiftWeek(-1),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
            onPressed: () => _shiftWeek(1),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _pickDate,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  static const _shortDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  // The 7 days shown: a forward window starting at the anchor (today by
  // default) → today is first and the rest of the plan week follows. Week
  // arrows / calendar reach other weeks (incl. future plan days & past).
  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekAnchor.add(Duration(days: i)));

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)), // allow future plan days
    );
    if (picked == null) return;
    setState(() => _weekAnchor = _dateOnly(picked));
    _selectDate(picked);
  }

  // ── 7-day strip (same style as the Nutrition tab) ──────────────────────────
  Widget _weekStrip() {
    final days = _weekDays;
    final today = _dateOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppTheme.sm, 4, AppTheme.sm),
      child: Row(
        children: days.map((day) {
          final isActive = _dateOnly(day) == _date;
          final isToday = _dateOnly(day) == today;
          final hasWorkout = _loggedDates.contains(WorkoutDay.keyFor(day));
          final textColor =
              (isActive || isToday) ? Colors.white : const Color(0xFF454545);
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(day),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  width: 5,
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasWorkout
                        ? (isActive
                            ? AppTheme.lime
                            : AppTheme.lime.withValues(alpha: 0.4))
                        : Colors.transparent,
                  ),
                ),
                Text(
                  day.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: isActive ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shortDays[day.weekday % 7],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: isActive ? 18 : 0,
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _progressBar() {
    final done = _day.completedCount;
    final total = _day.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, 0, AppTheme.md, AppTheme.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(DateFormat('EEEE, MMM d').format(_date),
                style: AppTheme.labelMD.copyWith(color: AppTheme.textSecondary)),
            const Spacer(),
            Text('$done / $total done',
                style: AppTheme.labelMD.copyWith(
                    color: done == total
                        ? AppTheme.lime
                        : AppTheme.textSecondary)),
          ]),
          const SizedBox(height: AppTheme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: _day.progress,
              minHeight: 8,
              backgroundColor: AppTheme.surface2,
              valueColor: const AlwaysStoppedAnimation(AppTheme.lime),
            ),
          ),
        ],
      ),
    );
  }

  // ── Group a day's exercises by body-region category ────────────────────────
  static const Map<String, String> _muscleCategory = {
    'chest': 'Chest',
    'lats': 'Back', 'middle back': 'Back', 'lower back': 'Back', 'traps': 'Back',
    'quadriceps': 'Legs', 'hamstrings': 'Legs', 'glutes': 'Legs',
    'calves': 'Legs', 'adductors': 'Legs', 'abductors': 'Legs',
    'shoulders': 'Shoulders', 'neck': 'Shoulders',
    'biceps': 'Arms', 'triceps': 'Arms', 'forearms': 'Arms',
    'abdominals': 'Core',
  };

  String _categoryOf(RoutineExercise ex) {
    if (ex.primaryMuscles.isEmpty) return 'Other';
    return _muscleCategory[ex.primaryMuscles.first.toLowerCase()] ?? 'Other';
  }

  List<Widget> _groupedExerciseWidgets() {
    final order = <String>[];
    final groups = <String, List<int>>{};
    for (int i = 0; i < _day.exercises.length; i++) {
      final cat = _categoryOf(_day.exercises[i]);
      if (!groups.containsKey(cat)) {
        groups[cat] = [];
        order.add(cat);
      }
      groups[cat]!.add(i);
    }
    // Single group → no need for section headers.
    if (order.length <= 1) {
      return [for (int i = 0; i < _day.exercises.length; i++) _exerciseCard(i)];
    }
    final widgets = <Widget>[];
    for (final cat in order) {
      final idxs = groups[cat]!;
      final done = idxs.where((i) => _day.exercises[i].completed).length;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, AppTheme.sm, 4, 4),
        child: Row(children: [
          Text(cat.toUpperCase(),
              style: AppTheme.labelMD.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Text('$done/${idxs.length}',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
        ]),
      ));
      for (final i in idxs) {
        widgets.add(_exerciseCard(i));
      }
    }
    return widgets;
  }

  // ── Exercise card (collapsed + expandable set log) ─────────────────────────
  Widget _exerciseCard(int i) {
    final ex = _day.exercises[i];
    final open = _expanded.contains(i);
    final done = ex.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: done ? AppTheme.lime.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              // Thumbnail → demo
              GestureDetector(
                onTap: () => _openDemo(ex),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Container(
                    color: Colors.white,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ex.thumbnailUrl != null)
                          CachedNetworkImage(
                            imageUrl: ex.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: Color(0xFFECECEC)),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.fitness_center, color: Colors.black26),
                          )
                        else
                          const Icon(Icons.fitness_center, color: Colors.black26),
                        const Positioned(
                          right: 2,
                          bottom: 2,
                          child: Icon(Icons.play_circle_fill_rounded,
                              size: 16, color: AppTheme.lime),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(
                      () => open ? _expanded.remove(i) : _expanded.add(i)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.labelLG.copyWith(
                              color: AppTheme.textPrimary,
                              decoration: done ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 2),
                      Text(
                        '${ex.targetSets}×${ex.targetReps}'
                        '${ex.muscleLabel.isNotEmpty ? ' · ${ex.muscleLabel}' : ''}'
                        '  ·  ${ex.doneSets}/${ex.sets.length} sets',
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              // Mark whole exercise done
              IconButton(
                icon: Icon(
                  done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: done ? AppTheme.lime : AppTheme.textTertiary,
                ),
                onPressed: () => _toggleExercise(i),
              ),
              GestureDetector(
                onTap: () => setState(
                    () => open ? _expanded.remove(i) : _expanded.add(i)),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textTertiary),
                ),
              ),
            ],
          ),
          if (open) _setEditor(i),
        ],
      ),
    );
  }

  Widget _setEditor(int i) {
    final ex = _day.exercises[i];
    return Container(
      color: Colors.white.withValues(alpha: 0.02),
      padding: const EdgeInsets.fromLTRB(AppTheme.md, 4, AppTheme.md, AppTheme.md),
      child: Column(
        children: [
          for (int s = 0; s < ex.sets.length; s++) _setRow(i, s),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _addSet(i),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add set'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _removeExercise(i),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppTheme.error),
                label: const Text('Remove',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setRow(int i, int s) {
    final set = _day.exercises[i].sets[s];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text('Set ${s + 1}',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary)),
          ),
          _numPill('${set.reps}', 'reps', () => _editReps(i, s)),
          const SizedBox(width: AppTheme.sm),
          _numPill(set.weightKg == null ? '–' : _fmt(set.weightKg!), 'kg',
              () => _editWeight(i, s)),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              set.done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: set.done ? AppTheme.lime : AppTheme.textTertiary,
            ),
            onPressed: () => _toggleSet(i, s),
          ),
        ],
      ),
    );
  }

  Widget _numPill(String value, String unit, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          Text(unit,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
        ]),
      ),
    );
  }

  // ── Empty state + add / templates ──────────────────────────────────────────
  Widget _emptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.xl),
          const Icon(Icons.fitness_center_rounded, size: 52, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.md),
          const Text('No workout for this day', style: AppTheme.headingSM),
          const SizedBox(height: AppTheme.sm),
          Text('Add exercises from the library, or start from a template.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: AppTheme.lg),
          _addButton(),
          const SizedBox(height: AppTheme.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('QUICK START',
                style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
          ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.sm,
            children: [for (final t in _templates) _templateChip(t)],
          ),
        ],
      ),
    );
  }

  Widget _templateChip(_WorkoutTemplate t) {
    return GestureDetector(
      onTap: () => _addTemplate(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(t.icon, size: 16, color: AppTheme.lime),
          const SizedBox(width: 6),
          Text(t.name, style: AppTheme.labelMD.copyWith(color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }

  Widget _addButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add exercise'),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _openDemo(RoutineExercise ex) async {
    final catalog = ExerciseCatalog.instance;
    // The catalog is lazy-loaded; make sure it's in memory before we look up
    // the exercise (otherwise byId() returns null and the tap does nothing).
    if (catalog.byId(ex.exerciseId) == null) {
      await catalog.loadAll();
    }
    final full = catalog.byId(ex.exerciseId);
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No demo available for this exercise.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: full)));
  }

  void _toggleSet(int i, int s) {
    final nowDone = !_day.exercises[i].sets[s].done;
    setState(() => _day.exercises[i].sets[s].done = nowDone);
    _save();
    if (nowDone) _startRest(); // auto-start a rest countdown after a set
    _creditStreakIfComplete();
  }

  void _toggleExercise(int i) {
    final ex = _day.exercises[i];
    final makeDone = !ex.completed;
    setState(() {
      for (final s in ex.sets) {
        s.done = makeDone;
      }
    });
    _save();
    _creditStreakIfComplete();
  }

  /// Completing TODAY's workout counts toward the daily streak (once per day).
  Future<void> _creditStreakIfComplete() async {
    if (_day.allDone && _dateOnly(_date) == _dateOnly(DateTime.now())) {
      await StreakService.recordActivity();
    }
  }

  // ── Rest timer ──────────────────────────────────────────────────────────────
  void _startRest([int? seconds]) {
    _restTimer?.cancel();
    setState(() => _restRemaining = seconds ?? _restDefaultSeconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_restRemaining <= 1) {
          _restRemaining = 0;
          t.cancel();
        } else {
          _restRemaining--;
        }
      });
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  Widget _restBar() {
    final mm = (_restRemaining ~/ 60).toString();
    final ss = (_restRemaining % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.md, 0, AppTheme.md, AppTheme.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lime.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.timer_outlined, color: AppTheme.lime, size: 20),
        const SizedBox(width: AppTheme.sm),
        Text('Rest  $mm:$ss',
            style: const TextStyle(
                color: AppTheme.lime,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
        const Spacer(),
        TextButton(
            onPressed: () => _startRest(_restRemaining + 30),
            child: const Text('+30s')),
        TextButton(onPressed: _stopRest, child: const Text('Skip')),
      ]),
    );
  }

  void _addSet(int i) {
    final ex = _day.exercises[i];
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    setState(() => ex.sets.add(SetLog(
        reps: last?.reps ?? ex.targetReps, weightKg: last?.weightKg)));
    _save();
  }

  void _removeExercise(int i) {
    setState(() {
      _day.exercises.removeAt(i);
      _expanded.clear();
    });
    _save();
  }

  Future<void> _editReps(int i, int s) async {
    final v = await _editNumber('Reps', _day.exercises[i].sets[s].reps.toDouble(),
        decimals: 0);
    if (v == null) return;
    setState(() => _day.exercises[i].sets[s].reps = v.round());
    _save();
  }

  Future<void> _editWeight(int i, int s) async {
    final cur = _day.exercises[i].sets[s].weightKg ?? 0;
    final v = await _editNumber('Weight (kg)', cur, decimals: 1);
    if (v == null) return;
    setState(() => _day.exercises[i].sets[s].weightKg = v <= 0 ? null : v);
    _save();
  }

  Future<double?> _editNumber(String title, double initial,
      {int decimals = 0}) async {
    final controller = TextEditingController(
        text: decimals == 0
            ? initial.round().toString()
            : (initial == 0 ? '' : _fmt(initial)));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
          decoration: const InputDecoration(hintText: 'Enter a number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.search_rounded, color: AppTheme.lime),
            title: const Text('From exercise library',
                style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Browse 800+ exercises with demos'),
            onTap: () {
              Navigator.pop(ctx);
              _addFromLibrary();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppTheme.lime),
            title: const Text('Custom exercise',
                style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Add your own by name'),
            onTap: () {
              Navigator.pop(ctx);
              _addCustomExercise();
            },
          ),
          const SizedBox(height: AppTheme.sm),
        ]),
      ),
    );
  }

  Future<void> _addCustomExercise() async {
    final nameCtrl = TextEditingController();
    int sets = 3, reps = 10;
    final result = await showModalBottomSheet<RoutineExercise>(
      context: context,
      backgroundColor: AppTheme.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg,
              AppTheme.lg + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom exercise', style: AppTheme.headingSM),
              const SizedBox(height: AppTheme.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Exercise name (e.g. Cable Fly)'),
              ),
              const SizedBox(height: AppTheme.md),
              _stepper('Sets', sets, (v) => setModal(() => sets = v.clamp(1, 20))),
              const SizedBox(height: AppTheme.sm),
              _stepper('Reps', reps, (v) => setModal(() => reps = v.clamp(1, 100))),
              const SizedBox(height: AppTheme.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      RoutineExercise(
                        exerciseId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        primaryMuscles: const [],
                        targetSets: sets,
                        targetReps: reps,
                        sets: List.generate(sets, (_) => SetLog(reps: reps)),
                      ),
                    );
                  },
                  child: const Text('Add to workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _day.exercises.add(result));
    _save();
  }

  Future<void> _addFromLibrary() async {
    final picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(pickMode: true)),
    );
    if (picked == null || !mounted) return;
    final target = await _askTarget(picked);
    if (target == null) return;
    setState(() => _day.exercises.add(RoutineExercise.fromExercise(
          picked,
          sets: target.sets,
          reps: target.reps,
          weightKg: target.weight,
        )));
    _save();
  }

  Future<_TargetSpec?> _askTarget(Exercise e) {
    int sets = 3, reps = 10;
    double weight = 0;
    return showModalBottomSheet<_TargetSpec>(
      context: context,
      backgroundColor: AppTheme.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg,
              AppTheme.lg + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, style: AppTheme.headingSM),
              const SizedBox(height: AppTheme.lg),
              _stepper('Sets', sets, (v) => setModal(() => sets = v.clamp(1, 20)), step: 1),
              const SizedBox(height: AppTheme.md),
              _stepper('Reps', reps, (v) => setModal(() => reps = v.clamp(1, 100)), step: 1),
              const SizedBox(height: AppTheme.md),
              _stepper('Weight (kg)', weight.round(),
                  (v) => setModal(() => weight = v.toDouble().clamp(0, 500)),
                  step: 5, showValue: weight == 0 ? 'optional' : _fmt(weight)),
              const SizedBox(height: AppTheme.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                      ctx, _TargetSpec(sets, reps, weight <= 0 ? null : weight)),
                  child: const Text('Add to workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged,
      {int step = 1, String? showValue}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary))),
        IconButton(
          onPressed: () => onChanged(value - step),
          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.textSecondary),
        ),
        SizedBox(
          width: 64,
          child: Text(showValue ?? '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        IconButton(
          onPressed: () => onChanged(value + step),
          icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.lime),
        ),
      ],
    );
  }

  Future<void> _addTemplate(_WorkoutTemplate t) async {
    final all = await ExerciseCatalog.instance.loadAll();
    final chosen = <RoutineExercise>[];
    final usedIds = <String>{};
    for (final muscle in t.muscles) {
      final matches = ExerciseCatalog.instance.filter(all, muscle: muscle);
      matches.sort((a, b) => _templateScore(b).compareTo(_templateScore(a)));
      final pick = matches.firstWhere((e) => !usedIds.contains(e.id),
          orElse: () => matches.isNotEmpty ? matches.first : _noExercise);
      if (pick.id.isNotEmpty) {
        usedIds.add(pick.id);
        chosen.add(RoutineExercise.fromExercise(pick, sets: 3, reps: 10));
      }
    }
    if (chosen.isEmpty) return;
    setState(() => _day.exercises.addAll(chosen));
    _save();
  }

  // Prefer common equipment + compound movements for templates.
  int _templateScore(Exercise e) {
    int score = 0;
    const good = {'barbell', 'dumbbell', 'body only', 'cable', 'machine'};
    if (e.equipment != null && good.contains(e.equipment)) score += 2;
    if (e.mechanic == 'compound') score += 2;
    if (e.hasAnimation) score += 1;
    return score;
  }

  static const _noExercise = Exercise(id: '', name: '');

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
