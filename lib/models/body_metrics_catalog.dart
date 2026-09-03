import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'member_model.dart';

/// A colored health band for a metric segment (e.g. "Standard" 18.5–25 for BMI).
class MetricBand {
  final String label;
  final double? min;
  final double? max;
  final Color color;
  const MetricBand({
    required this.label,
    this.min,
    this.max,
    required this.color,
  });
}

/// Definition of a single body-composition metric, evaluated against ANY
/// [BodyMeasurement] (not just the latest). This mirrors the health-range bands
/// used by MeasurementScreen, but reads from the PERSISTED model so it works for
/// historical readings and the FitDays-style two-reading comparison.
///
/// The kg-mass metrics (fat mass, lean mass, muscle mass, water weight, protein
/// mass) are NOT stored per reading, so they are recomputed here from that
/// reading's own weight × its stored percentage — which keeps each reading's
/// derived values self-consistent when comparing two dates.
class BodyMetricDef {
  final String id;
  final String name;
  final String unit;
  final int decimals;
  final double? Function(BodyMeasurement m) read;
  final List<MetricBand> bands;

  const BodyMetricDef({
    required this.id,
    required this.name,
    required this.unit,
    required this.decimals,
    required this.read,
    this.bands = const [],
  });

  double? valueFor(BodyMeasurement m) => read(m);

  /// Formatted value, e.g. "53.45" or "--" when the reading lacks this metric.
  String format(double? v) => v == null ? '--' : v.toStringAsFixed(decimals);

  /// Value + unit, e.g. "53.45 kg".
  String formatWithUnit(double? v) {
    if (v == null) return '--';
    return unit.isEmpty ? format(v) : '${format(v)} $unit';
  }

  MetricBand? bandFor(double? v) {
    if (v == null) return null;
    for (final b in bands) {
      final min = b.min ?? double.negativeInfinity;
      final max = b.max ?? double.infinity;
      if (v >= min && v < max) return b;
    }
    return null;
  }

  Color colorFor(double? v) => bandFor(v)?.color ?? AppTheme.textTertiary;
  String labelFor(double? v) => bandFor(v)?.label ?? '--';
  bool get hasBands => bands.isNotEmpty;
}

// ── Band colors (kept consistent with MeasurementScreen) ─────────────────────
const Color _cLow = Color(0xFF4FC3F7);
const Color _cStd = Color(0xFF81C784);
const Color _cWarn = Color(0xFFFFB74D);
const Color _cHigh = Color(0xFFE57373);
const Color _cExc = Color(0xFF4DB6AC);

List<MetricBand> _bmrBands(bool isMale, int age) {
  double threshold;
  if (isMale) {
    if (age < 30) {
      threshold = 1600;
    } else if (age < 50) {
      threshold = 1500;
    } else {
      threshold = 1350;
    }
  } else {
    if (age < 30) {
      threshold = 1300;
    } else if (age < 50) {
      threshold = 1200;
    } else {
      threshold = 1100;
    }
  }
  return [
    MetricBand(label: 'Low', min: 0, max: threshold, color: _cLow),
    MetricBand(label: 'Excellent', min: threshold, max: 10000, color: _cStd),
  ];
}

