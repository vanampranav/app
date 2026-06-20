import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_layout.dart';
import '../../services/firebase_rest_service.dart';
import '../../services/health_service.dart';
import '../home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step map
//   0  : Welcome         (full-screen, no progress bar)
//   1  : Auth            (sign-up / sign-in, no progress bar)
//   2-8: Data collection (progress 1/7 … 7/7)
//   2  : Name
//   3  : Gender
//   4  : Birthdate
//   5  : Height & Weight
//   6  : Activity Level
//   7  : Health Connect  (skippable)
//   8  : Complete
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  // ── Navigation ─────────────────────────────────────────────────────────────
  int _step = 0;
  bool _goingForward = true;

  // ── Firebase ───────────────────────────────────────────────────────────────
  final FirebaseRestService _fb = FirebaseRestService();

  // ── Auth step state ────────────────────────────────────────────────────────
  bool   _isSignUp       = true;
  String _authEmail      = '';
  String _authPassword   = '';
  String _authFirstName  = '';
  bool   _authLoading    = false;
  String? _authError;
  bool   _showPassword   = false;

  // ── Profile data ───────────────────────────────────────────────────────────
  String _name          = '';
  String _gender        = '';
  int    _birthYear     = 1995;
  int    _birthMonth    = 6;
  int    _birthDay      = 15;
  bool   _isMetric      = true;
  int    _heightCm      = 170;
  int    _heightFt      = 5;
  int    _heightIn      = 7;
  double _weightKg      = 70.0;
  double _weightLbs     = 154.0;
  String _activityLevel = '';

  // ── Health Connect step ────────────────────────────────────────────────────
  bool _healthConnected   = false;
  bool _healthConnecting  = false;

  // ── Complete step ──────────────────────────────────────────────────────────
  bool   _saving        = false;

  // ── Name text controller ───────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;

  // ── Drum-picker controllers ────────────────────────────────────────────────
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _heightCmCtrl;
  late FixedExtentScrollController _heightFtCtrl;
  late FixedExtentScrollController _heightInCtrl;
  late FixedExtentScrollController _weightKgCtrl;
  late FixedExtentScrollController _weightLbsCtrl;

  // ── Static lists ───────────────────────────────────────────────────────────
  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const _monthShort = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  List<String> get _dayItems    => List.generate(31,  (i) => '${i + 1}');
  List<String> get _yearItems   => List.generate(69,  (i) => '${1940 + i}');
  List<String> get _htCmItems   => List.generate(81,  (i) => '${140 + i}');
  List<String> get _htFtItems   => ['4', '5', '6', '7'];
  List<String> get _htInItems   => List.generate(12,  (i) => '$i');
  List<String> get _wtKgItems   => List.generate(171, (i) => '${30 + i}');
  List<String> get _wtLbItems   => List.generate(375, (i) => '${66 + i}');

  @override
  void initState() {
    super.initState();
    _fb.init();
    _nameCtrl      = TextEditingController(text: _name);
    _monthCtrl     = FixedExtentScrollController(initialItem: 5);
    _dayCtrl       = FixedExtentScrollController(initialItem: 14);
    _yearCtrl      = FixedExtentScrollController(initialItem: 55);
    _heightCmCtrl  = FixedExtentScrollController(initialItem: 30);
    _heightFtCtrl  = FixedExtentScrollController(initialItem: 1);
    _heightInCtrl  = FixedExtentScrollController(initialItem: 7);
    _weightKgCtrl  = FixedExtentScrollController(initialItem: 40);
    _weightLbsCtrl = FixedExtentScrollController(initialItem: 88);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _monthCtrl.dispose();   _dayCtrl.dispose();      _yearCtrl.dispose();
    _heightCmCtrl.dispose();_heightFtCtrl.dispose(); _heightInCtrl.dispose();
    _weightKgCtrl.dispose();_weightLbsCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (_step == 1) { _handleAuth(); return; }
    if (_step < 8) setState(() { _goingForward = true; _step++; });
  }

  void _back() {
    if (_step > 0) setState(() { _goingForward = false; _step--; });
  }

  bool get _canContinue {
    switch (_step) {
      case 1:
        final validEmail    = _authEmail.contains('@') && _authEmail.contains('.');
        final validPassword = _authPassword.length >= 6;
        final validName     = !_isSignUp || _authFirstName.trim().isNotEmpty;
        return validEmail && validPassword && validName;
      case 2: return _name.trim().isNotEmpty;
      case 3: return _gender.isNotEmpty;
      case 6: return _activityLevel.isNotEmpty;
      case 7: return true; // Health Connect is always skippable
      default: return true;
    }
  }

  // ── Auth handler ────────────────────────────────────────────────────────────
  void _handleAuth() {
    _doAuth();
  }

  Future<void> _doAuth() async {
    setState(() { _authLoading = true; _authError = null; });
    try {
      if (_isSignUp) {
        await _fb.createAccount(_authEmail.trim(), _authPassword);
        // Seed the users/{uid} record with credits so AI Coach works immediately.
        await _fb.updateUserProfile({
          'email':     _authEmail.trim(),
          'firstName': _authFirstName.trim(),
          'credits':   5,
        });
        setState(() { _name = _authFirstName.trim(); });
      } else {
        // Sign in
        await _fb.signIn(_authEmail.trim(), _authPassword);
        // Check if this user already completed onboarding
        final existing = await _fb.getOnboardingProfile();
        if (existing != null && existing['dailyCalorieTarget'] != null) {
          // Already onboarded — pre-fill everything and go straight to home.
          _prefillFromProfile(existing);
          final prefs = await SharedPreferences.getInstance();
          await _saveLocalPrefs();
          await prefs.setBool('onboarded', true);
          setState(() => _authLoading = false);
          _goToHome();
          return;
        }
        // Returning user who never finished onboarding — pre-fill name if possible.
        final userDoc = await _fb.getUserProfile();
        if (userDoc != null) {
          final fn = (userDoc['firstName'] ?? '').toString();
          if (fn.isNotEmpty) setState(() => _name = fn);
        }
      }
      setState(() { _authLoading = false; _goingForward = true; _step = 2; });
    } catch (e) {
      setState(() {
        _authLoading = false;
        _authError = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection reset') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        msg.contains('errno = 54') ||
        msg.contains('clientexception') ||
        msg.contains('handshake') ||
        msg.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('email') && msg.contains('already')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (msg.contains('invalid') && msg.contains('credential') ||
        msg.contains('wrong password') ||
        msg.contains('user not found')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('too many')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('weak password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  void _prefillFromProfile(Map<String, dynamic> p) {
    if (p['firstName']     != null) _name           = p['firstName'].toString();
    if (p['gender']        != null) _gender         = p['gender'].toString();
    if (p['birthYear']     != null) _birthYear      = (p['birthYear']     as num).toInt();
    if (p['birthMonth']    != null) _birthMonth     = (p['birthMonth']    as num).toInt();
    if (p['birthDay']      != null) _birthDay       = (p['birthDay']      as num).toInt();
    if (p['heightCm']      != null) _heightCm       = (p['heightCm']      as num).toInt();
    if (p['weightKg']      != null) _weightKg       = (p['weightKg']      as num).toDouble();
    if (p['activityLevel'] != null) _activityLevel  = p['activityLevel'].toString();
  }

  // ── Calculations ────────────────────────────────────────────────────────────
  int _calcAge() {
    final now = DateTime.now();
    int age = now.year - _birthYear;
    if (now.month < _birthMonth ||
        (now.month == _birthMonth && now.day < _birthDay)) age--;
    return age.clamp(10, 100);
  }

  int _calculateCalories() {
    final age = _calcAge();
    final wKg = _isMetric ? _weightKg : _weightLbs / 2.205;
    final hCm = _isMetric
        ? _heightCm.toDouble()
        : (_heightFt * 30.48 + _heightIn * 2.54);
    double bmr;
    if (_gender == 'female') {
      bmr = 10 * wKg + 6.25 * hCm - 5 * age - 161;
    } else {
      bmr = 10 * wKg + 6.25 * hCm - 5 * age + 5;
    }
    const mult = {
      'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55,
      'active': 1.725,  'very_active': 1.9,
    };
    final tdee = bmr * (mult[_activityLevel] ?? 1.55);
    return tdee.round().clamp(1200, 4000);
  }

  Map<String, int> _calcMacros(int kcal) {
    final wKg    = _isMetric ? _weightKg : _weightLbs / 2.205;
    final protein = (wKg * 1.8).round();
    final fatCals = (kcal * 0.28).round();
    final fat     = (fatCals / 9).round();
    final carbs   = ((kcal - protein * 4 - fatCals) / 4).round().clamp(0, 500);
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  double get _resolvedWeightKg  => _isMetric ? _weightKg      : _weightLbs / 2.205;
  double get _resolvedHeightCm  => _isMetric ? _heightCm.toDouble() : (_heightFt * 30.48 + _heightIn * 2.54);

  // ── Save helpers ────────────────────────────────────────────────────────────
  Future<void> _saveLocalPrefs() async {
    final prefs  = await SharedPreferences.getInstance();
    final kcal   = _calculateCalories();
    final macros = _calcMacros(kcal);

    await prefs.setString('user_name',     _name.trim());
    await prefs.setString('user_gender',   _gender);
    await prefs.setInt('user_birth_year',  _birthYear);
    await prefs.setInt('user_birth_month', _birthMonth);
    await prefs.setInt('user_birth_day',   _birthDay);
    await prefs.setDouble('user_weight_kg', _resolvedWeightKg);
    await prefs.setDouble('user_height_cm', _resolvedHeightCm);
    await prefs.setString('user_activity',  _activityLevel);

    // Write under both key names so every screen reads the right value
    await prefs.setInt('user_daily_calories', kcal);
    await prefs.setInt('cal_goal',     kcal);
    await prefs.setInt('protein_goal', macros['protein'] ?? 0);
    await prefs.setInt('carbs_goal',   macros['carbs']   ?? 0);
    await prefs.setInt('fat_goal',     macros['fat']     ?? 0);
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      final kcal   = _calculateCalories();
      final macros = _calcMacros(kcal);
      final now    = DateTime.now().toUtc().toIso8601String();

      // ── Save to Firestore `profiles/{uid}` ─────────────────────────────
      await _fb.saveOnboardingProfile({
        'uid':              _fb.uid ?? '',
        'email':            _fb.email ?? _authEmail,
        'firstName':        _name.trim().split(' ').first,
        'gender':           _gender,
        'birthYear':        _birthYear,
        'birthMonth':       _birthMonth,
        'birthDay':         _birthDay,
        'age':              _calcAge(),
        'heightCm':         _resolvedHeightCm,
        'weightKg':         _resolvedWeightKg,
        'activityLevel':    _activityLevel,
        'dailyCalorieTarget': kcal,
        'macroProtein':     macros['protein'] ?? 0,
        'macroCarbs':       macros['carbs']   ?? 0,
        'macroFat':         macros['fat']     ?? 0,
        'onboardedAt':      now,
        'createdAt':        now,
      });

      // ── Save to local SharedPreferences + mark onboarded ───────────────
      await _saveLocalPrefs();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarded', true);

      _goToHome();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainLayout(currentIndex: 0, child: const HomeScreen()),
      ),
      (_) => false,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        resizeToAvoidBottomInset: true,
        body: _step == 0 ? _buildWelcome() : _buildStepScaffold(),
      ),
    );
  }

  Widget _buildStepScaffold() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, anim) {
                final slide = Tween<Offset>(
                  begin: _goingForward
                      ? const Offset(0.10, 0)
                      : const Offset(-0.10, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    // step 1 = auth  → back button only, no progress
    // step 2-9       → back + step label + progress bar
    final showProgress = _step >= 2;
    final dataStep     = _step - 1; // 1-9 range displayed as "1 / 9" .. "9 / 9"

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _back,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textPrimary, size: 16),
                ),
              ),
              const Spacer(),
              if (showProgress)
                Text('$dataStep / 7',
                    style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: dataStep / 7),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,  // dataStep / 9
                  backgroundColor: AppTheme.surface3,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.lime),
                  minHeight: 3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    if (_healthConnecting) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: SizedBox(
          height: 58,
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.lime),
          ),
        ),
      );
    }
    if (_authLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: SizedBox(
          height: 58,
          child: Center(child: CircularProgressIndicator(color: AppTheme.lime)),
        ),
      );
    }
    if (_saving) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.surface3,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: AppTheme.lime, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Saving your profile...',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      );
    }

    String label;
    if (_step == 8)                      label = "Let's Go! 🚀";
    else if (_step == 7 && _healthConnected) label = 'Continue ✓';
    else if (_step == 7)                 label = 'Skip for now';
    else if (_step == 1 && _isSignUp)    label = 'Create Account';
    else if (_step == 1 && !_isSignUp)   label = 'Sign In';
    else                                 label = 'Continue';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: _EFButton(
        label: label,
        enabled: _canContinue,
        onTap: _step == 8 ? _complete : _next,
      ),
    );
  }

  // ── Step router ─────────────────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_step) {
      case 1: return _buildAuthStep();
      case 2: return _buildNameStep();
      case 3: return _buildGenderStep();
      case 4: return _buildBirthdateStep();
      case 5: return _buildHeightWeightStep();
      case 6: return _buildActivityStep();
      case 7: return _buildHealthConnectStep();
      case 8: return _buildCompleteStep();
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 0 — Welcome
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWelcome() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/elefit_logo.png',
              height: 36,
              fit: BoxFit.fitHeight,
              errorBuilder: (_, __, ___) => Text(
                'ELEFIT.',
                style: AppTheme.headingLG.copyWith(
                  color: AppTheme.lime,
                  letterSpacing: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Your fitness,\nbeautifully\ntracked.',
              style: AppTheme.displayLG.copyWith(height: 1.05, letterSpacing: -1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Smart scale integration, AI-powered plans,\nand nutrition tracking — all in one place.',
              style: AppTheme.bodyMD.copyWith(height: 1.65),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _FeatureChip(label: '⚡ AI Coach'),
                _FeatureChip(label: '📊 Smart Scale'),
                _FeatureChip(label: '🥗 Nutrition Log'),
                _FeatureChip(label: '❤️ Health Sync'),
              ],
            ),
            const Spacer(),
            _EFButton(
              label: 'Get Started',
              enabled: true,
              onTap: _next,
            ),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: () {
                  // Jump straight to sign-in mode
                  setState(() { _isSignUp = false; _goingForward = true; _step = 1; });
                },
                child: Text.rich(TextSpan(
                  text: 'Already have an account? ',
                  style: AppTheme.bodyMD,
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: AppTheme.bodyMD.copyWith(
                          color: AppTheme.lime, fontWeight: FontWeight.w800),
                    ),
                  ],
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Auth (Sign Up / Sign In)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignUp ? 'Create your\naccount' : 'Welcome\nback',
          style: AppTheme.displayMD,
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Your data is saved securely to your profile.'
              : 'Sign in to continue your fitness journey.',
          style: AppTheme.bodyMD,
        ),
        const SizedBox(height: 28),
        // ── Mode toggle ──────────────────────────────────────────────────
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Row(
            children: [
              Expanded(child: _authTab('Create Account', _isSignUp, () {
                setState(() { _isSignUp = true; _authError = null; });
              })),
              Expanded(child: _authTab('Sign In', !_isSignUp, () {
                setState(() { _isSignUp = false; _authError = null; });
              })),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // ── First name (sign-up only) ─────────────────────────────────────
        if (_isSignUp) ...[
          _EFTextField(
            hint: 'First name',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.name,
            onChanged: (v) => setState(() => _authFirstName = v),
          ),
          const SizedBox(height: 12),
        ],
        // ── Email ────────────────────────────────────────────────────────
        _EFTextField(
          hint: 'Email address',
          autofocus: !_isSignUp,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => setState(() { _authEmail = v; _authError = null; }),
        ),
        const SizedBox(height: 12),
        // ── Password ─────────────────────────────────────────────────────
        _EFPasswordField(
          hint: 'Password (min 6 characters)',
          showPassword: _showPassword,
          onChanged: (v) => setState(() { _authPassword = v; _authError = null; }),
          onToggleVisibility: () => setState(() => _showPassword = !_showPassword),
        ),
        // ── Error ────────────────────────────────────────────────────────
        if (_authError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_authError!,
                      style: AppTheme.bodyMD.copyWith(color: AppTheme.error)),
                ),
              ],
            ),
          ),
        ],
        // ── Forgot password ───────────────────────────────────────────────
        if (!_isSignUp) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _showForgotPasswordDialog,
              child: Text(
                'Forgot password?',
                style: AppTheme.bodyMD.copyWith(
                    color: AppTheme.lime, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        // ── Firebase note ─────────────────────────────────────────────────
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppTheme.textTertiary, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your data is encrypted with AES-256 and stored securely.',
                style: AppTheme.bodySM,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _authTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? AppTheme.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              color: active ? Colors.black : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    String resetEmail = _authEmail;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
          title: Text('Reset password',
              style: AppTheme.headingMD.copyWith(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("We'll send a reset link to your email.",
                  style: AppTheme.bodyMD),
              const SizedBox(height: 16),
              _EFTextField(
                hint: 'Email address',
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => resetEmail = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTheme.labelLG.copyWith(
                      color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _fb.sendPasswordReset(resetEmail.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Reset link sent — check your inbox.'),
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_friendlyError(e)),
                      backgroundColor: AppTheme.error,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lime,
                foregroundColor: Colors.black,
              ),
              child: const Text('Send Link',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Name
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: "What's your\nname?",
          subtitle: "We'll use this to personalize\nyour experience.",
        ),
        const SizedBox(height: 36),
        _EFTextField(
          hint: 'Your first name',
          autofocus: true,
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => _name = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppTheme.textTertiary, size: 14),
          const SizedBox(width: 6),
          Text('Your data stays private and on-device.', style: AppTheme.bodySM),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Gender
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGenderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Choose your\ngender',
          subtitle: 'This will be used to calibrate\nyour custom plan.',
        ),
        const SizedBox(height: 36),
        _SelectTile(label: 'Male',   icon: '♂', selected: _gender == 'male',
            onTap: () => setState(() => _gender = 'male')),
        const SizedBox(height: 12),
        _SelectTile(label: 'Female', icon: '♀', selected: _gender == 'female',
            onTap: () => setState(() => _gender = 'female')),
        const SizedBox(height: 12),
        _SelectTile(label: 'Other',  icon: '◎', selected: _gender == 'other',
            onTap: () => setState(() => _gender = 'other')),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Birthdate
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBirthdateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'When were\nyou born?',
          subtitle: 'This helps calculate your\nmetabolic rate accurately.',
        ),
        const SizedBox(height: 36),
        Container(
          height: 230,
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Row(children: [
            Expanded(flex: 4, child: _DrumPicker(
              items: _monthNames, controller: _monthCtrl,
              containerColor: AppTheme.surface1,
              onChanged: (i) => setState(() => _birthMonth = i + 1),
            )),
            Container(width: 1, color: AppTheme.divider),
            Expanded(flex: 2, child: _DrumPicker(
              items: _dayItems, controller: _dayCtrl,
              containerColor: AppTheme.surface1,
              onChanged: (i) => setState(() => _birthDay = i + 1),
            )),
            Container(width: 1, color: AppTheme.divider),
            Expanded(flex: 3, child: _DrumPicker(
              items: _yearItems, controller: _yearCtrl,
              containerColor: AppTheme.surface1,
              onChanged: (i) => setState(() => _birthYear = 1940 + i),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${_monthShort[_birthMonth - 1]} $_birthDay, $_birthYear · Age ${_calcAge()}',
            style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5 — Height & Weight
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeightWeightStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Height &\nweight',
          subtitle: 'This will be used to calibrate\nyour custom plan.',
        ),
        const SizedBox(height: 20),
        _UnitToggle(
          isMetric: _isMetric,
          onChanged: (v) => setState(() => _isMetric = v),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _PickerCard(
                label: 'Height',
                unit: _isMetric ? 'cm' : 'ft / in',
                child: _isMetric
                    ? _DrumPicker(
                        items: _htCmItems, controller: _heightCmCtrl,
                        containerColor: AppTheme.surface2,
                        onChanged: (i) => setState(() => _heightCm = 140 + i),
                      )
                    : Row(children: [
                        Expanded(child: _DrumPicker(
                          items: _htFtItems, controller: _heightFtCtrl,
                          containerColor: AppTheme.surface2,
                          onChanged: (i) => setState(() => _heightFt = 4 + i),
                        )),
                        Container(width: 1, color: AppTheme.divider),
                        Expanded(child: _DrumPicker(
                          items: _htInItems, controller: _heightInCtrl,
                          containerColor: AppTheme.surface2,
                          onChanged: (i) => setState(() => _heightIn = i),
                        )),
                      ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: _PickerCard(
                label: 'Weight',
                unit: _isMetric ? 'kg' : 'lbs',
                child: _DrumPicker(
                  items: _isMetric ? _wtKgItems : _wtLbItems,
                  controller: _isMetric ? _weightKgCtrl : _weightLbsCtrl,
                  containerColor: AppTheme.surface2,
                  onChanged: (i) => setState(() {
                    if (_isMetric) _weightKg  = 30.0 + i;
                    else           _weightLbs = 66.0 + i;
                  }),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              _isMetric
                  ? '$_heightCm cm  ·  ${_weightKg.round()} kg'
                  : '$_heightFt\'$_heightIn"  ·  ${_weightLbs.round()} lbs',
              style: AppTheme.labelLG.copyWith(color: AppTheme.lime),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 6 — Activity
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActivityStep() {
    final items = [
      {'id': 'sedentary',   'emoji': '🪑', 'label': 'Sedentary',         'desc': 'Little to no exercise'},
      {'id': 'light',       'emoji': '🚶', 'label': 'Lightly Active',    'desc': '1–2 workouts per week'},
      {'id': 'moderate',    'emoji': '🏃', 'label': 'Moderately Active', 'desc': '3–5 workouts per week'},
      {'id': 'active',      'emoji': '💪', 'label': 'Very Active',       'desc': '6–7 workouts per week'},
      {'id': 'very_active', 'emoji': '🔥', 'label': 'Extra Active',      'desc': 'Intense daily training'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'How active\nare you?',
          subtitle: 'Choose your typical weekly activity level.',
        ),
        const SizedBox(height: 28),
        ...items.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ActivityTile(
            emoji: a['emoji']!, label: a['label']!, desc: a['desc']!,
            selected: _activityLevel == a['id'],
            onTap: () => setState(() => _activityLevel = a['id']!),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 9 — Health Connect (skippable)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _connectHealth() async {
    setState(() => _healthConnecting = true);
    final granted = await HealthService().requestPermissions();
    setState(() {
      _healthConnected  = granted;
      _healthConnecting = false;
    });
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Health Connect requires a Play Store build. '
            'Connect later once published, or test on the emulator.'),
        backgroundColor: AppTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ));
    }
  }

  Widget _buildHealthConnectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Connect your\nhealth data',
          subtitle: 'Sync steps, burned calories, sleep, and\nbody data with your device.',
        ),
        const SizedBox(height: 32),

        // ── Platform card ───────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _healthConnected
                ? AppTheme.lime.withOpacity(0.07)
                : AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            border: Border.all(
              color: _healthConnected
                  ? AppTheme.lime.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
              width: _healthConnected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _healthConnected
                    ? AppTheme.lime.withOpacity(0.15)
                    : AppTheme.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _healthConnected ? '✓' : '❤️',
                  style: TextStyle(
                    fontSize: _healthConnected ? 22 : 24,
                    color: AppTheme.lime,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apple Health / Health Connect',
                    style: AppTheme.headingSM.copyWith(
                      color: _healthConnected
                          ? AppTheme.lime
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _healthConnected
                        ? 'Connected — syncing body data & nutrition'
                        : 'Steps · Burned calories · Sleep · Body weight',
                    style: AppTheme.bodySM,
                  ),
                ],
              ),
            ),
            if (!_healthConnected) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _connectHealth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Text('Connect',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // ── What gets synced ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHAT GETS SYNCED',
                  style: AppTheme.labelMD.copyWith(
                      color: AppTheme.textTertiary)),
              const SizedBox(height: 12),
              _syncRow('📥', 'Reads',
                  'Steps, burned calories, sleep, heart rate'),
              const SizedBox(height: 8),
              _syncRow('📤', 'Writes',
                  'Scale measurements, body fat %, nutrition logs'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Privacy note ────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppTheme.textTertiary, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'All health data stays on your device. '
              'EleFit never uploads it to external servers.',
              style: AppTheme.bodySM,
            ),
          ),
        ]),

        if (!_healthConnected) ...[
          const SizedBox(height: 20),
          Center(
            child: Text(
              "You can always connect later in\nProfile → Settings → Connected Apps",
              style: AppTheme.bodySM.copyWith(
                  color: AppTheme.textTertiary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _syncRow(String emoji, String label, String detail) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTheme.labelLG.copyWith(
                color: AppTheme.textPrimary, fontSize: 12)),
        Text(detail,
            style: AppTheme.bodySM),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 10 — Complete
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCompleteStep() {
    final kcal   = _calculateCalories();
    final macros = _calcMacros(kcal);
    final first  = _name.trim().isEmpty ? 'You' : _name.trim().split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$first, your plan\nis ready 🎉',
            style: AppTheme.displayMD.copyWith(height: 1.1)),
        const SizedBox(height: 8),
        Text('Your plan will be saved when you tap Let\'s Go.',
            style: AppTheme.bodyMD),
        const SizedBox(height: 28),
        // Calorie hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.lime, Color(0xFFD4E84F)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            boxShadow: [
              BoxShadow(
                color: AppTheme.lime.withOpacity(0.35),
                blurRadius: 28, offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(children: [
            Text('$kcal',
                style: const TextStyle(
                    fontSize: 64, fontWeight: FontWeight.w900,
                    color: Colors.black, letterSpacing: -2, height: 1)),
            const SizedBox(height: 6),
            const Text('KCAL / DAY',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900,
                    color: Colors.black54, letterSpacing: 2.5)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _MacroCard(value: '${macros['protein']}g', label: 'PROTEIN',
              color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 10),
          _MacroCard(value: '${macros['carbs']}g',   label: 'CARBS',
              color: AppTheme.lime),
          const SizedBox(width: 10),
          _MacroCard(value: '${macros['fat']}g',     label: 'FAT',
              color: const Color(0xFFFFAA00)),
        ]),
        const SizedBox(height: 14),
        // Insight card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.lime.withOpacity(0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'Hitting $kcal kcal/day consistently will keep your energy stable and support your fitness goals.',
              style: AppTheme.bodyMD.copyWith(height: 1.55),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        // Firebase save note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('☁️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'All your data will be saved securely and linked to '
              'your account at ${_fb.email ?? _authEmail}.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR PLAN INCLUDES',
                  style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
              const SizedBox(height: 14),
              _PlanFeatureRow(emoji: '🤖', text: 'AI-generated 7-day meal & workout plan'),
              const SizedBox(height: 10),
              _PlanFeatureRow(emoji: '⚖️', text: 'Smart scale body composition tracking'),
              const SizedBox(height: 10),
              _PlanFeatureRow(emoji: '🥗', text: 'Daily food log with calorie counting'),
              const SizedBox(height: 10),
              _PlanFeatureRow(
                emoji: _healthConnected ? '✅' : '❤️',
                text: _healthConnected
                    ? 'Apple Health / Health Connect — connected'
                    : 'Apple Health & Google Health sync',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.displayMD),
        const SizedBox(height: 8),
        Text(subtitle, style: AppTheme.bodyMD),
      ],
    );
  }
}

// ── Continue / action button ──────────────────────────────────────────────────
class _EFButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _EFButton({required this.label, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.lime : AppTheme.surface3,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: enabled
              ? [BoxShadow(color: AppTheme.lime.withOpacity(0.30),
                    blurRadius: 20, offset: const Offset(0, 8))]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: enabled ? Colors.black : AppTheme.textTertiary)),
        ),
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────
class _EFTextField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? initialValue;
  final TextEditingController? controller;
  const _EFTextField({
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.initialValue,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      controller: controller ?? (initialValue != null
          ? (TextEditingController()..text = initialValue!)
          : null),
      style: AppTheme.headingLG.copyWith(color: AppTheme.textPrimary),
      cursorColor: AppTheme.lime,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.headingLG.copyWith(color: AppTheme.textTertiary),
        filled: true,
        fillColor: AppTheme.surface1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lime, width: 2),
        ),
      ),
    );
  }
}

// ── Password field with show/hide ─────────────────────────────────────────────
class _EFPasswordField extends StatelessWidget {
  final String hint;
  final bool showPassword;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  const _EFPasswordField({
    required this.hint,
    required this.showPassword,
    required this.onChanged,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      obscureText: !showPassword,
      style: AppTheme.headingLG.copyWith(color: AppTheme.textPrimary, fontSize: 20),
      cursorColor: AppTheme.lime,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.bodyLG.copyWith(color: AppTheme.textTertiary),
        filled: true,
        fillColor: AppTheme.surface1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lime, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppTheme.textTertiary,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}

// ── Selection tile ────────────────────────────────────────────────────────────
class _SelectTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  const _SelectTile({
    required this.label, this.subtitle, this.icon, this.emoji,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime.withOpacity(0.07) : AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? AppTheme.lime : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
          ] else if (icon != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.lime.withOpacity(0.15)
                    : AppTheme.surface3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon!,
                    style: TextStyle(
                        fontSize: 18,
                        color: selected ? AppTheme.lime : AppTheme.textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTheme.headingSM.copyWith(
                      color: selected ? AppTheme.lime : AppTheme.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppTheme.bodySM),
              ],
            ],
          )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppTheme.lime : Colors.transparent,
              border: Border.all(
                color: selected ? AppTheme.lime : AppTheme.textTertiary,
                width: 1.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 15)
                : null,
          ),
        ]),
      ),
    );
  }
}

