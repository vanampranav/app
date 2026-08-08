import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/health_service.dart';
import 'settings_screen.dart';
import 'devices_screen.dart';

// ── Metric colours ─────────────────────────────────────────────────────────────
const _kStepsColor    = Color(0xFF5B9CF6);
const _kCaloriesColor = Color(0xFFFF6B35);
const _kExerciseColor = Color(0xFFC8DA2B); // lime
const _kSleepColor    = Color(0xFF7B68EE);
const _kHRColor       = Color(0xFFFF4757);
const _kHRVColor      = Color(0xFF00D2D3);
const _kWeightColor   = Color(0xFFC8DA2B); // lime

// ── Snapshot ───────────────────────────────────────────────────────────────────
class _Snapshot {
  final int stepsToday;
  final double? activeCalories;
  final bool caloriesEstimated; // true when derived from steps, not read from Health
  final double? distanceKm;
  final int? workoutMinutes;
  final double? restingHR;
  final List<double?> hrv7Days;
  final Duration sleepLastNight;
  final Map<String, double> sleepStages;
  final List<Map<String, dynamic>> weightHistory;
  final List<int> weeklySteps;

  const _Snapshot({
    required this.stepsToday,
    required this.activeCalories,
    this.caloriesEstimated = false,
    required this.distanceKm,
    required this.workoutMinutes,
    required this.restingHR,
    required this.hrv7Days,
    required this.sleepLastNight,
    required this.sleepStages,
    required this.weightHistory,
    required this.weeklySteps,
  });

  bool get hasActivityData =>
      stepsToday > 0 || activeCalories != null || workoutMinutes != null;
  bool get hasHeartData =>
      restingHR != null || hrv7Days.any((v) => v != null);
  bool get hasSleepData => sleepLastNight.inMinutes > 10;
  bool get hasWeightData => weightHistory.isNotEmpty;
  bool get hasWeeklySteps => weeklySteps.any((s) => s > 0);

