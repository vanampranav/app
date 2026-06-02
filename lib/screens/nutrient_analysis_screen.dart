import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../theme/app_theme.dart';

class NutrientAnalysisScreen extends StatelessWidget {
  final DailySummary dailySummary;

  const NutrientAnalysisScreen({Key? key, required this.dailySummary})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalCal  = dailySummary.totalCalories;

    double fiber = 0, cholesterol = 0, calcium = 0, iron = 0,
           sodium = 0, potassium = 0, magnesium = 0, zinc = 0,
           vitC = 0, vitA = 0, sugar = 0;

    for (final e in dailySummary.entries) {
      fiber       += e.nutrition.fiber;
      cholesterol += e.nutrition.cholesterol ?? 0;
      calcium     += e.nutrition.calcium ?? 0;
      iron        += e.nutrition.iron ?? 0;
      sodium      += e.nutrition.sodium ?? 0;
      potassium   += e.nutrition.potassium ?? 0;
      magnesium   += e.nutrition.magnesium ?? 0;
      zinc        += e.nutrition.zinc ?? 0;
      vitC        += e.nutrition.vitaminC ?? 0;
      vitA        += e.nutrition.vitaminA ?? 0;
      sugar       += e.nutrition.sugar ?? 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Nutrient Analysis'),
        backgroundColor: AppTheme.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.md, 0, AppTheme.md, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Calorie hero ────────────────────────────────────────────────
          _CalorieHero(totalCalories: totalCal),
          const SizedBox(height: AppTheme.lg),

          // ── Macronutrients ──────────────────────────────────────────────
          _SectionHeader(title: 'MACRONUTRIENTS'),
          const SizedBox(height: AppTheme.sm),
          _NutrientSection(rows: [
            _NRow('Fat',           dailySummary.totalFat,     'g',  const Color(0xFFFFD93D)),
            _NRow('Carbohydrates', dailySummary.totalCarbs,   'g',  const Color(0xFF4ECDC4)),
            _NRow('Protein',       dailySummary.totalProtein, 'g',  const Color(0xFFFF6B6B)),
            if (fiber > 0) _NRow('Dietary Fiber', fiber, 'g', const Color(0xFF6BCB77)),
            if (sugar > 0) _NRow('Sugar',         sugar, 'g', const Color(0xFFFF8C42)),
          ]),
          const SizedBox(height: AppTheme.lg),

          // ── Minerals ────────────────────────────────────────────────────
          if (_anyPositive([calcium, iron, magnesium, potassium, sodium, zinc])) ...[
            _SectionHeader(title: 'MINERALS'),
            const SizedBox(height: AppTheme.sm),
            _NutrientSection(rows: [
              if (calcium   > 0) _NRow('Calcium',   calcium,   'mg', const Color(0xFF4ECDC4)),
              if (iron      > 0) _NRow('Iron',       iron,      'mg', const Color(0xFFFF6B6B)),
              if (magnesium > 0) _NRow('Magnesium',  magnesium, 'mg', const Color(0xFF8B5CF6)),
              if (potassium > 0) _NRow('Potassium',  potassium, 'mg', const Color(0xFF3B9EFF)),
              if (sodium    > 0) _NRow('Sodium',     sodium,    'mg', const Color(0xFFFFAA00)),
              if (zinc      > 0) _NRow('Zinc',       zinc,      'mg', const Color(0xFF6BCB77)),
            ]),
            const SizedBox(height: AppTheme.lg),
          ],

          // ── Vitamins ────────────────────────────────────────────────────
          if (_anyPositive([vitA, vitC])) ...[
            _SectionHeader(title: 'VITAMINS'),
            const SizedBox(height: AppTheme.sm),
            _NutrientSection(rows: [
              if (vitA > 0) _NRow('Vitamin A', vitA, 'μg', const Color(0xFFFFD93D)),
              if (vitC > 0) _NRow('Vitamin C', vitC, 'mg', const Color(0xFFFF8C42)),
            ]),
            const SizedBox(height: AppTheme.lg),
          ],

          // ── Other ───────────────────────────────────────────────────────
          if (cholesterol > 0) ...[
            _SectionHeader(title: 'OTHER'),
            const SizedBox(height: AppTheme.sm),
            _NutrientSection(rows: [
              _NRow('Cholesterol', cholesterol, 'mg', const Color(0xFFFF6B6B)),
            ]),
          ],
        ]),
      ),
    );
  }

  bool _anyPositive(List<double> vals) => vals.any((v) => v > 0);
}

// ── Calorie hero card ─────────────────────────────────────────────────────────
class _CalorieHero extends StatelessWidget {
  final double totalCalories;
  const _CalorieHero({required this.totalCalories});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.lime, Color(0xFFD4E84F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        boxShadow: [
          BoxShadow(
              color: AppTheme.lime.withOpacity(0.3),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Text(
          totalCalories.toStringAsFixed(0),
          style: const TextStyle(
              fontSize: 56, fontWeight: FontWeight.w900,
              color: Colors.black, letterSpacing: -2, height: 1),
        ),
        const SizedBox(height: 4),
        const Text('KCAL TODAY',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900,
                color: Colors.black54, letterSpacing: 2.5)),
      ]),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(title,
        style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
  );
}

// ── Nutrient section (card with rows) ─────────────────────────────────────────
class _NutrientSection extends StatelessWidget {
  final List<_NRow> rows;
  const _NutrientSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.val > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: visible.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 4, height: 32,
                  decoration: BoxDecoration(
                    color: r.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(r.name,
                      style: AppTheme.bodyLG.copyWith(
                          color: AppTheme.textPrimary)),
                ),
                Text(
                  '${r.val < 10 ? r.val.toStringAsFixed(2) : r.val.toStringAsFixed(1)} ${r.unit}',
                  style: AppTheme.labelLG.copyWith(color: r.color),
                ),
              ]),
            ),
            if (i < visible.length - 1)
              Divider(height: 1,
                  color: Colors.white.withOpacity(0.04), indent: 34),
          ]);
        }).toList(),
      ),
    );
  }
}

class _NRow {
  final String name;
  final double val;
  final String unit;
  final Color  color;
  const _NRow(this.name, this.val, this.unit, this.color);
}