// ── Activity tile ─────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final String emoji, label, desc;
  final bool selected;
  final VoidCallback onTap;
  const _ActivityTile({
    required this.emoji, required this.label, required this.desc,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime.withOpacity(0.07) : AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? AppTheme.lime : Colors.white.withOpacity(0.07),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.lime.withOpacity(0.15)
                  : AppTheme.surface3,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTheme.headingSM.copyWith(
                      color: selected ? AppTheme.lime : AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(desc, style: AppTheme.bodySM),
            ],
          )),
          if (selected)
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppTheme.lime),
              child: const Icon(Icons.check_rounded,
                  color: Colors.black, size: 15),
            ),
        ]),
      ),
    );
  }
}

// ── Macro card ────────────────────────────────────────────────────────────────
class _MacroCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MacroCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(children: [
          Text(value, style: AppTheme.numericMD),
          const SizedBox(height: 6),
          Text(label,
              style: AppTheme.labelSM.copyWith(
                  color: color, letterSpacing: 1.0)),
        ]),
      ),
    );
  }
}

// ── Plan feature row ──────────────────────────────────────────────────────────
class _PlanFeatureRow extends StatelessWidget {
  final String emoji, text;
  const _PlanFeatureRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: AppTheme.bodyMD.copyWith(
                  color: AppTheme.textPrimary))),
    ]);
  }
}

