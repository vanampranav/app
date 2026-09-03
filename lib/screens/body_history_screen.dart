import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/body_metrics_catalog.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';
import '../theme/app_theme.dart';
import 'body_comparison_report_screen.dart';
import 'body_trend_screen.dart';

/// FitDays-style body-data history: a month calendar showing which days have
/// readings, the readings for the selected day, a per-reading detail sheet, and
/// a "Data comparison" mode to pick any two readings and open the comparison
/// report.
class BodyHistoryScreen extends StatefulWidget {
  const BodyHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BodyHistoryScreen> createState() => _BodyHistoryScreenState();
}

class _BodyHistoryScreenState extends State<BodyHistoryScreen> {
  final MemberService _memberService = MemberService();

  Member? _member;
  List<BodyMeasurement> _all = [];
  final Map<String, List<BodyMeasurement>> _byDay = {};
  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime _selectedDay = _dateOnly(DateTime.now());
  bool _loading = true;

  bool _selectionMode = false;
  final List<BodyMeasurement> _selected = [];

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final member = await _memberService.getActiveMember();
    List<BodyMeasurement> all = [];
    if (member != null) {
      all = await _memberService.getMeasurements(member.id);
    }
    _byDay.clear();
    for (final m in all) {
      _byDay.putIfAbsent(_dayKey(m.timestamp), () => []).add(m);
    }
    // Newest reading first within a day.
    for (final list in _byDay.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final latest = all.isNotEmpty ? all.first.timestamp : DateTime.now();
    if (!mounted) return;
    setState(() {
      _member = member;
      _all = all;
      _selectedDay = _dateOnly(latest);
      _visibleMonth = _monthStart(latest);
      _loading = false;
    });
  }

