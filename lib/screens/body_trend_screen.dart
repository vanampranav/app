import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/body_metrics_catalog.dart';
import '../models/member_model.dart';
import '../theme/app_theme.dart';

/// Plots a single body-composition metric across all of a member's readings
/// over time (line chart). The user can switch which metric is charted.
class BodyTrendScreen extends StatefulWidget {
  final Member member;
  final List<BodyMeasurement> readings;
  final String? initialMetricId;

  const BodyTrendScreen({
    Key? key,
    required this.member,
    required this.readings,
    this.initialMetricId,
  }) : super(key: key);

  @override
  State<BodyTrendScreen> createState() => _BodyTrendScreenState();
}

class _BodyTrendScreenState extends State<BodyTrendScreen> {
  late final List<BodyMetricDef> _metrics;
  late final List<BodyMeasurement> _sorted;
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _metrics = buildBodyMetricsCatalog(widget.member);
    _sorted = [...widget.readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _selectedId = widget.initialMetricId ?? 'weight';
  }

  BodyMetricDef get _metric =>
      _metrics.firstWhere((m) => m.id == _selectedId, orElse: () => _metrics.first);

  /// Readings that actually have a value for the selected metric.
  List<MapEntry<BodyMeasurement, double>> get _points {
    final out = <MapEntry<BodyMeasurement, double>>[];
    for (final r in _sorted) {
      final v = _metric.valueFor(r);
      if (v != null) out.add(MapEntry(r, v));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Trends',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          _metricSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.md, 0, AppTheme.md, AppTheme.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(points),
                  const SizedBox(height: AppTheme.md),
                  _chartCard(points),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricSelector() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
        itemCount: _metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
        itemBuilder: (_, i) {
          final m = _metrics[i];
          final selected = m.id == _selectedId;
          return Center(
            child: ChoiceChip(
              label: Text(m.name),
              selected: selected,
              onSelected: (_) => setState(() => _selectedId = m.id),
              labelStyle: AppTheme.labelMD.copyWith(
                  color: selected ? Colors.black : AppTheme.textSecondary),
              backgroundColor: AppTheme.surface2,
              selectedColor: AppTheme.lime,
              showCheckmark: false,
              side: BorderSide(
                  color: selected
                      ? AppTheme.lime
                      : Colors.white.withValues(alpha: 0.08)),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(List<MapEntry<BodyMeasurement, double>> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final values = points.map((e) => e.value).toList();
    final latest = values.last;
    final first = values.first;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final change = latest - first;

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _summaryStat('Latest', _metric.formatWithUnit(latest), AppTheme.lime),
          _summaryStat(
            'Change',
            '${change >= 0 ? '+' : '−'}${_metric.format(change.abs())}',
            change.abs() < 0.05
                ? AppTheme.textSecondary
                : (change > 0 ? const Color(0xFFE57373) : const Color(0xFF4DB6AC)),
          ),
          _summaryStat('Low', _metric.format(minV), AppTheme.textPrimary),
          _summaryStat('High', _metric.format(maxV), AppTheme.textPrimary),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
        ],
      ),
    );
  }

  Widget _chartCard(List<MapEntry<BodyMeasurement, double>> points) {
    if (points.length < 2) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppTheme.xl),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          'Not enough data to chart ${_metric.name}.\nNeed at least 2 readings that include this metric.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    final values = points.map((e) => e.value).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() < 0.01 ? (maxY.abs() * 0.1 + 1) : (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;

    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
    ];
    final lastX = (points.length - 1).toDouble();
    final labelInterval = lastX <= 4 ? 1.0 : (lastX / 4).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.sm, AppTheme.lg, AppTheme.md, AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: AppTheme.sm, bottom: AppTheme.md),
              child: Text('${_metric.name} over time',
                  style: AppTheme.headingSM),
            ),
          ),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: lastX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.min || v == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return Text(_metric.format(v),
                            style: AppTheme.bodySM
                                .copyWith(color: AppTheme.textTertiary, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: labelInterval,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final idx = v.round();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('M/d').format(points[idx].key.timestamp),
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
                      final p = points[s.x.round()];
                      return LineTooltipItem(
                        '${_metric.formatWithUnit(p.value)}\n${DateFormat('MMM d, yyyy').format(p.key.timestamp)}',
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
                    dotData: FlDotData(
                      show: points.length <= 15,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3,
                        color: AppTheme.lime,
                        strokeWidth: 2,
                        strokeColor: AppTheme.bg,
                      ),
                    ),
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
          ),
        ],
      ),
    );
  }
}