/// Builds the full ordered list of metrics for a member (uses gender/age/height
/// to pick the correct healthy-range bands). Ordering follows the FitDays report.
List<BodyMetricDef> buildBodyMetricsCatalog(Member member) {
  final isMale = member.gender == Gender.male;
  final age = member.age;

  double? pctMass(double? pct, double weight) =>
      pct == null ? null : weight * pct / 100.0;

  return [
    BodyMetricDef(
      id: 'weight',
      name: 'Weight',
      unit: 'kg',
      decimals: 2,
      read: (m) => m.weightKg,
    ),
    BodyMetricDef(
      id: 'bmi',
      name: 'BMI',
      unit: '',
      decimals: 1,
      read: (m) => m.bmi,
      bands: const [
        MetricBand(label: 'Thin', min: 0, max: 18.5, color: _cLow),
        MetricBand(label: 'Standard', min: 18.5, max: 25.0, color: _cStd),
        MetricBand(label: 'Overweight', min: 25.0, max: 27.0, color: _cWarn),
        MetricBand(label: 'Severely overweight', min: 27.0, max: 100, color: _cHigh),
      ],
    ),
    BodyMetricDef(
      id: 'bodyFat',
      name: 'Body Fat',
      unit: '%',
      decimals: 1,
      read: (m) => m.bodyFatPercent,
      bands: isMale
          ? const [
              MetricBand(label: 'Thin', min: 0, max: 10, color: _cLow),
              MetricBand(label: 'Standard', min: 10, max: 20, color: _cStd),
              MetricBand(label: 'Overweight', min: 20, max: 25, color: _cWarn),
              MetricBand(label: 'Severely overweight', min: 25, max: 100, color: _cHigh),
            ]
          : const [
              MetricBand(label: 'Thin', min: 0, max: 18, color: _cLow),
              MetricBand(label: 'Standard', min: 18, max: 28, color: _cStd),
              MetricBand(label: 'Overweight', min: 28, max: 32, color: _cWarn),
              MetricBand(label: 'Severely overweight', min: 32, max: 100, color: _cHigh),
            ],
    ),
    BodyMetricDef(
      id: 'fatMass',
      name: 'Fat Mass',
      unit: 'kg',
      decimals: 1,
      read: (m) => pctMass(m.bodyFatPercent, m.weightKg),
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 8, color: _cLow),
              MetricBand(label: 'Standard', min: 8, max: 15, color: _cStd),
              MetricBand(label: 'High', min: 15, max: 20, color: _cWarn),
              MetricBand(label: 'Very High', min: 20, max: 200, color: _cHigh),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 13, color: _cLow),
              MetricBand(label: 'Standard', min: 13, max: 20, color: _cStd),
              MetricBand(label: 'High', min: 20, max: 27, color: _cWarn),
              MetricBand(label: 'Very High', min: 27, max: 200, color: _cHigh),
            ],
    ),
    BodyMetricDef(
      id: 'leanBodyMass',
      name: 'Fat-free Body Weight',
      unit: 'kg',
      decimals: 1,
      read: (m) => m.bodyFatPercent == null
          ? null
          : m.weightKg * (1 - m.bodyFatPercent! / 100),
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 50, color: _cLow),
              MetricBand(label: 'Standard', min: 50, max: 65, color: _cStd),
              MetricBand(label: 'High', min: 65, max: 200, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 38, color: _cLow),
              MetricBand(label: 'Standard', min: 38, max: 50, color: _cStd),
              MetricBand(label: 'High', min: 50, max: 200, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'muscleMass',
      name: 'Muscle Mass',
      unit: 'kg',
      decimals: 1,
      read: (m) => pctMass(m.muscleRatePercent, m.weightKg),
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 32, color: _cLow),
              MetricBand(label: 'Standard', min: 32, max: 40, color: _cStd),
              MetricBand(label: 'Excellent', min: 40, max: 200, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 22, color: _cLow),
              MetricBand(label: 'Standard', min: 22, max: 28, color: _cStd),
              MetricBand(label: 'Excellent', min: 28, max: 200, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'muscleRate',
      name: 'Muscle Rate',
      unit: '%',
      decimals: 1,
      read: (m) => m.muscleRatePercent,
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 33, color: _cLow),
              MetricBand(label: 'Standard', min: 33, max: 39, color: _cStd),
              MetricBand(label: 'Excellent', min: 39, max: 100, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 25, color: _cLow),
              MetricBand(label: 'Standard', min: 25, max: 30, color: _cStd),
              MetricBand(label: 'Excellent', min: 30, max: 100, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'skeletalMuscle',
      name: 'Skeletal Muscle',
      unit: '%',
      decimals: 1,
      read: (m) => m.skeletalMusclePercent,
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 40, color: _cLow),
              MetricBand(label: 'Standard', min: 40, max: 60, color: _cStd),
              MetricBand(label: 'Excellent', min: 60, max: 100, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 30, color: _cLow),
              MetricBand(label: 'Standard', min: 30, max: 40, color: _cStd),
              MetricBand(label: 'Excellent', min: 40, max: 100, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'boneMass',
      name: 'Bone Mass',
      unit: 'kg',
      decimals: 1,
      read: (m) => m.boneMassKg,
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 2.5, color: _cWarn),
              MetricBand(label: 'Standard', min: 2.5, max: 3.5, color: _cStd),
              MetricBand(label: 'Excellent', min: 3.5, max: 20, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 1.8, color: _cWarn),
              MetricBand(label: 'Standard', min: 1.8, max: 2.5, color: _cStd),
              MetricBand(label: 'Excellent', min: 2.5, max: 20, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'proteinMass',
      name: 'Protein Mass',
      unit: 'kg',
      decimals: 1,
      read: (m) => pctMass(m.proteinPercent, m.weightKg),
      bands: const [
        MetricBand(label: 'Low', min: 0, max: 8, color: _cWarn),
        MetricBand(label: 'Standard', min: 8, max: 12, color: _cStd),
        MetricBand(label: 'Excellent', min: 12, max: 100, color: _cExc),
      ],
    ),
    BodyMetricDef(
      id: 'protein',
      name: 'Protein',
      unit: '%',
      decimals: 1,
      read: (m) => m.proteinPercent,
      bands: const [
        MetricBand(label: 'Low', min: 0, max: 16, color: _cWarn),
        MetricBand(label: 'Standard', min: 16, max: 20, color: _cStd),
        MetricBand(label: 'Excellent', min: 20, max: 100, color: _cExc),
      ],
    ),
    BodyMetricDef(
      id: 'waterWeight',
      name: 'Water Weight',
      unit: 'kg',
      decimals: 1,
      read: (m) => pctMass(m.bodyWaterPercent, m.weightKg),
      bands: const [
        MetricBand(label: 'Low', min: 0, max: 30, color: _cWarn),
        MetricBand(label: 'Standard', min: 30, max: 45, color: _cStd),
        MetricBand(label: 'High', min: 45, max: 200, color: _cExc),
      ],
    ),
    BodyMetricDef(
      id: 'bodyWater',
      name: 'Body Water',
      unit: '%',
      decimals: 1,
      read: (m) => m.bodyWaterPercent,
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 55, color: _cWarn),
              MetricBand(label: 'Standard', min: 55, max: 65, color: _cStd),
              MetricBand(label: 'Excellent', min: 65, max: 100, color: _cExc),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 45, color: _cWarn),
              MetricBand(label: 'Standard', min: 45, max: 60, color: _cStd),
              MetricBand(label: 'Excellent', min: 60, max: 100, color: _cExc),
            ],
    ),
    BodyMetricDef(
      id: 'subcutaneousFat',
      name: 'Subcutaneous Fat',
      unit: '%',
      decimals: 1,
      read: (m) => m.subcutaneousFatPercent,
      bands: isMale
          ? const [
              MetricBand(label: 'Low', min: 0, max: 8.6, color: _cLow),
              MetricBand(label: 'Standard', min: 8.6, max: 16.7, color: _cStd),
              MetricBand(label: 'High', min: 16.7, max: 20.7, color: _cWarn),
              MetricBand(label: 'Very High', min: 20.7, max: 100, color: _cHigh),
            ]
          : const [
              MetricBand(label: 'Low', min: 0, max: 18.5, color: _cLow),
              MetricBand(label: 'Standard', min: 18.5, max: 26.7, color: _cStd),
              MetricBand(label: 'High', min: 26.7, max: 30.7, color: _cWarn),
              MetricBand(label: 'Very High', min: 30.7, max: 100, color: _cHigh),
            ],
    ),
    BodyMetricDef(
      id: 'visceralFat',
      name: 'Visceral Fat',
      unit: '',
      decimals: 1,
      read: (m) => m.visceralFat,
      bands: const [
        MetricBand(label: 'Standard', min: 0, max: 10, color: _cStd),
        MetricBand(label: 'Too High', min: 10, max: 100, color: _cHigh),
      ],
    ),
    BodyMetricDef(
      id: 'bmr',
      name: 'BMR',
      unit: 'kcal',
      decimals: 0,
      read: (m) => m.bmr?.toDouble(),
      bands: _bmrBands(isMale, age),
    ),
    BodyMetricDef(
      id: 'bodyAge',
      name: 'Body Age',
      unit: '',
      decimals: 0,
      read: (m) => m.bodyAge?.toDouble(),
      bands: [
        MetricBand(label: 'Excellent', min: 0, max: age.toDouble() - 5, color: _cExc),
        MetricBand(label: 'Standard', min: age.toDouble() - 5, max: age.toDouble() + 5, color: _cStd),
        MetricBand(label: 'Above Age', min: age.toDouble() + 5, max: 200, color: _cWarn),
      ],
    ),
  ];
}
