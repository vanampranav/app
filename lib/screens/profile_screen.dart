import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/firebase_rest_service.dart';
import '../services/shopify_service.dart';
import '../services/auth_bridge.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/challenge_discovery_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_my_challenges_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_list_screen.dart';
import 'settings_screen.dart';
import 'OrdersScreen.dart';
import 'HelpScreen.dart';
import 'address_screen.dart';
import 'wishlist_screen.dart';
class ProfileScreen extends StatefulWidget {
  final bool showAiCoachNav;
  final VoidCallback? onAiAssistantTap;
  final VoidCallback? onWeeklyScheduleTap;
  const ProfileScreen({Key? key, this.showAiCoachNav = false, this.onAiAssistantTap, this.onWeeklyScheduleTap}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseRestService _fbService = FirebaseRestService();
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initAndCheckAuth();
  }

  static const _cacheKey = 'profile_cache';

  Future<void> _initAndCheckAuth() async {
    // 1. Load cached profile instantly (no spinner, no network)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        if (mounted) setState(() => _profile = Map<String, dynamic>.from(jsonDecode(cached)));
      } catch (_) {}
    }

    // 2. Init auth (reads secure storage — fast local I/O)
    await _fbService.init();
    if (!_fbService.isLoggedIn) return;

    // 3. Refresh from network in background — no blocking spinner
    _fetchProfile(background: _profile != null);
  }

  Future<void> _fetchProfile({bool background = false}) async {
    if (!background) setState(() { _isLoading = true; _error = null; });
    try {
      final profile = await _fbService.getUserProfile();
      if (profile != null && mounted) {
        setState(() { _profile = profile; _isLoading = false; });
        // Persist for next launch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(profile));
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    final shopify = context.read<ShopifyService>();
    setState(() { _isLoading = true; _error = null; });
    try {
      // 1. Sign in to REST service — with Shopify bridge fallback for store /
      //    AI-coach users whose Firebase password differs from what they type.
      final bridgeToken = await bridgeSignIn(
        email: email, password: password, fb: _fbService, shopify: shopify);
      // 2. Sign in to Firebase Auth SDK (used by the Challenge feature / Firestore):
      //    via the custom token if the bridge ran, otherwise with the password.
      if (mounted) {
        if (bridgeToken != null) {
          await context.read<AuthService>().signInWithCustomToken(bridgeToken);
        } else {
          await context.read<AuthService>().signIn(email, password);
        }
      }
      await _fetchProfile();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _fbService.signOut();
    if (mounted) {
      await context.read<AuthService>().signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    // Clear this user's locally-cached nutrition goals/consumption + the
    // onboarding flag so the NEXT account that signs in doesn't inherit them
    // (these keys are not namespaced per user).
    for (final key in prefs.getKeys().toList()) {
      if (key == 'cal_goal' ||
          key == 'user_daily_calories' ||
          key == 'onboarded' ||
          key.startsWith('protein_') ||
          key.startsWith('carbs_') ||
          key.startsWith('fat_') ||
          key.startsWith('cal_consumed_')) {
        await prefs.remove(key);
      }
    }
    setState(() { _profile = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: _profile != null
            ? [IconButton(icon: const Icon(Icons.logout, color: AppTheme.accentColor), onPressed: _logout)]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
          : _profile != null
              ? _buildProfileContent()
              : _buildLoginForm(),
      bottomNavigationBar: widget.showAiCoachNav ? _buildAiCoachNav(context) : null,
    );
  }

  Widget _buildAiCoachNav(BuildContext context) {
    return Container(
      height: 85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAiNavIcon(context, Icons.auto_awesome, 'AI ASSISTANT', false, () {
            if (widget.onAiAssistantTap != null) {
              widget.onAiAssistantTap!();
            } else {
              Navigator.pop(context);
            }
          }),
          _buildAiNavIcon(context, Icons.calendar_today_outlined, 'WEEKLY SCHEDULE', false, () {
            if (widget.onWeeklyScheduleTap != null) {
              widget.onWeeklyScheduleTap!();
            } else {
              Navigator.pop(context);
            }
          }),
          _buildAiNavIcon(context, Icons.person_outline, 'PROFILE', true, () {}),
        ],
      ),
    );
  }

  Widget _buildAiNavIcon(BuildContext context, IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? const Color(0xFFE8FF3A) : Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: active ? const Color(0xFFE8FF3A) : Colors.white38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppTheme.accentColor.withOpacity(0.3), AppTheme.accentColor.withOpacity(0.1)]),
              ),
              child: const Icon(Icons.person_outline, size: 40, color: AppTheme.accentColor),
            ),
            const SizedBox(height: 24),
            const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Access your fitness profile', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            const SizedBox(height: 32),

            TextField(
              controller: _emailCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('EMAIL', 'you@email.com', Icons.email_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDeco('PASSWORD', '••••••••', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.3)),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.2))),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
              ),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), elevation: 0),
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showPasswordResetDialog,
              child: const Text('Forgot password?', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  /// Sends a Firebase password-reset email. Available from the re-login form
  /// shown after a user signs out from this screen.
  Future<void> _showPasswordResetDialog() async {
    final resetCtrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter your email and we'll send you a link to reset your password.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('EMAIL', 'you@email.com', Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black),
            onPressed: () async {
              final email = resetCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _fbService.sendPasswordReset(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reset link sent to $email. Check your inbox.'), backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Send Link', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.accentColor.withOpacity(0.5))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3)),
    );
  }

  String _activityLabel(String? id) {
    const map = {
      'sedentary':   'Sedentary',
      'light':       'Lightly Active',
      'moderate':    'Moderately Active',
      'active':      'Active',
      'very_active': 'Very Active',
    };
    return map[id] ?? (id ?? '—');
  }

  void _showPersonalDataSheet() {
    if (_profile == null) return;
    final p = _profile!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Personal Data', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showEditPersonalDataSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: AppTheme.accentColor, size: 13),
                        SizedBox(width: 5),
                        Text('Edit', style: TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _dataCard('👤', 'Name', p['firstName']?.toString().isNotEmpty == true ? p['firstName'].toString() : '—')),
              const SizedBox(width: 12),
              Expanded(child: _dataCard('🚻', 'Gender', _genderLabel(p['gender']?.toString()))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dataCard('🎂', 'Age', p['age'] != null ? '${p['age']} yrs' : '—')),
              const SizedBox(width: 12),
              Expanded(child: _dataCard('📏', 'Height', p['height'] != null ? '${(p['height'] as num).toStringAsFixed(0)} cm' : '—')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dataCard('⚖️', 'Weight', p['weight'] != null ? '${(p['weight'] as num).toStringAsFixed(1)} kg' : '—')),
              const SizedBox(width: 12),
              Expanded(child: _dataCard('🏃', 'Activity', _activityLabel(p['activityLevel']?.toString()))),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditPersonalDataSheet();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), elevation: 0,
                ),
                child: const Text('Edit Personal Data', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String? g) {
    if (g == 'male') return 'Male';
    if (g == 'female') return 'Female';
    if (g == 'other') return 'Other';
    return g?.isNotEmpty == true ? g! : '—';
  }

  void _showEditPersonalDataSheet() {
    if (_profile == null) return;
    final p = _profile!;
    final nameCtrl = TextEditingController(text: p['firstName']?.toString() ?? '');
    final heightCtrl = TextEditingController(
        text: p['height'] != null ? (p['height'] as num).toStringAsFixed(0) : '');
    final weightCtrl = TextEditingController(
        text: p['weight'] != null ? (p['weight'] as num).toStringAsFixed(1) : '');
    String activityLevel = p['activityLevel']?.toString() ?? '';
    bool saving = false;
    String? errorMsg;

    const activities = [
      {'id': 'sedentary',   'emoji': '🪑', 'label': 'Sedentary',         'desc': 'Little to no exercise'},
      {'id': 'light',       'emoji': '🚶', 'label': 'Lightly Active',    'desc': '1–3 days/week'},
      {'id': 'moderate',    'emoji': '🏃', 'label': 'Moderately Active', 'desc': '3–5 days/week'},
      {'id': 'active',      'emoji': '💪', 'label': 'Active',            'desc': '6–7 days/week'},
      {'id': 'very_active', 'emoji': '🔥', 'label': 'Very Active',       'desc': 'Physical job or 2× training'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> save() async {
            setSheet(() { saving = true; errorMsg = null; });
            try {
              final heightCm = double.tryParse(heightCtrl.text.trim()) ?? 0;
              final weightKg = double.tryParse(weightCtrl.text.trim()) ?? 0;
              if (heightCm < 100 || heightCm > 250) throw Exception('Enter a valid height (100–250 cm)');
              if (weightKg < 20 || weightKg > 300) throw Exception('Enter a valid weight (20–300 kg)');
              if (activityLevel.isEmpty) throw Exception('Please select an activity level');
              await _savePersonalData(
                name: nameCtrl.text.trim(),
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel,
              );
              if (mounted) Navigator.pop(ctx);
            } catch (e) {
              setSheet(() { saving = false; errorMsg = e.toString().replaceAll('Exception: ', ''); });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Personal Data', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Changes update your calorie targets.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    const SizedBox(height: 24),

                    _sheetLabel('NAME'),
                    const SizedBox(height: 8),
                    _sheetTextField(nameCtrl, 'Your name', TextInputType.name),
                    const SizedBox(height: 16),

                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sheetLabel('HEIGHT (CM)'),
                        const SizedBox(height: 8),
                        _sheetTextField(heightCtrl, '170', TextInputType.number),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _sheetLabel('WEIGHT (KG)'),
                        const SizedBox(height: 8),
                        _sheetTextField(weightCtrl, '70.0', TextInputType.numberWithOptions(decimal: true)),
                      ])),
                    ]),
                    const SizedBox(height: 20),

                    _sheetLabel('ACTIVITY LEVEL'),
                    const SizedBox(height: 12),
                    ...activities.map((a) {
                      final id       = a['id']!;
                      final emoji    = a['emoji']!;
                      final label    = a['label']!;
                      final desc     = a['desc']!;
                      final selected = activityLevel == id;
                      return GestureDetector(
                        onTap: () => setSheet(() => activityLevel = id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.accentColor.withOpacity(0.1) : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selected ? AppTheme.accentColor.withOpacity(0.5) : Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(children: [
                            Text(emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(label, style: TextStyle(color: selected ? AppTheme.accentColor : Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                            ])),
                            if (selected) const Icon(Icons.check_circle, color: AppTheme.accentColor, size: 18),
                          ]),
                        ),
                      );
                    }),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.15)),
                        ),
                        child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          elevation: 0,
                          disabledBackgroundColor: AppTheme.accentColor.withOpacity(0.4),
                        ),
                        child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(text,
    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2));

  Widget _sheetTextField(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.accentColor.withOpacity(0.5))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _savePersonalData({
    required String name,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
  }) async {
    final p = _profile!;
    final gender = p['gender']?.toString() ?? 'male';
    final age = (p['age'] as num?)?.toInt() ?? 25;

    // Mifflin-St Jeor BMR → TDEE
    final double bmr = gender == 'female'
        ? 10 * weightKg + 6.25 * heightCm - 5 * age - 161
        : 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    const mult = {'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725, 'very_active': 1.9};
    final tdee = (bmr * (mult[activityLevel] ?? 1.55)).round().clamp(1200, 4000);
    final protein = (weightKg * 1.8).round();
    final fatCals = (tdee * 0.28).round();
    final fat    = (fatCals / 9).round();
    final carbs  = ((tdee - protein * 4 - fatCals) / 4).round().clamp(0, 500);

    // Write to profiles/{uid} (also syncs users/{uid})
    await _fbService.saveOnboardingProfile({
      'firstName':          name.isNotEmpty ? name : (p['firstName'] ?? ''),
      'gender':             gender,
      'birthYear':          (p['birthYear'] as num?)?.toInt() ?? 1990,
      'birthMonth':         (p['birthMonth'] as num?)?.toInt() ?? 1,
      'birthDay':           (p['birthDay']  as num?)?.toInt() ?? 1,
      'age':                age,
      'heightCm':           heightCm,
      'weightKg':           weightKg,
      'activityLevel':      activityLevel,
      'dailyCalorieTarget': tdee,
      'macroProtein':       protein,
      'macroCarbs':         carbs,
      'macroFat':           fat,
    });

    // Update SharedPreferences so home/nutrition screens pick up new targets
    final prefs = await SharedPreferences.getInstance();
    if (name.isNotEmpty) await prefs.setString('user_name', name);
    await prefs.setDouble('user_height_cm', heightCm);
    await prefs.setDouble('user_weight_kg', weightKg);
    await prefs.setString('user_activity', activityLevel);
    await prefs.setInt('user_daily_calories', tdee);
    await prefs.setInt('cal_goal',     tdee);
    await prefs.setInt('protein_goal', protein);
    await prefs.setInt('carbs_goal',   carbs);
    await prefs.setInt('fat_goal',     fat);

    // Refresh profile card
    await _fetchProfile(background: false);
  }

  Widget _fitnessDataCards(Map<String, dynamic> p) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _dataCard('⚖️', 'Weight', p['weight'] != null ? '${p['weight']} kg' : '—')),
          const SizedBox(width: 12),
          Expanded(child: _dataCard('📏', 'Height', p['height'] != null ? '${p['height']} cm' : '—')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dataCard('🎂', 'Age', p['age'] != null ? '${p['age']} yrs' : '—')),
          const SizedBox(width: 12),
          Expanded(child: _dataCard('🚻', 'Gender', (p['gender'] ?? '—').toString().toUpperCase())),
        ]),
        const SizedBox(height: 12),
        _dataCard('🏃', 'Activity', _activityLabel(p['activityLevel']?.toString())),
        if (p['dietaryRestrictions'] != null && p['dietaryRestrictions'].toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          _dataCard('🥗', 'Dietary', p['dietaryRestrictions'].toString()),
        ],
      ],
    );
  }

  Widget _buildProfileContent() {
    final p = _profile!;
    final firstName = p['firstName'] ?? '';
    final lastName = p['lastName'] ?? '';
    final displayName = '$firstName $lastName'.trim();
    final email = p['email'] ?? _fbService.email ?? '';
    final profileImg = p['profileImageUrl'] ?? p['profileImageURL'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar & Name
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF1A1A1A),
                backgroundImage: profileImg != null ? NetworkImage(profileImg) : null,
                child: profileImg == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.accentColor)) : null,
              ),
              const SizedBox(height: 16),
              Text(displayName.isNotEmpty ? displayName : 'User', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐ ', style: TextStyle(fontSize: 14)),
                    Text('${p['credits'] ?? 0} Credits', style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // FITNESS DATA: inline cards for AI Coach, menu tile for main nav
        if (widget.showAiCoachNav) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('FITNESS DATA'),
              GestureDetector(
                onTap: _showEditPersonalDataSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.accentColor, size: 12),
                      SizedBox(width: 4),
                      Text('Edit', style: TextStyle(color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fitnessDataCards(p),
          const SizedBox(height: 32),
        ],

        _sectionHeader('CHALLENGES'),
        const SizedBox(height: 12),
        _settingsTile(Icons.emoji_events_outlined, 'Find Challenges', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengeDiscoveryScreen()))),
        _settingsTile(Icons.workspace_premium_outlined, 'My Challenges', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParticipantMyChallengesScreen()))),
        if (p['isAdmin'] == true || p['role'] == 'admin' || p['role'] == 'superAdmin')
          _settingsTile(Icons.admin_panel_settings_outlined, 'Manage Challenges', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChallengeListScreen()))),
        const SizedBox(height: 32),

        _sectionHeader('SETTINGS'),
        const SizedBox(height: 12),
        if (!widget.showAiCoachNav)
          _settingsTile(Icons.person_outline, 'Personal Data', _showPersonalDataSheet),
        _settingsTile(Icons.shopping_bag_outlined, 'My Orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
        _settingsTile(Icons.favorite_border, 'Wishlist', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
        _settingsTile(Icons.location_on_outlined, 'Addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressScreen()))),
        _settingsTile(Icons.settings_outlined, 'Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        _settingsTile(Icons.info_outline, 'About', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
        _settingsTile(Icons.logout, 'Sign Out', _logout, isDestructive: true),
      ],
    );
  }

  Widget _sectionHeader(String label) => Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));

  Widget _dataCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF212121))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(emoji, style: const TextStyle(fontSize: 16)), const SizedBox(width: 8), Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF212121))),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white.withOpacity(0.5), size: 22),
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}