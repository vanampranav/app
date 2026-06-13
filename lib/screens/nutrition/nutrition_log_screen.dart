import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/food_models.dart';
import '../../services/nutrition_service.dart';
import '../../services/fitdays_service.dart';
import '../../models/device_model.dart';
import '../../utils/food_emoji_helper.dart';
import '../../utils/food_icon_helper.dart';
import '../../services/health_service.dart';
import '../../widgets/device_scan_sheet.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ef_components.dart';
import '../food_search_screen.dart';

// Meal metadata now uses MealIconHelper instead of emoji strings.

// ─────────────────────────────────────────────────────────────────────────────

class NutritionLogScreen extends StatefulWidget {
  const NutritionLogScreen({Key? key}) : super(key: key);

  @override
  State<NutritionLogScreen> createState() => _NutritionLogScreenState();
}

class _NutritionLogScreenState extends State<NutritionLogScreen> {
  final NutritionService _nutritionService = NutritionService();
  final FitDaysService   _fitDays          = FitDaysService();

  DateTime     _selectedDate    = DateTime.now();
  DailySummary _summary         = DailySummary(date: DateTime.now(), entries: []);
  Set<String>  _daysWithEntries = {};   // keys like '2026-05-29'
  bool         _scaleConnected  = false;
  StreamSubscription? _connSub;

  int _calGoal     = 2000;
  int _proteinGoal = 150;
  int _carbsGoal   = 200;
  int _fatGoal     = 65;