  // Day Score 0-100 — weighted from available data only
  int get dayScore {
    double score = 0, weight = 0;
    const stepsGoal = 8000, calGoal = 500.0, sleepGoal = 8.0;
    if (stepsToday > 0) {
      score  += (stepsToday / stepsGoal).clamp(0.0, 1.0) * 40;
      weight += 40;
    }
    if (activeCalories != null) {
      score  += (activeCalories! / calGoal).clamp(0.0, 1.0) * 25;
      weight += 25;
    }
    if (sleepLastNight.inMinutes > 10) {
      score  += (sleepLastNight.inMinutes / 60 / sleepGoal).clamp(0.0, 1.0) * 35;
      weight += 35;
    }
    if (weight == 0) return 0;
    return (score / weight * 100).round().clamp(0, 100);
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({Key? key}) : super(key: key);
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with SingleTickerProviderStateMixin {
  bool _loading         = true;
  bool _connected       = false;
  bool _connectingHealth = false;
  _Snapshot? _snap;
  DateTime _selectedDate = DateTime.now();

  late final AnimationController _animCtrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
           _selectedDate.month == now.month &&
           _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.lime,
            onPrimary: Colors.black,
            surface: AppTheme.surface1,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final connected = await HealthService().isConnected;
    if (!connected) {
      if (mounted) setState(() { _connected = false; _loading = false; });
      return;
    }

    final date = _isToday ? null : _selectedDate;

    final results = await Future.wait([
      HealthService().fetchTodaySteps(date: date),
      HealthService().fetchTodayActiveCalories(date: date),
      HealthService().fetchTodayDistance(date: date),
      HealthService().fetchTodayWorkoutMinutes(date: date),
      HealthService().fetchRestingHeartRate(date: date),
      HealthService().fetchHRV7Days(date: date),
      HealthService().fetchSleepLastNight(date: date),
      HealthService().fetchSleepStagesLastNight(date: date),
      HealthService().fetchWeightHistory(
          _selectedDate.subtract(const Duration(days: 30))),
      HealthService().fetchWeeklySteps(date: date),
    ]);

    // Steps come free from the device, but active calories only exist in Health
    // if a wearable / fitness app writes them. When there's no such data, fall
    // back to a step-based estimate so the ring isn't stuck on 0.
    final steps = results[0] as int;
    final fetchedCalories = results[1] as double?;
    bool caloriesEstimated = false;
    double? effectiveCalories = fetchedCalories;
    if ((fetchedCalories == null || fetchedCalories <= 0) && steps > 0) {
      effectiveCalories = await HealthService().estimateActiveCaloriesFromSteps(steps);
      caloriesEstimated = effectiveCalories > 0;
    }

    final snap = _Snapshot(
      stepsToday:      steps,
      activeCalories:  effectiveCalories,
      caloriesEstimated: caloriesEstimated,
      distanceKm:      results[2] as double?,
      workoutMinutes:  results[3] as int?,
      restingHR:       results[4] as double?,
      hrv7Days:        results[5] as List<double?>,
      sleepLastNight:  results[6] as Duration,
      sleepStages:     results[7] as Map<String, double>,
      weightHistory:   results[8] as List<Map<String, dynamic>>,
      weeklySteps:     results[9] as List<int>,
    );

    if (mounted) {
      setState(() {
        _connected = true;
        _snap      = snap;
        _loading   = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _loading
            ? _buildLoader()
            : RefreshIndicator(
                color: AppTheme.lime,
                backgroundColor: AppTheme.surface1,
                onRefresh: _load,
                child: !_connected
                    ? _buildEmptyState()
                    : _buildContent(),
              ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
        child: CircularProgressIndicator(color: AppTheme.lime, strokeWidth: 2),
      );

  Widget _buildEmptyState() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.monitor_heart_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 24),
          Text('Your Performance\nDashboard',
              style: AppTheme.displayMD
                  .copyWith(height: 1.15, color: AppTheme.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Connect Apple Health or Health Connect to unlock '
            'step counts, sleep, heart rate, and recovery insights.',
            style: AppTheme.bodyMD.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _connectingHealth
                ? null
                : () async {
                    setState(() => _connectingHealth = true);
                    final ok = await HealthService().requestPermissions();
                    if (!mounted) return;
                    setState(() => _connectingHealth = false);
                    if (ok) {
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Health access was not granted. Please allow it in your device Settings.'),
                          backgroundColor: Color(0xFF2A2A2A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.lime,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppTheme.lime.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _connectingHealth
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5))
                : const Text('Connect Health',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _connectingHealth
                ? null
                : () async {
                    setState(() => _connectingHealth = true);
                    final ok = await HealthService().checkPermissions();
                    if (!mounted) return;
                    setState(() => _connectingHealth = false);
                    if (ok) {
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No health connection found. Tap "Connect Health" to set it up.'),
                          backgroundColor: Color(0xFF2A2A2A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            child: Text('Already connected? Re-check',
                style: TextStyle(color: AppTheme.lime.withValues(alpha: 0.8))),
          ),
        ],
      );

  Widget _buildContent() {
    final s = _snap!;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildDayScore(s)),
        if (s.hasActivityData)
          SliverToBoxAdapter(child: _buildActivityRings(s)),
        SliverToBoxAdapter(child: _buildMetricsGrid(s)),
        if (s.hasWeightData)
          SliverToBoxAdapter(child: _buildBodyComposition(s)),
        if (s.hasHeartData)
          SliverToBoxAdapter(child: _buildHeartRecovery(s)),
        if (s.hasSleepData)
          SliverToBoxAdapter(child: _buildSleep(s)),
        if (s.hasWeeklySteps)
          SliverToBoxAdapter(child: _buildWeeklySteps(s)),
        SliverToBoxAdapter(child: _buildConnectedDevices()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final label  = '${days[_selectedDate.weekday - 1]}, '
                   '${_selectedDate.day} ${months[_selectedDate.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text('Performance',
              style: AppTheme.headingLG
                  .copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const Spacer(),
          if (!_isToday)
            GestureDetector(
              onTap: () {
                setState(() => _selectedDate = DateTime.now());
                _load();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Today',
                    style: TextStyle(
                        color: AppTheme.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppTheme.bodyMD.copyWith(
                        color: _isToday
                            ? AppTheme.textTertiary
                            : AppTheme.lime)),
                const SizedBox(width: 4),
                Icon(Icons.calendar_month_rounded,
                    size: 15,
                    color: _isToday ? AppTheme.textTertiary : AppTheme.lime),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Day Score ────────────────────────────────────────────────────────────────

  Widget _buildDayScore(_Snapshot s) {
    final score  = s.dayScore;
    final color  = _scoreColor(score);
    final label  = _scoreLabel(score);

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(children: [
        _SectionLabel('DAY SCORE'),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => SizedBox(
            width: 120, height: 120,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                progress: _anim.value * score / 100,
                color: color,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(score * _anim.value).round()}',
                      style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -2),
                    ),
                    Text('/100',
                        style: AppTheme.bodyMD
                            .copyWith(color: AppTheme.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.lime;
    if (score >= 55) return _kHRVColor;
    if (score >= 35) return const Color(0xFFFFB347);
    return _kCaloriesColor;
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Excellent day 🔥';
    if (score >= 55) return 'Good day — keep pushing';
    if (score >= 35) return 'Room to improve';
    return 'Rest and recover';
  }

  // ── Activity Rings ────────────────────────────────────────────────────────────

  Widget _buildActivityRings(_Snapshot s) {
    const stepsGoal    = 10000;
    const caloriesGoal = 600;
    const exerciseGoal = 30;

    final stepsPct    = s.stepsToday / stepsGoal;
    final calPct      = (s.activeCalories ?? 0) / caloriesGoal;
    final exercisePct = (s.workoutMinutes ?? 0) / exerciseGoal;

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(children: [
        _SectionLabel('ACTIVITY'),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => SizedBox(
            width: 150, height: 150,
            child: CustomPaint(
              painter: _ActivityRingsPainter(
                outerProgress:  _anim.value * stepsPct,
                middleProgress: _anim.value * calPct,
                innerProgress:  _anim.value * exercisePct,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _RingLegend(_kStepsColor, 'Steps',
              '${_fmt(s.stepsToday)} / ${_fmt(stepsGoal)}'),
          _RingLegend(_kCaloriesColor, s.caloriesEstimated ? 'Calories (est.)' : 'Calories',
              '${(s.activeCalories ?? 0).round()} / $caloriesGoal kcal'),
          _RingLegend(_kExerciseColor, 'Exercise',
              '${s.workoutMinutes ?? 0} / $exerciseGoal min'),
        ]),
      ]),
    );
  }

  // ── Metrics Grid ──────────────────────────────────────────────────────────────

  Widget _buildMetricsGrid(_Snapshot s) {
    final cards = <Widget>[];

    if (s.stepsToday > 0) {
      cards.add(_MetricCard(
        color: _kStepsColor,
        icon: Icons.directions_walk_rounded,
        value: _fmt(s.stepsToday),
        label: 'STEPS',
        bottom: _ProgressBar(
            value: s.stepsToday / 10000, color: _kStepsColor),
      ));
    }
    if (s.activeCalories != null) {
      cards.add(_MetricCard(
        color: _kCaloriesColor,
        icon: Icons.local_fire_department_rounded,
        value: '${s.activeCalories!.round()}',
        label: s.caloriesEstimated ? 'CAL BURNED · EST' : 'CAL BURNED',
        bottom: _ProgressBar(
            value: s.activeCalories! / 600, color: _kCaloriesColor),
      ));
    }
    if (s.sleepLastNight.inMinutes > 10) {
      final h = s.sleepLastNight.inHours;
      final m = s.sleepLastNight.inMinutes % 60;
      cards.add(_MetricCard(
        color: _kSleepColor,
        icon: Icons.bedtime_rounded,
        value: '${h}h ${m}m',
        label: 'SLEEP',
        bottom: _StatusBadge(
            label: h >= 7 ? 'Good' : 'Short',
            good: h >= 7),
      ));
    }
    if (s.restingHR != null) {
      final hr = s.restingHR!.round();
      final good = hr >= 50 && hr <= 75;
      cards.add(_MetricCard(
        color: _kHRColor,
        icon: Icons.favorite_rounded,
        value: '$hr bpm',
        label: 'RESTING HR',
        bottom: _StatusBadge(label: good ? 'Optimal' : 'Elevated', good: good),
      ));
    }
    if (s.distanceKm != null) {
      cards.add(_MetricCard(
        color: _kStepsColor,
        icon: Icons.straighten_rounded,
        value: '${s.distanceKm!.toStringAsFixed(1)} km',
        label: 'DISTANCE',
        bottom: const SizedBox.shrink(),
      ));
    }
    if (s.workoutMinutes != null && s.workoutMinutes! > 0) {
      cards.add(_MetricCard(
        color: _kExerciseColor,
        icon: Icons.fitness_center_rounded,
        value: '${s.workoutMinutes} min',
        label: 'WORKOUT',
        bottom: _ProgressBar(
            value: s.workoutMinutes! / 60, color: _kExerciseColor),
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    // 2-column grid
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: cards[i]),
        const SizedBox(width: 12),
        Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
      ]));
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 12));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('TODAY'),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  // ── Body Composition ──────────────────────────────────────────────────────────

  Widget _buildBodyComposition(_Snapshot s) {
    // Sort a copy — never mutate the snapshot list
    final history = [...s.weightHistory]
      ..sort((a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(),
          (e.value['weight'] as double));
    }).toList();

    final latest  = history.last['weight'] as double;
    final oldest  = history.first['weight'] as double;
    final delta   = latest - oldest;
    final deltaStr = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg';
    final minY = spots.map((s) => s.y).reduce(math.min) - 1.5;
    final maxY = spots.map((s) => s.y).reduce(math.max) + 1.5;

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel('BODY COMPOSITION'),
        const SizedBox(height: 4),
        Text('Last ${history.length} readings',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textTertiary,
                fontSize: 11)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toStringAsFixed(1)} kg',
                          const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: _kWeightColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, _) =>
                      spot.x == spots.last.x,
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(
                          radius: 5,
                          color: _kWeightColor,
                          strokeWidth: 2,
                          strokeColor: AppTheme.surface1),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _kWeightColor.withValues(alpha: 0.25),
                      _kWeightColor.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _StatPill(label: 'Current',
              value: '${latest.toStringAsFixed(1)} kg',
              color: _kWeightColor),
          const SizedBox(width: 10),
          _StatPill(label: '30-day',
              value: deltaStr,
              color: delta <= 0 ? AppTheme.lime : _kHRColor),
        ]),
      ]),
    );
  }

  // ── Heart & Recovery ──────────────────────────────────────────────────────────

  Widget _buildHeartRecovery(_Snapshot s) {
    final hasHRV = s.hrv7Days.any((v) => v != null);
    final hrvSpots = <FlSpot>[];
    if (hasHRV) {
      for (int i = 0; i < s.hrv7Days.length; i++) {
        if (s.hrv7Days[i] != null) {
          hrvSpots.add(FlSpot(i.toDouble(), s.hrv7Days[i]!));
        }
      }
    }

    String recoveryLabel = 'No data';
    Color recoveryColor  = AppTheme.textTertiary;
    if (s.restingHR != null && hasHRV) {
      final hr  = s.restingHR!;
      final hrv = s.hrv7Days.whereType<double>().last;
      if (hr <= 65 && hrv >= 50) {
        recoveryLabel = 'Well Recovered';
        recoveryColor = AppTheme.lime;
      } else if (hr <= 75 && hrv >= 30) {
        recoveryLabel = 'Moderate';
        recoveryColor = const Color(0xFFFFB347);
      } else {
        recoveryLabel = 'Under-Recovered';
        recoveryColor = _kHRColor;
      }
    } else if (s.restingHR != null) {
      final hr = s.restingHR!;
      recoveryLabel = hr <= 70 ? 'Resting HR Optimal' : 'Elevated HR';
      recoveryColor = hr <= 70 ? AppTheme.lime : _kHRColor;
    }

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _SectionLabel('HEART & RECOVERY'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: recoveryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(recoveryLabel,
                style: TextStyle(
                    color: recoveryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasHRV) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HRV — 7 days',
                      style: AppTheme.bodyMD.copyWith(
                          fontSize: 11,
                          color: AppTheme.textTertiary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: LineChart(LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData:
                          const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: hrvSpots,
                          isCurved: true,
                          color: _kHRVColor,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _kHRVColor.withValues(alpha: 0.25),
                                _kHRVColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${hrvSpots.last.y.round()} ms avg',
                    style: TextStyle(
                        color: _kHRVColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (s.restingHR != null) ...[
              const SizedBox(width: 20),
              const VerticalDivider(
                  width: 1, color: AppTheme.divider),
              const SizedBox(width: 20),
            ],
          ],
          if (s.restingHR != null)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Resting HR',
                  style: AppTheme.bodyMD
                      .copyWith(fontSize: 11, color: AppTheme.textTertiary)),
              const SizedBox(height: 8),
              Text('${s.restingHR!.round()}',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: _kHRColor)),
              Text('bpm',
                  style: AppTheme.bodyMD.copyWith(
                      color: AppTheme.textTertiary, fontSize: 11)),
            ]),
        ]),
      ]),
    );
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────────

  Widget _buildSleep(_Snapshot s) {
    final h = s.sleepLastNight.inHours;
    final m = s.sleepLastNight.inMinutes % 60;

    final stages    = s.sleepStages;
    final hasStages = stages.isNotEmpty;
    final totalMins = hasStages
        ? stages.values.reduce((a, b) => a + b)
        : s.sleepLastNight.inMinutes.toDouble();

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel('SLEEP'),
        const SizedBox(height: 16),
        Row(children: [
          Text('${h}h ${m}m',
              style: AppTheme.displayMD.copyWith(
                  color: _kSleepColor, letterSpacing: -1)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (h >= 7 ? AppTheme.lime : _kCaloriesColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              h >= 8 ? 'Excellent' : h >= 7 ? 'Good' : h >= 6 ? 'Short' : 'Poor',
              style: TextStyle(
                  color: h >= 7 ? AppTheme.lime : _kCaloriesColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        if (hasStages) ...[
          const SizedBox(height: 16),
          Text('Sleep stages',
              style: AppTheme.bodyMD
                  .copyWith(fontSize: 11, color: AppTheme.textTertiary)),
          const SizedBox(height: 8),
          // Stage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(children: [
                if (stages['deep'] != null)
                  _StageBar(stages['deep']! / totalMins,
                      const Color(0xFF4B3F9E)),
                if (stages['rem'] != null)
                  _StageBar(stages['rem']! / totalMins,
                      _kSleepColor),
                if (stages['light'] != null)
                  _StageBar(stages['light']! / totalMins,
                      const Color(0xFF9B8FE0)),
                if (stages['awake'] != null)
                  _StageBar(stages['awake']! / totalMins,
                      AppTheme.surface3),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 6, children: [
            if (stages['deep']  != null)
              _StageLegend('Deep',  _minToStr(stages['deep']!),
                  const Color(0xFF4B3F9E)),
            if (stages['rem']   != null)
              _StageLegend('REM',   _minToStr(stages['rem']!),   _kSleepColor),
            if (stages['light'] != null)
              _StageLegend('Light', _minToStr(stages['light']!),
                  const Color(0xFF9B8FE0)),
            if (stages['awake'] != null)
              _StageLegend('Awake', _minToStr(stages['awake']!), AppTheme.textTertiary),
          ]),
        ],
      ]),
    );
  }

  // ── Weekly Steps ──────────────────────────────────────────────────────────────

  Widget _buildWeeklySteps(_Snapshot s) {
    const stepsGoal = 8000;
    final maxVal = [...s.weeklySteps, stepsGoal]
        .reduce(math.max)
        .toDouble() * 1.2;

    final now   = DateTime.now();
    final days  = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return ['M','T','W','T','F','S','S'][d.weekday - 1];
    });

    final weekAvg = s.weeklySteps.where((v) => v > 0).isEmpty
        ? 0
        : s.weeklySteps.reduce((a, b) => a + b) ~/
            s.weeklySteps.where((v) => v > 0).length;

    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _SectionLabel('THIS WEEK'),
          const Spacer(),
          Text('avg ${_fmt(weekAvg)} steps/day',
              style: AppTheme.bodyMD
                  .copyWith(fontSize: 11, color: AppTheme.textTertiary)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal,
            barGroups: s.weeklySteps.asMap().entries.map((e) {
              final met = e.value >= stepsGoal;
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value.toDouble().clamp(1, maxVal),
                  gradient: met
                      ? LinearGradient(
                          colors: [
                            _kStepsColor,
                            _kStepsColor.withValues(alpha: 0.6)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: met ? null : AppTheme.surface3,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                ),
              ]);
            }).toList(),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: stepsGoal.toDouble(),
                color: _kStepsColor.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'goal',
                  style: TextStyle(
                      color: _kStepsColor.withValues(alpha: 0.7),
                      fontSize: 10),
                ),
              ),
            ]),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt() < days.length ? days[v.toInt()] : '',
                    style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData:   const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          )),
        ),
      ]),
    );
  }

  // ── Connected Devices ─────────────────────────────────────────────────────────

  Widget _buildConnectedDevices() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel('CONNECTED DEVICES'),
        const SizedBox(height: 14),
        _DeviceTile(
          icon: Icons.favorite_rounded,
          iconColor: _kHRColor,
          name: 'Apple Health / Health Connect',
          status: 'Connected · syncing 9 data types',
          statusColor: AppTheme.lime,
          onTap: () => HealthService().openHealthApp(),
        ),
        const Divider(height: 20, color: AppTheme.divider),
        _DeviceTile(
          icon: Icons.monitor_weight_rounded,
          iconColor: _kWeightColor,
          name: 'FitDays Scale',
          status: 'Tap to scan & connect',
          statusColor: AppTheme.textTertiary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DevicesScreen())),
        ),
        const Divider(height: 20, color: AppTheme.divider),
        InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.settings_outlined,
                  size: 16, color: AppTheme.textTertiary),
              const SizedBox(width: 8),
              Text('Manage connected apps in Settings',
                  style: AppTheme.bodyMD
                      .copyWith(fontSize: 12, color: AppTheme.textTertiary)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _fmt(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k == k.roundToDouble() ? k.round() : k.toStringAsFixed(1)}k';
    }
    return '$v';
  }

  String _minToStr(double mins) {
    final h = mins ~/ 60;
    final m = mins.round() % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

// ── Custom Painters ────────────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 10;

    final bgPaint = Paint()
      ..color      = color.withValues(alpha: 0.12)
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap  = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    final fgPaint = Paint()
      ..color      = color
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap  = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter o) =>
      o.progress != progress || o.color != color;
}

