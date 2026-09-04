import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/body_metrics_catalog.dart';
import '../models/member_model.dart';
import '../theme/app_theme.dart';

/// FitDays-style "Body Data Comparison Report": takes any two body-composition
/// readings and shows every metric with its From → To → change (delta). The
/// whole report can be captured and shared as an image.
class BodyComparisonReportScreen extends StatefulWidget {
  final BodyMeasurement readingA;
  final BodyMeasurement readingB;
  final Member member;

  const BodyComparisonReportScreen({
    Key? key,
    required this.readingA,
    required this.readingB,
    required this.member,
  }) : super(key: key);

  @override
  State<BodyComparisonReportScreen> createState() =>
      _BodyComparisonReportScreenState();
}

class _BodyComparisonReportScreenState
    extends State<BodyComparisonReportScreen> {
  // Directional delta colors (match FitDays: any increase = warm, decrease = cool).
  static const Color _up = Color(0xFFE57373);
  static const Color _down = Color(0xFF4DB6AC);

  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;
  bool _saving = false;

  bool get _busy => _sharing || _saving;

  /// Renders the whole report (even the off-screen part) to PNG bytes.
  Future<Uint8List?> _capturePng() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw 'Report not ready yet';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/elefit_body_comparison.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My EleFit body data comparison',
      );
    } catch (e) {
      _toast('Could not share the report: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _saving = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw 'Report not ready yet';
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'elefit_body_comparison_${DateTime.now().millisecondsSinceEpoch}',
      );
      _toast('Saved to your gallery ✓');
    } on GalException catch (e) {
      _toast('Could not save: ${e.type.message}');
    } catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Order chronologically: `earlier` is the "from" column, `later` the "to".
    final bool aIsEarlier =
        widget.readingA.timestamp.isBefore(widget.readingB.timestamp);
    final earlier = aIsEarlier ? widget.readingA : widget.readingB;
    final later = aIsEarlier ? widget.readingB : widget.readingA;

    final metrics = buildBodyMetricsCatalog(widget.member);
    final days = later.timestamp.difference(earlier.timestamp).inDays.abs();

    final weightDelta = later.weightKg - earlier.weightKg;
    final double? fatDelta =
        (earlier.bodyFatPercent != null && later.bodyFatPercent != null)
            ? later.bodyFatPercent! - earlier.bodyFatPercent!
            : null;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Body Data Comparison Report',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Save to gallery',
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.lime))
                : const Icon(Icons.download_rounded),
            onPressed: _busy ? null : _save,
          ),
          IconButton(
            tooltip: 'Share',
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.lime))
                : const Icon(Icons.ios_share_rounded),
            onPressed: _busy ? null : _share,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: Text(_sharing ? 'Preparing…' : 'Share'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            color: AppTheme.bg,
            padding: const EdgeInsets.fromLTRB(
                AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(days, weightDelta, fatDelta, later),
                const SizedBox(height: AppTheme.md),
                _table(context, metrics, earlier, later),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Values marked "--" weren’t captured for that reading (e.g. manual '
                  'weight entries store fewer metrics than a body-fat scale).',
                  style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                ),
                const SizedBox(height: AppTheme.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.spa_rounded, size: 14, color: AppTheme.lime),
                    const SizedBox(width: 6),
                    Text('EleFit',
                        style: AppTheme.labelMD.copyWith(color: AppTheme.lime)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
      int days, double weightDelta, double? fatDelta, BodyMeasurement later) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.purpleGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(
                  widget.member.nickname.isNotEmpty
                      ? widget.member.nickname[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: AppTheme.lime,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.member.nickname.isEmpty
                            ? 'User'
                            : widget.member.nickname,
                        style:
                            AppTheme.headingSM.copyWith(color: Colors.white)),
                    Text(
                      DateFormat('HH:mm · MMM d, yyyy').format(later.timestamp),
                      style: AppTheme.bodySM
                          .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              _headStat('$days', 'Days', 'Go through', null),
              _headDivider(),
              _headStat(
                weightDelta.abs().toStringAsFixed(2),
                'kg',
                weightDelta >= 0 ? 'Weight gain' : 'Weight loss',
                weightDelta,
              ),
              _headDivider(),
              _headStat(
                fatDelta == null ? '--' : fatDelta.abs().toStringAsFixed(1),
                fatDelta == null ? '' : '%',
                fatDelta == null
                    ? 'Fat change'
                    : (fatDelta >= 0 ? 'Fat gain' : 'Fat loss'),
                fatDelta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headDivider() => Container(
        width: 1,
        height: 42,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _headStat(String value, String unit, String label, double? delta) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(unit,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              if (delta != null && delta.abs() > 0.0001)
                Icon(
                  delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: delta > 0 ? _up : AppTheme.lime,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTheme.bodySM
                  .copyWith(color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, List<BodyMetricDef> metrics,
      BodyMeasurement earlier, BodyMeasurement later) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.md, vertical: AppTheme.sm),
            color: AppTheme.surface2,
            child: Row(
              children: [
                Expanded(
                    flex: 5,
                    child: Text('Index',
                        style: AppTheme.labelMD
                            .copyWith(color: AppTheme.textSecondary))),
                Expanded(
                    flex: 4,
                    child: _colDate(earlier.timestamp)),
                Expanded(
                    flex: 4,
                    child: _colDate(later.timestamp)),
                Expanded(
                    flex: 4,
                    child: Text('Change',
                        textAlign: TextAlign.right,
                        style: AppTheme.labelMD
                            .copyWith(color: AppTheme.textSecondary))),
              ],
            ),
          ),
          for (int i = 0; i < metrics.length; i++)
            _row(metrics[i], earlier, later, i.isOdd),
        ],
      ),
    );
  }

  Widget _colDate(DateTime t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(DateFormat('MMM d').format(t),
            style: AppTheme.labelMD.copyWith(color: AppTheme.textSecondary)),
        Text(DateFormat('yyyy').format(t),
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
      ],
    );
  }

  Widget _row(BodyMetricDef m, BodyMeasurement earlier, BodyMeasurement later,
      bool shaded) {
    final va = m.valueFor(earlier);
    final vb = m.valueFor(later);
    final bool bothPresent = va != null && vb != null;
    final double? delta = bothPresent ? vb - va : null;

    Widget deltaCell;
    if (delta == null) {
      deltaCell = Text('--',
          textAlign: TextAlign.right,
          style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary));
    } else if (delta.abs() < 0.05) {
      deltaCell = Text('0${m.unit.isEmpty ? '' : ' ${m.unit}'}',
          textAlign: TextAlign.right,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.textTertiary));
    } else {
      final up = delta > 0;
      deltaCell = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              '${m.format(delta.abs())}${m.unit.isEmpty ? '' : ' ${m.unit}'}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: up ? _up : _down,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
            ),
          ),
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12, color: up ? _up : _down),
        ],
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 11),
      color: shaded ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(m.name,
                style: AppTheme.bodyMD.copyWith(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 4,
            child: Text('${m.format(va)}${_unitSuffix(m, va)}',
                textAlign: TextAlign.right,
                style:
                    AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
          ),
          Expanded(
            flex: 4,
            child: Text('${m.format(vb)}${_unitSuffix(m, vb)}',
                textAlign: TextAlign.right,
                style: AppTheme.bodyMD.copyWith(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          ),
          Expanded(flex: 4, child: deltaCell),
        ],
      ),
    );
  }

  String _unitSuffix(BodyMetricDef m, double? v) {
    if (v == null || m.unit.isEmpty) return '';
    return ' ${m.unit}';
  }
}
