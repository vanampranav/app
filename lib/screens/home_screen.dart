import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/ef_components.dart';
import '../services/shopify_service.dart';
import '../services/onesignal_service.dart';
import '../services/health_service.dart';
import '../services/fitdays_service.dart';
import '../models/device_model.dart';
import '../models/cart_model.dart';
import '../screens/ai_coach/ai_coach_screen.dart' as ai_coach;
import '../screens/nutrition/nutrition_log_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/shop_screen.dart';
import '../widgets/main_layout.dart';
import '../screens/devices_screen.dart';
import '../screens/measurement_screen.dart';
import '../services/member_service.dart';
import '../models/member_model.dart';
import '../widgets/device_scan_sheet.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/challenge_discovery_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_dashboard_screen.dart';
import 'package:elefit_app/features/challenge/presentation/providers/home_challenge_entry_provider.dart';

import 'package:elefit_app/features/challenge/presentation/widgets/notification_bell_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final ShopifyService _shopifyService;
  List<dynamic> _featuredProducts = [];
  bool _productsLoading = true;

  // Daily fitness stats (from local storage)
  int _caloriesConsumed = 0;
  int _caloriesGoal    = 2000;
  int _proteinG        = 0;
  int _proteinGoal     = 150;
  int _carbsG          = 0;
  int _carbsGoal       = 200;
  int _fatG            = 0;
  int _fatGoal         = 65;
  double? _latestWeight;
  int _streak          = 0;
  String _userName     = '';
  int    _stepsToday   = 0;
  int    _burnedToday  = 0;

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _shopifyService = Provider.of<ShopifyService>(context, listen: false);

    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));

    _loadAll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OneSignalService.triggerAppOpened();
      _headerAnim.forward();
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadFitnessStats(), _loadProducts(), _loadHealthData()]);
  }

  Future<void> _loadHealthData() async {
    // Silently read from Apple Health / Health Connect if connected.
    // Never blocks — returns 0 when permissions aren't granted.
    final health = HealthService();
    final connected = await health.isConnected;
    if (!connected) return;
    await health.checkPermissions();
    final results = await Future.wait([
      health.fetchTodaySteps(),
      health.fetchTodayActiveCalories(),
    ]);
    if (mounted) {
      setState(() {
        _stepsToday  = results[0] as int;
        _burnedToday = (results[1] as double).round();
      });
    }
  }

  Future<void> _loadFitnessStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (mounted) {
      setState(() {
        _caloriesConsumed = prefs.getInt('cal_consumed_$today') ?? 0;
        _caloriesGoal     = prefs.getInt('cal_goal')
                         ?? prefs.getInt('user_daily_calories')
                         ?? 2000;
        _proteinG         = prefs.getInt('protein_$today') ?? 0;
        _proteinGoal      = prefs.getInt('protein_goal') ?? 150;
        _carbsG           = prefs.getInt('carbs_$today') ?? 0;
        _carbsGoal        = prefs.getInt('carbs_goal') ?? 200;
        _fatG             = prefs.getInt('fat_$today') ?? 0;
        _fatGoal          = prefs.getInt('fat_goal') ?? 65;
        _latestWeight     = prefs.getDouble('latest_weight');
        _streak           = prefs.getInt('streak') ?? 0;
        _userName         = prefs.getString('user_name') ?? '';
      });
    }
  }

  Future<void> _loadProducts() async {
    // Serve cache instantly
    final cached = _shopifyService.getCachedProducts();
    if (cached != null) {
      _setProducts(cached);
      _shopifyService.getProducts().then((fresh) {
        if (mounted && fresh != null) _setProducts(fresh);
      });
      return;
    }
    final data = await _shopifyService.getProducts();
    if (mounted) {
      if (data != null) _setProducts(data);
      setState(() => _productsLoading = false);
    }
  }

  void _setProducts(Map<String, dynamic> data) {
    final edges = (data['products']?['edges'] as List?) ?? [];
    setState(() {
      _featuredProducts = edges.take(6).toList();
      _productsLoading = false;
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  // ── Track Weight flow ────────────────────────────────────────────────────
  void _onTrackWeightTapped() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXxl)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Record your weight', style: AppTheme.headingMD),
          const SizedBox(height: 6),
          Text('How would you like to record today\'s weight?',
              style: AppTheme.bodyMD, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          // Use scale
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _useScaleForWeight();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.lime,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: [
                  BoxShadow(color: AppTheme.lime.withValues(alpha: 0.3),
                      blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.monitor_weight_outlined,
                    color: Colors.black, size: 20),
                const SizedBox(width: 10),
                const Text('Use scale',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: Colors.black)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Enter manually
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _enterWeightManually();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_outlined,
                    color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text('Enter manually',
                    style: AppTheme.labelLG.copyWith(
                        color: AppTheme.textSecondary)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // If scale already connected → open MeasurementScreen directly.
  // If not → show scanner to find a body fat scale.
  Future<void> _useScaleForWeight() async {
    final fitDays = FitDaysService();

    if (fitDays.connectedDeviceMac != null) {
      // Already connected — load the device info from prefs
      await _openMeasurementScreen(fitDays);
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DeviceScanSheet(
        filterType: DeviceType.bodyFatScale,
        title: 'Connect body fat scale',
        subtitle: 'For full body composition measurements',
        onConnected: (device) async {
          if (!mounted) return;
          Navigator.pop(context); // close scanner
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeasurementScreen(
                connectedDevice: device,
                fitDaysService: fitDays,
              ),
            ),
          );
          // Refresh weight stat after returning
          _loadFitnessStats();
        },
      ),
    );
  }

  Future<void> _openMeasurementScreen(FitDaysService fitDays) async {
    // Load bound devices to get the FitDaysDevice object
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('bound_devices');
    FitDaysDevice? device;
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => FitDaysDevice.fromMap(e as Map<String, dynamic>))
            .toList();
        device = list.firstWhere(
          (d) => d.macAddress == fitDays.connectedDeviceMac,
          orElse: () => list.first,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementScreen(
          connectedDevice: device ??
              FitDaysDevice(
                macAddress: fitDays.connectedDeviceMac!,
                name: 'Scale',
                rssi: 0,
                deviceType: DeviceType.bodyFatScale,
              ),
          fitDaysService: fitDays,
        ),
      ),
    );
    _loadFitnessStats();
  }

  void _enterWeightManually() {
    final ctrl = TextEditingController(
      text: _latestWeight != null ? _latestWeight!.toStringAsFixed(1) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
        title: Row(children: [
          const Text('⚖️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('Enter weight', style: AppTheme.headingSM),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: AppTheme.numericLG.copyWith(fontSize: 32),
          cursorColor: AppTheme.lime,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffix: Text(' kg', style: AppTheme.headingSM.copyWith(
                color: AppTheme.textSecondary)),
            hintText: '70.0',
            hintStyle: AppTheme.numericLG.copyWith(
                fontSize: 32, color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.lime, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.labelLG.copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () async {
              final w = double.tryParse(ctrl.text);
              if (w == null || w < 20 || w > 300) return;
              Navigator.pop(ctx);
              await _saveManualWeight(w);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManualWeight(double weightKg) async {
    final fitDays = FitDaysService();
    final memberService = MemberService();
    final member = await memberService.ensureMemberExists();

    // Calculate BMI and BMR from member profile (no BIA required)
    final heightM = member.heightCm / 100.0;
    final bmi = heightM > 0 ? weightKg / (heightM * heightM) : null;
    final base = (10 * weightKg) + (6.25 * member.heightCm) - (5 * member.age.toDouble());
    final bmr = (member.gender == Gender.male ? base + 5 : base - 161).round();

    await memberService.addMeasurement(BodyMeasurement(
      id: MemberService.generateId(),
      memberId: member.id,
      timestamp: DateTime.now(),
      weightKg: weightKg,
      bmi: bmi,
      bmr: bmr > 0 ? bmr : null,
    ));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latest_weight', weightKg);
    setState(() => _latestWeight = weightKg);

    if (!mounted) return;

    // Open MeasurementScreen so the user can see their full history and body index.
    // Load a bound body fat scale as the "device" — the screen works in offline mode.
    FitDaysDevice device;
    try {
      final raw = prefs.getString('bound_devices');
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => FitDaysDevice.fromMap(e as Map<String, dynamic>))
            .where((d) => d.deviceType == DeviceType.bodyFatScale)
            .toList();
        device = list.isNotEmpty
            ? list.first
            : FitDaysDevice(
                macAddress: 'manual',
                name: 'Manual Entry',
                rssi: 0,
                deviceType: DeviceType.bodyFatScale,
              );
      } else {
        device = FitDaysDevice(
          macAddress: 'manual',
          name: 'Manual Entry',
          rssi: 0,
          deviceType: DeviceType.bodyFatScale,
        );
      }
    } catch (_) {
      device = FitDaysDevice(
        macAddress: 'manual',
        name: 'Manual Entry',
        rssi: 0,
        deviceType: DeviceType.bodyFatScale,
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementScreen(
          connectedDevice: device,
          fitDaysService: fitDays,
        ),
      ),
    );
    _loadFitnessStats();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingName {
    if (_userName.isNotEmpty) return ', ${_userName.split(' ').first}';
    return '';
  }

  double get _calProgress => _caloriesGoal > 0
      ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0)
      : 0.0;

  int get _caloriesRemaining => (_caloriesGoal - _caloriesConsumed).clamp(0, _caloriesGoal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppTheme.lime,
        backgroundColor: AppTheme.surface1,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreetingHeader(),
                  const SizedBox(height: AppTheme.lg),
                  _buildCalorieHero(),
                  const SizedBox(height: AppTheme.md),
                  _buildMacrosCard(),
                  const SizedBox(height: AppTheme.md),
                  _buildQuickActions(),
                  const SizedBox(height: AppTheme.lg),
                  _buildAiCoachBanner(),
                  const SizedBox(height: AppTheme.lg),
                  _buildStatsRow(),
                  const SizedBox(height: AppTheme.lg),
                  _buildFeaturedProducts(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App bar ─────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppTheme.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Image.asset(
          'assets/images/elefit_logo.png',
          height: 36,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const Text(
            'ELEFIT.',
            style: TextStyle(
              color: AppTheme.lime,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
      actions: [
        const NotificationBellIcon(),
        const SizedBox(width: 8),
        Consumer<CartModel>(
          builder: (_, cart, __) => GestureDetector(
            onTap: () => Navigator.push(context,
                EFPageRoute(page: const CartScreen())),
            child: Container(
              margin: const EdgeInsets.only(right: AppTheme.md),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface1,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Badge(
                isLabelVisible: cart.itemCount > 0,
                label: Text(
                  '${cart.itemCount}',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.black, fontWeight: FontWeight.w900),
                ),
                backgroundColor: AppTheme.lime,
                child: const Icon(Icons.shopping_bag_outlined,
                    color: AppTheme.textPrimary, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Greeting header ─────────────────────────────────────────────────────────

  Widget _buildGreetingHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting$_greetingName 👋',
                      style: AppTheme.headingMD,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(),
                      style: AppTheme.bodyMD,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_streak > 0) ...[
                const SizedBox(width: 12),
                EFStreakBadge(streak: _streak),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  // ─── Calorie hero ─────────────────────────────────────────────────────────────

  Widget _buildCalorieHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
      child: EFCard(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Row(children: [
          // Animated progress ring
          EFProgressRing(
            size: 140,
            strokeWidth: 11,
            progress: _calProgress,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<int>(
                  key: ValueKey(_caloriesRemaining),
                  tween: IntTween(begin: _caloriesGoal, end: _caloriesRemaining),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => Text(
                    '$val',
                    style: AppTheme.numericLG.copyWith(fontSize: 28),
                  ),
                ),
                Text('left', style: AppTheme.labelSM),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.lg),
          // Right-side stats
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TODAY\'S CALORIES', style: AppTheme.labelSM),
              const SizedBox(height: 6),
              // Count-up consumed number — larger and more dramatic
              TweenAnimationBuilder<int>(
                key: ValueKey(_caloriesConsumed),
                tween: IntTween(begin: 0, end: _caloriesConsumed),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => Text(
                  '$val',
                  style: AppTheme.numericXL.copyWith(
                      color: AppTheme.lime, fontSize: 36, height: 1),
                ),
              ),
              Text('of $_caloriesGoal kcal', style: AppTheme.bodyMD),
              const SizedBox(height: AppTheme.md),
              _buildCalStatRow(Icons.local_fire_department_outlined, 'Burned',
                  _burnedToday > 0 ? '$_burnedToday' : '--'),
              const SizedBox(height: 6),
              _buildCalStatRow(Icons.flag_outlined, 'Goal', '$_caloriesGoal'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCalStatRow(IconData icon, String label, String val) {
    return Row(children: [
      Icon(icon, size: 13, color: AppTheme.textTertiary),
      const SizedBox(width: 5),
      Expanded(
        child: Text(label,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis),
      ),
      Text('$val kcal',
          style: AppTheme.bodySM.copyWith(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
    ]);
  }

  // ─── Macros card ──────────────────────────────────────────────────────────────

  Widget _buildMacrosCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
      child: EFCard(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MACROS', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
                EFTag(label: 'Today', color: AppTheme.lime),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            EFMacroBar(
              label: 'Protein',
              current: _proteinG,
              target: _proteinGoal,
              color:  AppTheme.purpleLight,
            ),
            const SizedBox(height: AppTheme.md),
            EFMacroBar(
              label: 'Carbs',
              current: _carbsG,
              target: _carbsGoal,
              color: AppTheme.purpleLight,
            ),
            const SizedBox(height: AppTheme.md),
            EFMacroBar(
              label: 'Fat',
              current: _fatG,
              target: _fatGoal,
              color: AppTheme.purpleLight,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick actions ────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final challengeEntry = context.watch<HomeChallengeEntryProvider>();
    final hasActive = challengeEntry.hasActiveChallenge;
    final activeId = challengeEntry.activeParticipation?.challengeId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EFSectionHeader(title: 'Quick Actions'),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: EFQuickAction(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Log\nFood',
                  accentColor: AppTheme.lime,
                  onTap: () => Navigator.of(context).pushReplacement(
                    EFPageRoute(
                      page: MainLayout(
                        currentIndex: 1,
                        child: const NutritionLogScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: EFQuickAction(
                  icon: hasActive ? Icons.dashboard_customize_rounded : Icons.emoji_events_rounded,
                  label: hasActive ? 'My\nChallenge' : 'Join\nChallenge',
                  accentColor: AppTheme.lime,
                  onTap: () {
                    if (hasActive && activeId != null) {
                      Navigator.push(
                        context,
                        EFPageRoute(page: ParticipantChallengeDashboardScreen(challengeId: activeId)),
                      );
                    } else {
                      Navigator.push(
                        context,
                        EFPageRoute(page: const ChallengeDiscoveryScreen()),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: EFQuickAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI\nCoach',
                  accentColor: AppTheme.lime,
                  onTap: () => Navigator.push(
                      context, EFPageRoute(page: const ai_coach.AiCoachScreen())),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: EFQuickAction(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Track\nWeight',
                  accentColor: AppTheme.lime,
                  onTap: _onTrackWeightTapped,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── AI Coach banner ─────────────────────────────────────────────────────────

  Widget _buildAiCoachBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, EFPageRoute(page: const ai_coach.AiCoachScreen())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.md),
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          gradient: AppTheme.purpleGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.purple.withValues(alpha: 0.5)),
          boxShadow: AppTheme.shadowPurple,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EFTag(label: 'AI Powered', color: AppTheme.lime),
                  const SizedBox(height: AppTheme.sm),
                  Text('GEAR UP YOUR\nFITNESS JOURNEY', style: AppTheme.headingMD),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'Get a personalized meal & workout plan tailored to your goals.',
                    style: AppTheme.bodyMD,
                  ),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md, vertical: AppTheme.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.black, size: 14),
                        const SizedBox(width: 6),
                        Text('Build My Plan',
                            style: AppTheme.labelMD.copyWith(color: Colors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.lime.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.lime, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EFSectionHeader(title: 'Today\'s Stats'),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: EFStatTile(
                  label: 'Weight',
                  value: _latestWeight != null
                      ? _latestWeight!.toStringAsFixed(1)
                      : '--',
                  unit: 'kg',
                  icon: const Icon(Icons.monitor_weight_outlined),
                  valueColor: AppTheme.lime,
                  onTap: () => Navigator.push(
                      context, EFPageRoute(page: const DevicesScreen())),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: EFStatTile(
                  label: 'Steps',
                  value: _stepsToday > 0
                      ? _stepsToday >= 1000
                          ? '${(_stepsToday / 1000).toStringAsFixed(1)}k'
                          : '$_stepsToday'
                      : '--',
                  unit: _stepsToday > 0 ? 'steps' : '',
                  icon: const Icon(Icons.directions_walk_outlined),
                  valueColor: const Color(0xFF3B9EFF),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: EFStatTile(
                  label: 'Streak',
                  value: '$_streak',
                  unit: 'days',
                  icon: const Text('🔥', style: TextStyle(fontSize: 14)),
                  valueColor: const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Featured products ────────────────────────────────────────────────────────

  Widget _buildFeaturedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
          child: EFSectionHeader(
            title: 'Featured Gear',
            action: 'See All',
            onAction: () => Navigator.push(context, EFPageRoute(page: const ShopScreen())),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        if (_productsLoading)
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
              itemBuilder: (_, __) => _buildProductSkeleton(),
            ),
          )
        else if (_featuredProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
            child: EFCard(
              child: Row(
                children: [
                  const Text('🛍️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explore EleFit Gear', style: AppTheme.headingSM),
                        const SizedBox(height: 4),
                        Text('Premium fitness equipment for every level.',
                            style: AppTheme.bodyMD),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, EFPageRoute(page: const ShopScreen())),
                    child: const Icon(Icons.chevron_right,
                        color: AppTheme.lime, size: 24),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
              itemCount: _featuredProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
              itemBuilder: (_, i) => _buildProductCard(_featuredProducts[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(dynamic edge) {
    final product = edge['node'] as Map<String, dynamic>? ?? {};
    final images = (product['images']?['edges'] as List?) ?? [];
    final imageUrl = images.isNotEmpty ? images[0]['node']['url'] as String? : null;
    final title = product['title'] as String? ?? '';
    final variants = (product['variants']?['edges'] as List?) ?? [];
    final priceData = variants.isNotEmpty
        ? variants[0]['node']['price'] as Map?
        : null;
    final price = priceData?['amount'] as String? ?? '0';
    final currency = priceData?['currencyCode'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, EFPageRoute(page: const ShopScreen())),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 130, width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 130,
                        color: AppTheme.surface2,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.lime, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 130, color: AppTheme.surface2,
                        child: const Icon(Icons.fitness_center,
                            color: AppTheme.textTertiary, size: 40),
                      ),
                    )
                  : Container(
                      height: 130, color: AppTheme.surface2,
                      child: const Icon(Icons.fitness_center,
                          color: AppTheme.textTertiary, size: 40),
                    ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(AppTheme.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodySM.copyWith(color: AppTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${double.tryParse(price)?.toStringAsFixed(0) ?? price}',
                    style: AppTheme.labelMD.copyWith(color: AppTheme.lime),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSkeleton() {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EFShimmer(width: 160, height: 130, radius: AppTheme.radiusLg),
          Padding(
            padding: const EdgeInsets.all(AppTheme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EFShimmer(width: 120, height: 10),
                const SizedBox(height: 6),
                EFShimmer(width: 80, height: 10),
                const SizedBox(height: 6),
                EFShimmer(width: 50, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