class _ActivityRingsPainter extends CustomPainter {
  final double outerProgress;
  final double middleProgress;
  final double innerProgress;

  const _ActivityRingsPainter({
    required this.outerProgress,
    required this.middleProgress,
    required this.innerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    const stroke = 16.0;
    const gap    = 10.0;

    void drawRing(double radius, Color color, double progress) {
      final bgPaint = Paint()
        ..color       = color.withValues(alpha: 0.15)
        ..style       = PaintingStyle.stroke
        ..strokeWidth  = stroke
        ..strokeCap   = StrokeCap.round;
      canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

      if (progress <= 0) return;
      final fgPaint = Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeWidth  = stroke
        ..strokeCap   = StrokeCap.round;

      // Draw shadow/glow
      final glowPaint = Paint()
        ..color        = color.withValues(alpha: 0.3)
        ..style        = PaintingStyle.stroke
        ..strokeWidth  = stroke + 6
        ..strokeCap    = StrokeCap.round
        ..maskFilter   = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.3),
        false, glowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.3),
        false, fgPaint,
      );
    }

    final outerR  = math.min(cx, cy) - stroke / 2;
    final middleR = outerR  - stroke - gap;
    final innerR  = middleR - stroke - gap;

    drawRing(outerR,  _kStepsColor,    outerProgress);
    drawRing(middleR, _kCaloriesColor, middleProgress);
    drawRing(innerR,  _kExerciseColor, innerProgress);
  }

  @override
  bool shouldRepaint(_ActivityRingsPainter o) =>
      o.outerProgress != outerProgress ||
      o.middleProgress != middleProgress ||
      o.innerProgress  != innerProgress;
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  const _Card({required this.child, this.margin});

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? EdgeInsets.zero,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textTertiary,
            letterSpacing: 1.2),
      );
}

class _MetricCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;
  final Widget bottom;
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                    letterSpacing: 1.0)),
            const SizedBox(height: 10),
            bottom,
          ],
        ),
      );
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color  color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 4,
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool   good;
  const _StatusBadge({required this.label, required this.good});

  @override
  Widget build(BuildContext context) {
    final c = good ? AppTheme.lime : _kHRColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _RingLegend extends StatelessWidget {
  final Color  color;
  final String label;
  final String value;
  const _RingLegend(this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 3),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StageBar extends StatelessWidget {
  final double fraction;
  final Color  color;
  const _StageBar(this.fraction, this.color);

  @override
  Widget build(BuildContext context) => Flexible(
        flex: (fraction * 1000).round(),
        child: Container(color: color),
      );
}

class _StageLegend extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StageLegend(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text('$label ',
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]);
}

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   name;
  final String   status;
  final Color    statusColor;
  final VoidCallback onTap;
  const _DeviceTile({
    required this.icon, required this.iconColor,
    required this.name, required this.status,
    required this.statusColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(status,
                  style: TextStyle(
                      fontSize: 12,
                      color: statusColor)),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 20),
        ]),
      );
}
