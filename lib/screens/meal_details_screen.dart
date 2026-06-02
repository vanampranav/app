import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_models.dart';
import '../theme/app_theme.dart';
import '../utils/food_emoji_helper.dart';
import '../utils/food_icon_helper.dart';

class MealDetailsScreen extends StatelessWidget {
  final MealType       meal;
  final List<MealEntry> entries;
  final DateTime       date;

  const MealDetailsScreen({
    Key? key,
    required this.meal,
    required this.entries,
    required this.date,
  }) : super(key: key);

  // ── Data ───────────────────────────────────────────────────────────────────
  String get _mealName {
    switch (meal) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
      case MealType.snacks:    return 'Snacks';
    }
  }

  String get _mealEmoji {
    switch (meal) {
      case MealType.breakfast: return '🌅';
      case MealType.lunch:     return '☀️';
      case MealType.dinner:    return '🌙';
      case MealType.snacks:    return '🍎';
    }
  }

  Color get _mealColor {
    switch (meal) {
      case MealType.breakfast: return const Color(0xFFFF8C42);
      case MealType.lunch:     return const Color(0xFF3B9EFF);
      case MealType.dinner:    return const Color(0xFF8B5CF6);
      case MealType.snacks:    return const Color(0xFF4ECDC4);
    }
  }

  double get _totalCalories => entries.fold(0, (s, e) => s + e.nutrition.calories);
  double get _totalFat      => entries.fold(0, (s, e) => s + e.nutrition.fat);
  double get _totalCarbs    => entries.fold(0, (s, e) => s + e.nutrition.carbs);
  double get _totalProtein  => entries.fold(0, (s, e) => s + e.nutrition.protein);

  @override
  Widget build(BuildContext context) {
    final total      = _totalFat + _totalCarbs + _totalProtein;
    final fatPct     = total > 0 ? ((_totalFat     / total) * 100).round() : 0;
    final carbsPct   = total > 0 ? ((_totalCarbs   / total) * 100).round() : 0;
    final proteinPct = total > 0 ? ((_totalProtein / total) * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // ── Coloured hero AppBar ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.bg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_rounded,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _mealColor.withOpacity(0.25),
                      _mealColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(_mealEmoji,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(_mealName,
                            style: AppTheme.displayMD.copyWith(
                                color: AppTheme.textPrimary)),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date),
                          style: AppTheme.bodyMD,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(children: [
                // ── Composition card ────────────────────────────────────
                _buildCompositionCard(fatPct, carbsPct, proteinPct),
                const SizedBox(height: AppTheme.md),
                // ── Food list card ───────────────────────────────────────
                _buildFoodListCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Composition card ───────────────────────────────────────────────────────
  Widget _buildCompositionCard(int fatPct, int carbsPct, int proteinPct) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('COMPOSITION',
            style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
        const SizedBox(height: AppTheme.lg),
        Row(children: [
          // Calorie ring
          SizedBox(
            width: 110, height: 110,
            child: Stack(children: [
              Center(
                child: SizedBox(
                  width: 100, height: 100,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    backgroundColor: AppTheme.surface3,
                    valueColor: AlwaysStoppedAnimation<Color>(_mealColor),
                  ),
                ),
              ),
              Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _totalCalories.toStringAsFixed(0),
                        style: AppTheme.numericMD.copyWith(
                            color: _mealColor, fontSize: 22),
                      ),
                      Text('kcal', style: AppTheme.labelSM),
                    ]),
              ),
            ]),
          ),
          const SizedBox(width: AppTheme.lg),
          Expanded(
            child: Column(children: [
              _macroRow('Fat',     _totalFat,     fatPct,     const Color(0xFFFFD93D)),
              const SizedBox(height: 10),
              _macroRow('Carbs',   _totalCarbs,   carbsPct,   const Color(0xFF4ECDC4)),
              const SizedBox(height: 10),
              _macroRow('Protein', _totalProtein, proteinPct, const Color(0xFFFF6B6B)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _macroRow(String label, double val, int pct, Color color) {
    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary)),
      const Spacer(),
      Text('${val.toStringAsFixed(1)}g',
          style: AppTheme.labelLG.copyWith(color: AppTheme.textPrimary)),
      const SizedBox(width: 8),
      Text('$pct%', style: AppTheme.labelMD.copyWith(color: color)),
    ]);
  }

  // ── Food list card ─────────────────────────────────────────────────────────
  Widget _buildFoodListCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Text('FOOD ITEMS',
                style: AppTheme.labelMD.copyWith(
                    color: AppTheme.textTertiary)),
            const Spacer(),
            Text('${entries.length} item${entries.length == 1 ? '' : 's'}',
                style: AppTheme.bodyMD),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.divider),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(children: [
                Text(_mealEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('No food logged yet', style: AppTheme.bodyMD),
              ]),
            ),
          )
        else
          Column(
            children: entries.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Column(children: [
                _buildFoodRow(e),
                if (i < entries.length - 1)
                  Divider(height: 1,
                      color: Colors.white.withOpacity(0.04),
                      indent: 72),
              ]);
            }).toList(),
          ),
      ]),
    );
  }

  Widget _buildFoodRow(MealEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        // Icon / image
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _mealColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: entry.imageUrl != null
              ? Image.network(
                  entry.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    final fi = FoodIconHelper.get(
                        foodName: entry.foodName, nutrition: entry.nutrition);
                    return Center(child: Icon(fi.icon, color: fi.color, size: 22));
                  },
                )
              : Builder(builder: (_) {
                  final fi = FoodIconHelper.get(
                      foodName: entry.foodName, nutrition: entry.nutrition);
                  return Center(child: Icon(fi.icon, color: fi.color, size: 22));
                }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.foodName,
                style: AppTheme.headingSM.copyWith(fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              '${entry.weight.round()}g · ${entry.nutrition.calories.round()} kcal',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
            ),
          ]),
        ),
        // Mini macro chips
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _miniMacro('P', entry.nutrition.protein, const Color(0xFFFF6B6B)),
          const SizedBox(height: 3),
          _miniMacro('C', entry.nutrition.carbs,   const Color(0xFF4ECDC4)),
          const SizedBox(height: 3),
          _miniMacro('F', entry.nutrition.fat,     const Color(0xFFFFD93D)),
        ]),
      ]),
    );
  }

  Widget _miniMacro(String letter, double val, Color color) {
    return Text(
      '$letter ${val.round()}g',
      style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: color),
    );
  }
}