  List<BodyMeasurement> get _dayReadings => _byDay[_dayKey(_selectedDay)] ?? [];

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  void _toggleSelect(BodyMeasurement m) {
    setState(() {
      final idx = _selected.indexWhere((x) => x.id == m.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else if (_selected.length < 2) {
        _selected.add(m);
      } else {
        // FIFO: replace the earliest-picked so a third tap "just works".
        _selected.removeAt(0);
        _selected.add(m);
      }
    });
  }

  void _openComparison() {
    if (_selected.length != 2 || _member == null) return;
    final sorted = [..._selected]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BodyComparisonReportScreen(
          readingA: sorted.first,
          readingB: sorted.last,
          member: _member!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.lime))
            : Column(
                children: [
                  _topBar(),
                  _weekdayHeader(),
                  _calendar(),
                  const Divider(height: 1),
                  Expanded(child: _dayReadingsList()),
                  _bottomBar(),
                ],
              ),
      ),
    );
  }

  // ── Top bar with month navigation ──────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppTheme.textSecondary),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${DateFormat('MMM').format(_visibleMonth)}.${_visibleMonth.year}',
            style: AppTheme.headingSM,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
            onPressed: () => _changeMonth(1),
          ),
          const Spacer(),
          _all.isNotEmpty
              ? IconButton(
                  tooltip: 'Trends',
                  icon: const Icon(Icons.show_chart_rounded,
                      color: AppTheme.textPrimary, size: 22),
                  onPressed: () => _openTrend(null),
                )
              : const SizedBox(width: 40),
        ],
      ),
    );
  }

  void _openTrend(String? metricId) {
    if (_member == null || _all.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BodyTrendScreen(
          member: _member!,
          readings: _all,
          initialMetricId: metricId,
        ),
      ),
    );
  }

  Widget _weekdayHeader() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: AppTheme.bodySM
                            .copyWith(color: AppTheme.textTertiary)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Month calendar (6 weeks, spillover days dimmed) ────────────────────────
  Widget _calendar() {
    final leadingBlanks = _visibleMonth.weekday % 7; // Sun-first grid
    final gridStart = _visibleMonth.subtract(Duration(days: leadingBlanks));

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sm, vertical: AppTheme.xs),
      child: Column(
        children: List.generate(6, (row) {
          return Row(
            children: List.generate(7, (col) {
              final date = gridStart.add(Duration(days: row * 7 + col));
              return Expanded(child: _dayCell(date));
            }),
          );
        }),
      ),
    );
  }

  Widget _dayCell(DateTime date) {
    final inMonth = date.month == _visibleMonth.month;
    final readings = _byDay[_dayKey(date)] ?? const [];
    final hasData = readings.isNotEmpty;
    final isSelected = _dateOnly(date) == _selectedDay;
    // Representative value = latest reading that day.
    final repWeight = hasData ? readings.first.weightKg : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = _dateOnly(date);
          if (!inMonth) _visibleMonth = _monthStart(date);
        });
      },
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: hasData && !isSelected
              ? Border.all(color: AppTheme.lime.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.black
                    : inMonth
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
              ),
            ),
            if (repWeight != null)
              Text(
                repWeight.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.7)
                      : AppTheme.lime,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Readings list for the selected day ─────────────────────────────────────
  Widget _dayReadingsList() {
    if (_all.isEmpty) {
      return _emptyState(
        Icons.monitor_weight_outlined,
        'No weight readings yet',
        'Step on your connected scale or add a manual entry to start tracking.',
      );
    }
    final readings = _dayReadings;
    if (readings.isEmpty) {
      return _emptyState(
        Icons.event_busy_rounded,
        'No readings on ${DateFormat('MMM d, yyyy').format(_selectedDay)}',
        'Pick another day on the calendar above.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.md, AppTheme.md, AppTheme.md, AppTheme.sm),
      itemCount: readings.length,
      itemBuilder: (_, i) => _readingCard(readings[i]),
    );
  }

  Widget _readingCard(BodyMeasurement m) {
    final selectedIdx = _selected.indexWhere((x) => x.id == m.id);
    final isSelected = selectedIdx >= 0;

    IconData icon;
    final h = m.timestamp.hour;
    if (h < 12) {
      icon = Icons.wb_sunny_outlined;
    } else if (h < 17) {
      icon = Icons.wb_twilight;
    } else {
      icon = Icons.nightlight_round;
    }

    return GestureDetector(
      onTap: () => _selectionMode ? _toggleSelect(m) : _showReadingDetail(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md, vertical: AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppTheme.lime
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_selectionMode) ...[
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.lime : AppTheme.textTertiary,
                size: 22,
              ),
              const SizedBox(width: AppTheme.sm),
            ],
            Column(
              children: [
                Icon(icon, color: AppTheme.textSecondary, size: 20),
                const SizedBox(height: 4),
                Text(DateFormat('HH:mm').format(m.timestamp),
                    style: AppTheme.bodySM
                        .copyWith(color: AppTheme.textTertiary)),
              ],
            ),
            const SizedBox(width: AppTheme.md),
            Container(
                width: 1, height: 34, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(width: AppTheme.md),
            Expanded(child: _quickStat(m.weightKg.toStringAsFixed(2), 'kg', 'Weight')),
            Expanded(
                child: _quickStat(
                    m.bmi?.toStringAsFixed(1) ?? '--', '', 'BMI')),
            Expanded(
                child: _quickStat(
                    m.bodyFatPercent?.toStringAsFixed(1) ?? '--', '%', 'Body Fat')),
            if (!_selectionMode)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _quickStat(String value, String unit, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text(unit,
                    style: AppTheme.bodySM
                        .copyWith(color: AppTheme.textSecondary)),
              ),
          ],
        ),
        Text(label,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.md),
            Text(title,
                textAlign: TextAlign.center, style: AppTheme.headingSM),
            const SizedBox(height: AppTheme.sm),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMD
                    .copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar: compare CTA / selection summary ────────────────────────────
  Widget _bottomBar() {
    if (!_selectionMode) {
      final canCompare = _all.length >= 2;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.md),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canCompare
                  ? () => setState(() {
                        _selectionMode = true;
                        _selected.clear();
                      })
                  : null,
              icon: const Icon(Icons.compare_arrows_rounded, size: 20),
              label: Text(canCompare
                  ? 'Data comparison'
                  : 'Need at least 2 readings to compare'),
            ),
          ),
        ),
      );
    }

    // Selection mode summary
    final a = _selected.isNotEmpty ? _selected[0] : null;
    final b = _selected.length > 1 ? _selected[1] : null;
    String middle = '· · ·';
    if (a != null && b != null) {
      final days = a.timestamp.difference(b.timestamp).inDays.abs();
      middle = '$days ${days == 1 ? 'Day' : 'Days'}';
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.md, AppTheme.md, AppTheme.md, AppTheme.md),
        decoration: const BoxDecoration(
          color: AppTheme.surface1,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _selSummary(a)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm),
                  child: Text(middle,
                      style: AppTheme.labelMD.copyWith(
                          color: _selected.length == 2
                              ? AppTheme.lime
                              : AppTheme.textTertiary)),
                ),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: _selSummary(b))),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _selectionMode = false;
                      _selected.clear();
                    }),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _selected.length == 2 ? _openComparison : null,
                    child: const Text('Comparison'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selSummary(BodyMeasurement? m) {
    if (m == null) {
      return Text('Not selected',
          style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${m.weightKg.toStringAsFixed(2)} kg',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
        Text(DateFormat('HH:mm MMM d').format(m.timestamp),
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
      ],
    );
  }

  // ── Single-reading detail sheet (all metrics) ──────────────────────────────
  void _showReadingDetail(BodyMeasurement m) {
    if (_member == null) return;
    final metrics = buildBodyMetricsCatalog(_member!);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.lg, 0, AppTheme.lg, AppTheme.xl),
              children: [
                Text(DateFormat('EEEE, MMM d, yyyy · HH:mm')
                    .format(m.timestamp),
                    style: AppTheme.headingSM),
                const SizedBox(height: 4),
                Text('Tap a metric to see its trend over time',
                    style: AppTheme.bodySM
                        .copyWith(color: AppTheme.textTertiary)),
                const SizedBox(height: AppTheme.md),
                for (final metric in metrics)
                  _detailRow(metric, m, () {
                    Navigator.pop(sheetCtx);
                    _openTrend(metric.id);
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(BodyMetricDef metric, BodyMeasurement m, VoidCallback onTap) {
    final v = metric.valueFor(m);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Flexible(
                  child: Text(metric.name,
                      style: AppTheme.bodyMD
                          .copyWith(color: AppTheme.textPrimary)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.show_chart_rounded,
                    size: 13, color: AppTheme.textTertiary),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(metric.formatWithUnit(v),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (metric.hasBands && v != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: metric.colorFor(v), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(metric.labelFor(v),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySM
                            .copyWith(color: AppTheme.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