  // ── Last 7 days (index 0 = 6 days ago, index 6 = today) ───────────────────
  List<DateTime> get _last7Days {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  static const _shortDays = ['SUN','MON','TUE','WED','THU','FRI','SAT'];

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadSummary();
    _loadDaysWithEntries();
    // Track scale connection state for the BT button colour
    _scaleConnected = _fitDays.connectedDeviceMac != null;
    _connSub = _fitDays.connectionStateStream.listen((data) {
      if (!mounted) return;
      setState(() => _scaleConnected = data['state'] == 'connected');
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDaysWithEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> found = {};
    for (final d in _last7Days) {
      final key = _dateKey(d);
      final raw = prefs.getString('meal_entries_$key');
      if (raw != null && raw != '[]') found.add(key);
    }
    if (mounted) setState(() => _daysWithEntries = found);
  }

  // ── Load goals from onboarding prefs ────────────────────────────────────────
  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calGoal     = prefs.getInt('cal_goal')      ?? prefs.getInt('user_daily_calories') ?? 2000;
      _proteinGoal = prefs.getInt('protein_goal')  ?? 150;
      _carbsGoal   = prefs.getInt('carbs_goal')    ?? 200;
      _fatGoal     = prefs.getInt('fat_goal')       ?? 65;
    });
  }

  // ── Date key (YYYY-MM-DD, zero-padded) ──────────────────────────────────────
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Load entries from SharedPreferences ──────────────────────────────────
  Future<void> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('meal_entries_${_dateKey(_selectedDate)}');
    List<MealEntry> entries = [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        entries = list.map((e) => MealEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    setState(() {
      _summary = DailySummary(
        date:            _selectedDate,
        entries:         entries,
        targetCalories:  _calGoal.toDouble(),
      );
    });
  }

  // ── Save and sync ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'meal_entries_${_dateKey(_selectedDate)}',
      jsonEncode(_summary.entries.map((e) => e.toJson()).toList()),
    );
    await _syncHomePrefs(prefs);
    await _loadDaysWithEntries();
  }

  Future<void> _syncHomePrefs(SharedPreferences prefs) async {
    // Only sync today's data to the home screen keys
    if (!_isToday(_selectedDate)) return;
    final d = DateTime.now();
    final k = '${d.year}_${d.month}_${d.day}';
    await prefs.setInt('cal_consumed_$k', _summary.totalCalories.round());
    await prefs.setInt('protein_$k',      _summary.totalProtein.round());
    await prefs.setInt('carbs_$k',        _summary.totalCarbs.round());
    await prefs.setInt('fat_$k',          _summary.totalFat.round());
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _goToDate(DateTime d) {
    setState(() => _selectedDate = d);
    _loadSummary();
  }

  // ── Add food ──────────────────────────────────────────────────────────────
  Future<void> _addFood(MealType meal) async {
    final entries = await Navigator.push<List<MealEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          meal:             meal,
          currentWeight:    0.0,
          nutritionService: _nutritionService,
          weightStream:     _fitDays.weightDataStream,
        ),
      ),
    );
    if (entries == null || entries.isEmpty) return;
    setState(() {
      for (final e in entries) _summary.entries.add(e);
    });
    await _save();

    // Push each new entry to Apple Health / Health Connect (silent)
    for (final e in entries) {
      HealthService().syncMealEntry(e);
    }
  }

  // ── Delete food ───────────────────────────────────────────────────────────
  Future<void> _deleteEntry(MealEntry entry) async {
    setState(() => _summary.entries.removeWhere((e) => e.id == entry.id));
    await _save();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: AppTheme.lime,
        backgroundColor: AppTheme.surface1,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildWeekStrip()),
            SliverToBoxAdapter(child: _buildSummaryCard()),
            SliverToBoxAdapter(child: const SizedBox(height: AppTheme.md)),
            ...MealType.values.map(_buildMealSection),
            SliverToBoxAdapter(child: _buildNutrientSummary()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── App bar — title only ───────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppTheme.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 52,
      title: const Text('Nutrition',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3)),
      actions: [
        // Bluetooth / scale connect button
        IconButton(
          tooltip: _scaleConnected ? 'Scale connected' : 'Connect scale',
          icon: Icon(
            _scaleConnected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_rounded,
            color: _scaleConnected ? AppTheme.lime : AppTheme.textSecondary,
            size: 22,
          ),
          onPressed: _showScaleScanner,
        ),
        // Calendar / date picker
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined,
              color: AppTheme.textSecondary, size: 20),
          onPressed: _pickDate,
        ),
      ],
    );
  }

  // ── 7-day strip (matches AI Coach schedule style) ──────────────────────────
  Widget _buildWeekStrip() {
    final days    = _last7Days;
    final selKey  = _dateKey(_selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: days.asMap().entries.map((entry) {
          final idx  = entry.key;
          final day  = entry.value;
          final key  = _dateKey(day);
          final isActive  = key == selKey;
          final hasFood   = _daysWithEntries.contains(key);
          final isFuture  = day.isAfter(DateTime.now());

          return Expanded(
            child: GestureDetector(
              onTap: isFuture ? null : () => _goToDate(day),
              child: Column(children: [
                // Lime dot (has food logged)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5, width: 5,
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasFood
                        ? (isActive ? AppTheme.lime : AppTheme.lime.withOpacity(0.4))
                        : Colors.transparent,
                    boxShadow: hasFood && isActive
                        ? [BoxShadow(color: AppTheme.lime.withOpacity(0.8), blurRadius: 6)]
                        : [],
                  ),
                ),
                // Date number
                Text(
                  day.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isFuture
                        ? AppTheme.textTertiary
                        : isActive ? Colors.white : const Color(0xFF454545),
                    fontSize: isActive ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                // Day name
                Text(
                  _shortDays[day.weekday % 7],
                  style: TextStyle(
                    color: isFuture
                        ? AppTheme.textTertiary
                        : isActive ? Colors.white : const Color(0xFF454545),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                // Lime underline when active
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: isActive ? 18 : 0,
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: isActive
                        ? [BoxShadow(color: AppTheme.lime.withOpacity(0.6), blurRadius: 6)]
                        : [],
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showScaleScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DeviceScanSheet(
        filterType: DeviceType.kitchenScale,
        title: 'Connect kitchen scale',
        subtitle: 'For live weight while logging food',
        onConnected: (_) {
          setState(() => _scaleConnected = true);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Scale connected — add food to weigh live.'),
            backgroundColor: AppTheme.surface2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ));
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.lime,
            surface: AppTheme.surface1,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _goToDate(picked);
  }

  // ── Calorie + macro summary card ──────────────────────────────────────────
  Widget _buildSummaryCard() {
    final consumed  = _summary.totalCalories;
    final remaining = (_calGoal - consumed).clamp(0, _calGoal).toInt();
    final progress  = _calGoal > 0
        ? (consumed / _calGoal).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: EFCard(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Row(
          children: [
            // Progress ring
            EFProgressRing(
              size: 130,
              strokeWidth: 10,
              progress: progress,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$remaining',
                    style: AppTheme.numericLG.copyWith(fontSize: 28),
                  ),
                  Text('left', style: AppTheme.labelSM),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CALORIES TODAY',
                      style: AppTheme.labelSM),
                  const SizedBox(height: 4),
                  Text(
                    '${consumed.round()} / $_calGoal kcal',
                    style: AppTheme.numericMD.copyWith(
                        color: AppTheme.lime, fontSize: 18),
                  ),
                  const SizedBox(height: AppTheme.md),
                  EFMacroBar(
                    label: 'Protein',
                    current: _summary.totalProtein.round(),
                    target: _proteinGoal,
                    color: const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 8),
                  EFMacroBar(
                    label: 'Carbs',
                    current: _summary.totalCarbs.round(),
                    target: _carbsGoal,
                    color: const Color(0xFF4ECDC4),
                  ),
                  const SizedBox(height: 8),
                  EFMacroBar(
                    label: 'Fat',
                    current: _summary.totalFat.round(),
                    target: _fatGoal,
                    color: const Color(0xFFFFD93D),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Meal section ──────────────────────────────────────────────────────────
  Widget _buildMealSection(MealType meal) {
    final mealIcon  = MealIconHelper.icon(meal);
    final mealColor = MealIconHelper.color(meal);
    final mealLabel = MealIconHelper.label(meal);
    final entries = _summary.getMealEntries(meal);
    final kcal    = _summary.getMealCalories(meal).round();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.md, 0, AppTheme.md, AppTheme.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: mealColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(mealIcon, size: 16, color: mealColor),
                ),
                const SizedBox(width: 8),
                Text(
                  mealLabel.toUpperCase(),
                  style: AppTheme.labelLG.copyWith(
                      color: mealColor, letterSpacing: 1.2),
                ),
                const Spacer(),
                if (kcal > 0)
                  Text(
                    '$kcal kcal',
                    style: AppTheme.labelMD.copyWith(
                        color: AppTheme.textTertiary),
                  ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _addFood(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: mealColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill),
                      border: Border.all(
                          color: mealColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: mealColor),
                        const SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: mealColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Entries or empty state ────────────────────────────────
            if (entries.isEmpty)
              _buildEmptyMeal(meal, mealLabel)
            else
              ...entries.asMap().entries.map((kv) =>
                  _buildFoodEntryTile(kv.value, mealColor, kv.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMeal(MealType meal, String mealLabel) {
    return GestureDetector(
      onTap: () => _addFood(meal),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: AppTheme.textTertiary, size: 18),
            const SizedBox(width: 10),
            Text(
              'Log your ${mealLabel.toLowerCase()}',
              style: AppTheme.bodyMD,
            ),
          ],
        ),
      ),
    );
  }

  void _showEntryDetail(MealEntry entry, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FoodEntryDetailSheet(entry: entry, accent: accent),
    );
  }

  Widget _buildFoodEntryTile(MealEntry entry, Color accent, [int index = 0]) {
    return EFAnimatedEntry(
      delay: Duration(milliseconds: 40 + index * 60),
      child: Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.error, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface1,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXxl)),
                title: Text('Remove entry?', style: AppTheme.headingSM),
                content: Text(
                    'Remove ${entry.foodName} from your log?',
                    style: AppTheme.bodyMD),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: AppTheme.labelLG.copyWith(
                            color: AppTheme.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _deleteEntry(entry),
      child: GestureDetector(
        onTap: () => _showEntryDetail(entry, accent),
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // Food icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(FoodEmojiHelper.get(entry.foodName),
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            // Name + macros
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.foodName,
                    style: AppTheme.headingSM.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${entry.weight.round()}g',
                        style: AppTheme.bodySM.copyWith(
                            color: AppTheme.textTertiary),
                      ),
                      const SizedBox(width: 8),
                      _macroPill(
                          'P',
                          entry.nutrition.protein.round(),
                          const Color(0xFFFF6B6B)),
                      const SizedBox(width: 4),
                      _macroPill(
                          'C',
                          entry.nutrition.carbs.round(),
                          const Color(0xFF4ECDC4)),
                      const SizedBox(width: 4),
                      _macroPill(
                          'F',
                          entry.nutrition.fat.round(),
                          const Color(0xFFFFD93D)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Calories
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.nutrition.calories.round()}',
                  style: AppTheme.numericMD.copyWith(
                      fontSize: 18, color: AppTheme.textPrimary),
                ),
                Text('kcal',
                    style: AppTheme.labelSM.copyWith(
                        color: AppTheme.textTertiary)),
              ],
            ),
          ],
        ),
      ), // Container
      ), // GestureDetector
      ), // Dismissible
    ); // EFAnimatedEntry
  }

  Widget _macroPill(String letter, int val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$letter $val',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ── Nutrient summary (bottom) ─────────────────────────────────────────────
  Widget _buildNutrientSummary() {
    final totalFiber   = _summary.entries
        .fold<double>(0, (s, e) => s + (e.nutrition.fiber ?? 0));
    final totalSodium  = _summary.entries
        .fold<double>(0, (s, e) => s + (e.nutrition.sodium ?? 0));
    final totalSugar   = _summary.entries
        .fold<double>(0, (s, e) => s + (e.nutrition.sugar ?? 0));

    if (_summary.entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: EFCard(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NUTRIENTS',
                style: AppTheme.labelMD
                    .copyWith(color: AppTheme.textTertiary)),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                _nutrientTile('Fiber',  '${totalFiber.round()}g',
                    const Color(0xFF6BCB77)),
                _divider(),
                _nutrientTile('Sodium', '${totalSodium.round()}mg',
                    const Color(0xFFFFD93D)),
                _divider(),
                _nutrientTile('Sugar',  '${totalSugar.round()}g',
                    const Color(0xFFFF6B6B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientTile(String label, String val, Color color) {
    return Expanded(
      child: Column(children: [
        Text(val,
            style: AppTheme.numericMD
                .copyWith(fontSize: 20, color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.labelSM),
      ]),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        color: AppTheme.divider,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Read-only nutrition detail sheet shown when tapping a logged food entry
// ─────────────────────────────────────────────────────────────────────────────
class _FoodEntryDetailSheet extends StatelessWidget {
  final MealEntry entry;
  final Color accent;

  const _FoodEntryDetailSheet({required this.entry, required this.accent});

  @override
  Widget build(BuildContext context) {
    final n = entry.nutrition;
    final total = n.fat + n.carbs + n.protein;
    final fatPct   = total > 0 ? ((n.fat     / total) * 100).round() : 0;
    final carbsPct = total > 0 ? ((n.carbs   / total) * 100).round() : 0;
    final protPct  = total > 0 ? ((n.protein / total) * 100).round() : 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(FoodEmojiHelper.get(entry.foodName),
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.foodName,
                    style: AppTheme.headingSM,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Text('${entry.weight.round()} g · ${n.calories.round()} kcal',
                    style: AppTheme.bodyMD),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Calorie ring + macros ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(children: [
                  // Calorie circle
                  SizedBox(
                    width: 96, height: 96,
                    child: Stack(children: [
                      Center(
                        child: SizedBox(
                          width: 88, height: 88,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 8,
                            backgroundColor: AppTheme.surface3,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${n.calories.round()}',
                                  style: AppTheme.numericMD.copyWith(
                                      color: accent, fontSize: 20)),
                              Text('kcal', style: AppTheme.labelSM),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(child: Column(children: [
                    _macroRow('Fat',     n.fat,     fatPct,   const Color(0xFFFFD93D)),
                    const SizedBox(height: 8),
                    _macroRow('Carbs',  n.carbs,   carbsPct, const Color(0xFF4ECDC4)),
                    const SizedBox(height: 8),
                    _macroRow('Protein',n.protein, protPct,  const Color(0xFFFF6B6B)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Extra nutrients ────────────────────────────────────────
              if (_hasExtra(n)) ...[
                Text('DETAILED NUTRIENTS',
                    style: AppTheme.labelMD.copyWith(
                        color: AppTheme.textTertiary)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(children: [
                    if (n.fiber > 0)
                      _nutrientRow('Dietary Fiber',  '${n.fiber.toStringAsFixed(1)} g',
                          const Color(0xFF6BCB77)),
                    if ((n.sodium ?? 0) > 0)
                      _nutrientRow('Sodium',
                          '${(n.sodium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFFAA00)),
                    if ((n.sugar ?? 0) > 0)
                      _nutrientRow('Sugar',
                          '${(n.sugar ?? 0).toStringAsFixed(1)} g',
                          const Color(0xFFFF8C42)),
                    if ((n.cholesterol ?? 0) > 0)
                      _nutrientRow('Cholesterol',
                          '${(n.cholesterol ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFF6B6B)),
                    if ((n.calcium ?? 0) > 0)
                      _nutrientRow('Calcium',
                          '${(n.calcium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFF4ECDC4)),
                    if ((n.vitaminC ?? 0) > 0)
                      _nutrientRow('Vitamin C',
                          '${(n.vitaminC ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFF8C42)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  bool _hasExtra(NutritionData n) =>
      n.fiber > 0 ||
      (n.sodium ?? 0) > 0 ||
      (n.sugar ?? 0) > 0 ||
      (n.cholesterol ?? 0) > 0 ||
      (n.calcium ?? 0) > 0 ||
      (n.vitaminC ?? 0) > 0;

  Widget _macroRow(String label, double val, int pct, Color color) {
    return Row(children: [
      Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Text(label,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary)),
      const Spacer(),
      Text('${val.toStringAsFixed(1)}g',
          style: AppTheme.labelLG.copyWith(color: AppTheme.textPrimary)),
      const SizedBox(width: 6),
      Text('$pct%',
          style: AppTheme.labelMD.copyWith(color: color)),
    ]);
  }

  Widget _nutrientRow(String label, String val, Color color) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
              width: 4, height: 28,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: AppTheme.bodyLG.copyWith(
                  color: AppTheme.textPrimary))),
          Text(val,
              style: AppTheme.labelLG.copyWith(color: color)),
        ]),
      ),
      Divider(height: 1,
          color: Colors.white.withOpacity(0.04), indent: 32),
    ]);
  }

}
