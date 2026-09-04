import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/food_models.dart';
import '../../services/nutrition_service.dart';
import '../../services/meal_vision_service.dart';
import '../../services/firebase_rest_service.dart';
import '../../services/fitdays_service.dart';
import '../../services/streak_service.dart';
import '../../models/device_model.dart';
import '../../utils/food_emoji_helper.dart';
import '../../utils/food_icon_helper.dart';
import '../../services/health_service.dart';
import '../../services/backend_service.dart';
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
  final MealVisionService _visionService = MealVisionService();
  final FitDaysService   _fitDays          = FitDaysService();
  final ImagePicker      _picker           = ImagePicker();

  DateTime     _selectedDate    = DateTime.now();
  DailySummary _summary         = DailySummary(date: DateTime.now(), entries: []);
  Set<String>  _daysWithEntries = {};   // keys like '2026-05-29'
  bool         _scaleConnected  = false;
  bool         _bluetoothOn      = true;
  StreamSubscription? _connSub;
  StreamSubscription? _btSub;

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
    // Track scale connection state for the BT button colour. Use the service's
    // set-based check so a stale device's disconnect doesn't wrongly flip it.
    _scaleConnected = _fitDays.hasConnectedDevice;
    _connSub = _fitDays.connectionStateStream.listen((_) {
      if (!mounted) return;
      setState(() => _scaleConnected = _fitDays.hasConnectedDevice);
    });

    // Track the phone's Bluetooth state so the BT button can show "off".
    _bluetoothOn = _fitDays.isBluetoothOn ?? true;
    _btSub = _fitDays.bluetoothStateStream.listen((on) {
      if (!mounted) return;
      setState(() {
        _bluetoothOn = on;
        if (!on) _scaleConnected = false; // BT off ⇒ nothing is connected
      });
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _btSub?.cancel();
    super.dispose();
  }

  void _showBluetoothOffMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
        title: Row(children: [
          const Icon(Icons.bluetooth_disabled_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Text('Bluetooth is off', style: AppTheme.headingSM),
        ]),
        content: Text(
          'Turn on Bluetooth in your device settings to connect your scale.',
          style: AppTheme.bodyMD.copyWith(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
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

    // Logging a meal counts as a streak-qualifying activity for today.
    await StreakService.recordActivity();
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

    // Push each new entry to Apple Health / Health Connect & Firebase backend (silent)
    for (final e in entries) {
      HealthService().syncMealEntry(e);
      _syncBackendMealEntry(e, source: 'manual', nutritionSource: 'fatsecret');
    }
  }

  Future<void> _syncBackendMealEntry(
    MealEntry entry, {
    String source = 'manual',
    String? nutritionSource,
  }) async {
    try {
      await BackendService().saveMeal(
        entry,
        source: source,
        nutritionSource: nutritionSource,
      );
    } catch (e) {
      debugPrint('Backend saveMeal error for "${entry.foodName}": $e');
    }
  }

  // ── AI Image Analysis ──────────────────────────────────────────────────────
  Future<void> _pickAndAnalyzeImage(MealType meal) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.lime),
              title: const Text('Take Photo', style: AppTheme.bodyLG),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.lime),
              title: const Text('Choose from Gallery', style: AppTheme.bodyLG),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (image == null) return;

    final imageFile = File(image.path);

    // Give iOS time to fully clean up the picker scene before showing dialogs,
    // otherwise the loading overlay can fail to present on top.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Show loading overlay (dismissed via the root navigator below).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: AppTheme.surface1, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.lime),
              const SizedBox(height: 24),
              Text('Analyzing meal...', style: AppTheme.headingSM),
              const SizedBox(height: 8),
              Text('AI is identifying your food', style: AppTheme.bodySM),
            ],
          ),
        ),
      ),
    );

    try {
      // Pass the Firebase UID so the backend can apply a per-user daily quota.
      final fb = FirebaseRestService();
      await fb.init();
      final results = await _visionService.analyzeMealImage(imageFile, userId: fb.uid);

      // Upgrade AI estimates with verified FatSecret nutrition where available
      // (keeps the spinner up — it's a few quick lookups). Falls back to the AI
      // estimate when FatSecret has no confident match.
      final enriched = await _visionService.enrichWithFatSecret(results, _nutritionService);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading
      // Let the pop animation finish before showing the next sheet.
      await Future.delayed(const Duration(milliseconds: 300));

      if (enriched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not identify food in image.')));
        return;
      }

      // Convert results to MealEntries with safe key parsing (LLMs vary keys).
      // fdcId carries the source: 'ai_vision' = AI estimate, otherwise a
      // FatSecret id = verified nutrition (used for the badge in the sheet).
      final List<MealEntry> initialEntries = [];
      for (final res in enriched) {
        try {
          final name = res['foodName'] ?? res['name'] ?? res['food'] ?? res['item'] ?? 'Unknown Food';
          final weight = (res['weight'] ?? res['quantity'] ?? 100.0).toDouble();
          initialEntries.add(MealEntry(
            id: '${DateTime.now().millisecondsSinceEpoch}_$name',
            foodName: name,
            fdcId: (res['fdcId'] ?? 'ai_vision').toString(),
            weight: weight,
            nutrition: NutritionData.fromJson(res['nutrition'] ?? {}),
            meal: meal,
            timestamp: DateTime.now(),
            imageUrl: image.path,
          ));
        } catch (e) {
          debugPrint('MealVision: Error parsing item: $e');
        }
      }

      if (!mounted || initialEntries.isEmpty) return;

      // Let the user review/edit detected items before logging.
      final confirmedEntries = await showModalBottomSheet<List<MealEntry>>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MealVisionConfirmSheet(initialEntries: initialEntries),
      );

      if (confirmedEntries == null || confirmedEntries.isEmpty) return;

      setState(() {
        for (final e in confirmedEntries) _summary.entries.add(e);
      });
      await _save();

      for (final e in confirmedEntries) {
        HealthService().syncMealEntry(e);
        final String nutritionSource =
            e.fdcId == 'ai_vision' ? 'ai_estimate' : 'fatsecret';
        _syncBackendMealEntry(
          e,
          source: 'camera_ai',
          nutritionSource: nutritionSource,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logged ${confirmedEntries.length} items from image 🎉'),
        backgroundColor: AppTheme.lime,
      ));
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
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
        // Bluetooth / scale connect button — 3 states: BT off, connected, idle.
        IconButton(
          tooltip: !_bluetoothOn
              ? 'Bluetooth is off'
              : _scaleConnected
                  ? 'Scale connected'
                  : 'Connect scale',
          icon: Icon(
            !_bluetoothOn
                ? Icons.bluetooth_disabled_rounded
                : _scaleConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_rounded,
            color: !_bluetoothOn
                ? AppTheme.error
                : _scaleConnected
                    ? AppTheme.lime
                    : AppTheme.textSecondary,
            size: 22,
          ),
          onPressed: !_bluetoothOn ? _showBluetoothOffMessage : _showScaleScanner,
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
                // AI Image logging button
                GestureDetector(
                  onTap: () => _pickAndAnalyzeImage(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface3,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, size: 16, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
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
            const Spacer(),
            IconButton(
              onPressed: () => _pickAndAnalyzeImage(meal),
              icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.textTertiary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
                    if ((n.sugar ?? 0) > 0)
                      _nutrientRow('Sugar',
                          '${(n.sugar ?? 0).toStringAsFixed(1)} g',
                          const Color(0xFFFF8C42)),
                    if ((n.cholesterol ?? 0) > 0)
                      _nutrientRow('Cholesterol',
                          '${(n.cholesterol ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFFD93D)),
                    if ((n.sodium ?? 0) > 0)
                      _nutrientRow('Sodium',
                          '${(n.sodium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFF8C42)),
                    if ((n.potassium ?? 0) > 0)
                      _nutrientRow('Potassium',
                          '${(n.potassium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFF3B9EFF)),
                    if ((n.calcium ?? 0) > 0)
                      _nutrientRow('Calcium',
                          '${(n.calcium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFF4ECDC4)),
                    if ((n.vitaminC ?? 0) > 0)
                      _nutrientRow('Vitamin C',
                          '${(n.vitaminC ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFFF6B6B)),
                    if ((n.vitaminA ?? 0) > 0)
                      _nutrientRow('Vitamin A',
                          '${(n.vitaminA ?? 0).toStringAsFixed(1)} μg',
                          const Color(0xFFFFAA00)),
                    if ((n.iron ?? 0) > 0)
                      _nutrientRow('Iron',
                          '${(n.iron ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFFB06060)),
                    if ((n.magnesium ?? 0) > 0)
                      _nutrientRow('Magnesium',
                          '${(n.magnesium ?? 0).toStringAsFixed(1)} mg',
                          const Color(0xFF8B5CF6)),
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
      (n.sugar ?? 0) > 0 ||
      (n.cholesterol ?? 0) > 0 ||
      (n.sodium ?? 0) > 0 ||
      (n.potassium ?? 0) > 0 ||
      (n.calcium ?? 0) > 0 ||
      (n.vitaminC ?? 0) > 0 ||
      (n.vitaminA ?? 0) > 0 ||
      (n.iron ?? 0) > 0 ||
      (n.magnesium ?? 0) > 0;

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

// ─────────────────────────────────────────────────────────────────────────────
// AI Meal-Vision confirmation sheet — review/edit detected foods before logging
// ─────────────────────────────────────────────────────────────────────────────
class _MealVisionConfirmSheet extends StatefulWidget {
  final List<MealEntry> initialEntries;
  const _MealVisionConfirmSheet({required this.initialEntries});

  @override
  State<_MealVisionConfirmSheet> createState() => _MealVisionConfirmSheetState();
}

class _MealVisionConfirmSheetState extends State<_MealVisionConfirmSheet> {
  late List<MealEntry> _entries;      // current (editable) entries
  late List<MealEntry> _baseEntries;  // immutable originals — for proportional recalc

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.initialEntries);
    _baseEntries = List.from(widget.initialEntries);
  }

  void _setName(int index, String name) {
    final e = _entries[index];
    setState(() => _entries[index] = MealEntry(
          id: e.id, foodName: name, fdcId: e.fdcId, weight: e.weight,
          nutrition: e.nutrition, meal: e.meal, timestamp: e.timestamp,
          imageUrl: e.imageUrl,
        ));
  }

  /// Changing the weight rescales ALL nutrition proportionally from the ORIGINAL
  /// reading (not the current value) so repeated edits don't compound.
  void _setWeight(int index, double newWeight) {
    if (newWeight <= 0) return;
    final base = _baseEntries[index];
    final cur = _entries[index];
    final factor = base.weight > 0 ? newWeight / base.weight : 1.0;
    setState(() => _entries[index] = MealEntry(
          id: cur.id,
          foodName: cur.foodName, // keep any name edit
          fdcId: cur.fdcId,
          weight: newWeight,
          nutrition: base.nutrition.scale(factor),
          meal: cur.meal,
          timestamp: cur.timestamp,
          imageUrl: cur.imageUrl,
        ));
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      _baseEntries.removeAt(index); // keep the two lists index-aligned
    });
    if (_entries.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Text('Confirm Meal', style: AppTheme.headingMD),
            const Spacer(),
            Text('${_entries.length} items identified', style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) => _ConfirmFoodItem(
              entry: _entries[i],
              onNameChanged: (name) => _setName(i, name),
              onWeightChanged: (w) => _setWeight(i, w),
              onRemoved: () => _removeEntry(i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: EFButton(
            label: 'Log Meal',
            onTap: () => Navigator.pop(context, _entries),
          ),
        ),
      ]),
    );
  }
}

class _ConfirmFoodItem extends StatelessWidget {
  final MealEntry entry;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onRemoved;

  const _ConfirmFoodItem({
    required this.entry,
    required this.onNameChanged,
    required this.onWeightChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(FoodEmojiHelper.get(entry.foodName), style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: entry.foodName,
              style: AppTheme.headingSM.copyWith(fontSize: 16),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Food name',
              ),
              onChanged: onNameChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.error, size: 20),
            onPressed: onRemoved,
          ),
        ]),
        const SizedBox(height: 10),
        // Source badge: verified (FatSecret) vs AI estimate
        Align(
          alignment: Alignment.centerLeft,
          child: Builder(builder: (_) {
            final verified = entry.fdcId != 'ai_vision';
            final color = verified ? AppTheme.lime : AppTheme.textTertiary;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(verified ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                    size: 11, color: color),
                const SizedBox(width: 4),
                Text(verified ? 'Verified' : 'AI estimate',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(children: [
          // Weight is the ONLY editable nutrition input — everything else is
          // recalculated proportionally from it (key on weight so the field
          // updates if changed elsewhere, but lets the user type freely).
          Expanded(
            child: _EditField(
              label: 'Weight (g)',
              value: entry.weight.round().toString(),
              onChanged: (val) {
                final w = double.tryParse(val);
                if (w != null && w > 0) onWeightChanged(w);
              },
            ),
          ),
          const SizedBox(width: 12),
          // Calories — derived, read-only.
          Expanded(
            child: _ReadOnlyField(
              label: 'Calories',
              value: entry.nutrition.calories.round().toString(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Macros — derived from weight, read-only.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MacroDisplay(label: 'P', value: entry.nutrition.protein.round().toString(), color: const Color(0xFFFF6B6B)),
            _MacroDisplay(label: 'C', value: entry.nutrition.carbs.round().toString(), color: const Color(0xFF4ECDC4)),
            _MacroDisplay(label: 'F', value: entry.nutrition.fat.round().toString(), color: const Color(0xFFFFD93D)),
          ],
        ),
      ]),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final String value;
  final Function(String) onChanged;

  const _EditField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(8)),
        child: TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          style: AppTheme.numericMD.copyWith(fontSize: 16),
          decoration: const InputDecoration(isDense: true, border: InputBorder.none),
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

// Read-only numeric field — used for derived nutrition values (calories) that
// recalculate from weight and must not be directly edited.
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface2.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value,
            style: AppTheme.numericMD.copyWith(fontSize: 16, color: AppTheme.textSecondary)),
      ),
    ]);
  }
}

// Read-only macro chip — derived from weight, not directly editable.
class _MacroDisplay extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroDisplay({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface2.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(value,
              textAlign: TextAlign.center,
              style: AppTheme.numericMD.copyWith(fontSize: 14, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}
