import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/workout_session.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';

/// Past workouts: a volume (reps × weight) trend chart + a list of logged days.
class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<WorkoutDay> _days = []; // newest first
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await WorkoutService.instance.recentDays(limit: 60);
    if (!mounted) return;
    setState(() {
      _days = days;
      _loading = false;
    });
  }

  DateTime _parse(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Workout History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
          : _days.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.xl),
                  children: [
                    _volumeChart(),
                    const SizedBox(height: AppTheme.lg),
                    Text('${_days.length} workout${_days.length == 1 ? '' : 's'} logged',
                        style: AppTheme.labelMD
                            .copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: AppTheme.sm),
                    for (final d in _days) _dayCard(d),
                  ],
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.history_rounded, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.md),
            const Text('No workouts logged yet', style: AppTheme.headingSM),
            const SizedBox(height: AppTheme.sm),
            Text('Your logged workouts and volume trend will show up here.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
          ]),
        ),
      );

  // ── Volume trend (reps × weight over time) ─────────────────────────────────
  Widget _volumeChart() {
    // Chronological (oldest → newest) days that have any logged volume.
    final chrono = _days.reversed.where((d) => d.volume > 0).toList();
    Widget inner;
    if (chrono.length < 2) {
      inner = SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Log a couple of workouts with weights to see your volume trend.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    } else {
      final spots = <FlSpot>[
        for (int i = 0; i < chrono.length; i++)
          FlSpot(i.toDouble(), chrono[i].volume),
      ];
      double maxY = chrono.map((d) => d.volume).reduce((a, b) => a > b ? a : b);
      maxY = maxY <= 0 ? 1 : maxY * 1.15;
      final lastX = (chrono.length - 1).toDouble();
      final interval = lastX <= 4 ? 1.0 : (lastX / 4).ceilToDouble();
      inner = SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: lastX,
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: interval,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) {
                    final idx = v.round();
                    if (idx < 0 || idx >= chrono.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('M/d').format(_parse(chrono[idx].date)),
                        style: AppTheme.bodySM.copyWith(
                            color: AppTheme.textTertiary, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.surface3,
                getTooltipItems: (spots) => spots.map((s) {
                  final d = chrono[s.x.round()];
                  return LineTooltipItem(
                    '${d.volume.round()} kg vol\n${DateFormat('MMM d').format(_parse(d.date))}',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: AppTheme.lime,
                barWidth: 3,
                dotData: FlDotData(show: chrono.length <= 15),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.lime.withValues(alpha: 0.25),
                      AppTheme.lime.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.sm, AppTheme.lg, AppTheme.md, AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppTheme.sm, bottom: AppTheme.md),
            child: Text('Volume trend (reps × weight)',
                style: AppTheme.headingSM),
          ),
          inner,
        ],
      ),
    );
  }

  Widget _dayCard(WorkoutDay d) {
    final date = _parse(d.date);
    final complete = d.allDone;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(complete ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
              color: complete ? AppTheme.lime : AppTheme.textSecondary, size: 22),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('EEEE, MMM d, yyyy').format(date),
                    style: AppTheme.labelLG
                        .copyWith(color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${d.total} exercise${d.total == 1 ? '' : 's'} · ${d.completedCount}/${d.total} done'
                  '${d.volume > 0 ? ' · ${d.volume.round()} kg vol' : ''}',
                  style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