// ── Feature chip (welcome) ────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(label,
          style: AppTheme.labelMD.copyWith(
              color: AppTheme.textSecondary)),
    );
  }
}

// ── Imperial / Metric toggle ──────────────────────────────────────────────────
class _UnitToggle extends StatelessWidget {
  final bool isMetric;
  final ValueChanged<bool> onChanged;
  const _UnitToggle({required this.isMetric, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('Imperial', !isMetric, () => onChanged(false)),
          _tab('Metric',    isMetric, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.black : AppTheme.textSecondary)),
      ),
    );
  }
}

// ── Picker card wrapper ───────────────────────────────────────────────────────
class _PickerCard extends StatelessWidget {
  final String label, unit;
  final Widget child;
  const _PickerCard({required this.label, required this.unit, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
          child: Text('$label · $unit',
              style: AppTheme.labelMD.copyWith(
                  color: AppTheme.textTertiary)),
        ),
        child,
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRUM PICKER
// ═══════════════════════════════════════════════════════════════════════════════
class _DrumPicker extends StatelessWidget {
  final List<String> items;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;
  final Color containerColor;
  static const double _itemH = 52.0;

  const _DrumPicker({
    required this.items,
    required this.controller,
    required this.onChanged,
    required this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _itemH,
            perspective: 0.003,
            diameterRatio: 2.0,
            useMagnifier: true,
            magnification: 1.15,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: items.length,
              builder: (_, i) => Center(
                child: Text(items[i],
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ),
            ),
          ),
          // Selection indicator lines
          IgnorePointer(
            child: Center(
              child: SizedBox(
                height: _itemH,
                child: Column(children: [
                  Container(height: 1, color: AppTheme.lime.withOpacity(0.35)),
                  const Spacer(),
                  Container(height: 1, color: AppTheme.lime.withOpacity(0.35)),
                ]),
              ),
            ),
          ),
          // Top fade
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [containerColor, containerColor.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
          // Bottom fade
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [containerColor, containerColor.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
