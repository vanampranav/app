import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';

class ParticipantProgressChart extends StatelessWidget {
  final List<ProgressPoint> points;

  const ParticipantProgressChart({Key? key, required this.points}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final bool hasBodyFat = points.any((p) => p.bodyFatPercent != null);
    final bool hasTrends = points.length > 1;

    return EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROGRESS TREND', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
          const SizedBox(height: 24),
          
          if (!hasTrends)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.show_chart_rounded, color: AppTheme.textTertiary, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Your baseline is approved. Submit your first weekly check-in to see progress trends.',
                    style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            // Weight Chart
            const Text('Weight (kg)', style: AppTheme.labelSM),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: _LineChart(
                points: points,
                isWeight: true,
                color: AppTheme.lime,
              ),
            ),
            
            if (hasBodyFat) ...[
              const SizedBox(height: 32),
              const Text('Body Fat (%)', style: AppTheme.labelSM),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: _LineChart(
                  points: points,
                  isWeight: false,
                  color: AppTheme.purpleLight,
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                'Body fat trend will appear once body fat measurements are available.',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<ProgressPoint> points;
  final bool isWeight;
  final Color color;

  const _LineChart({
    required this.points,
    required this.isWeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries.map((entry) {
      final value = isWeight ? entry.value.weightKg : (entry.value.bodyFatPercent ?? 0.0);
      return FlSpot(entry.key.toDouble(), value);
    }).where((spot) => isWeight || spot.y > 0).toList();

    if (spots.isEmpty) return const Center(child: Text('No data'));

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.05;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    points[index].label.replaceAll('Week ', 'W'),
                    style: AppTheme.labelSM.copyWith(fontSize: 8),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary),
                );
              },
              reservedSize: 35,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: AppTheme.bg,
                strokeWidth: 2,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineChartData().lineTouchData.copyWith(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surface2,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)}${isWeight ? " kg" : "%"}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
