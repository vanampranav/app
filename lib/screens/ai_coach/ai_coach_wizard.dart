import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_coach_models.dart';
import '../../services/ai_coach_service.dart';
import '../../services/firebase_rest_service.dart';
import 'schedule_plan_screen.dart';

class AiCoachWizard extends StatefulWidget {
  const AiCoachWizard({Key? key}) : super(key: key);

  @override
  State<AiCoachWizard> createState() => _AiCoachWizardState();
}

class _AiCoachWizardState extends State<AiCoachWizard> {
  final AiCoachService _service = AiCoachService();
  final FirebaseRestService _fbService = FirebaseRestService();
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMsg;
  
  // Step 1
  final _goalCtrl = TextEditingController();
  final _goalFocusNode = FocusNode();
  
  // Step 2
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController(text: '3');
  String _gender = 'male';
  String _timelineUnit = 'weeks';
  
  // Step 3
  String _helpType = 'both';
  String _activityLevel = 'moderate';
  double _workoutDays = 4;
  final _dietaryCtrl     = TextEditingController(); // restriction chips overflow
  final _foodPrefsCtrl   = TextEditingController(); // usual foods & cuisine
  final Set<String> _selectedDietaryChips = {};
  
  // Step 4 Targets
  AiCoachTarget? _targets;

  // Firebase profile data (for save-back comparison)
  Map<String, dynamic>? _firebaseProfile;

  @override
  void initState() {
    super.initState();
    _fbService.init();
    _goalFocusNode.addListener(() => setState(() {}));
    _goalCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _goalFocusNode.dispose();
    _goalCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _timelineCtrl.dispose();
    _dietaryCtrl.dispose();
    _foodPrefsCtrl.dispose();
    super.dispose();
  }

  /// Fetch profile from Firebase and pre-fill wizard fields
  Future<void> _loadFirebaseProfile() async {
    if (!_fbService.isLoggedIn) {
      _showSnack('Please sign in first (Profile tab)');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = await _fbService.getUserProfile();
      if (profile == null) {
        _showSnack('No profile data found');
        return;
      }

      _firebaseProfile = profile;

      // Show dialog: "Use Existing Profile?"
      if (!mounted) return;
      final useProfile = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Use Existing Profile?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          content: Text(
            'We found your profile data. Would you like to auto-fill your details?',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Use My Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Fill Manually', style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      );

      if (useProfile == true) {
        setState(() {
          final fn = profile['firstName'] ?? '';
          final ln = profile['lastName'] ?? '';
          _nameCtrl.text = '$fn $ln'.trim();
          if (profile['age'] != null) _ageCtrl.text = profile['age'].toString();
          if (profile['height'] != null) _heightCtrl.text = profile['height'].toString();
          if (profile['weight'] != null) _weightCtrl.text = profile['weight'].toString();
          if (profile['targetWeight'] != null) _targetWeightCtrl.text = profile['targetWeight'].toString();
          if (profile['gender'] != null) _gender = profile['gender'].toString().toLowerCase();
          if (profile['activityLevel'] != null) _activityLevel = profile['activityLevel'].toString().toLowerCase();
          if (profile['dietaryRestrictions'] != null && profile['dietaryRestrictions'].toString().isNotEmpty) {
            final raw = profile['dietaryRestrictions'].toString().toLowerCase();
            if (raw.contains('vegetarian')) _selectedDietaryChips.add('vegetarian');
            if (raw.contains('vegan')) _selectedDietaryChips.add('vegan');
            if (raw.contains('no dairy') || raw.contains('dairy')) _selectedDietaryChips.add('no dairy');
            if (raw.contains('no eggs') || raw.contains('eggs')) _selectedDietaryChips.add('no eggs');
            _dietaryCtrl.text = profile['dietaryRestrictions'].toString();
          }
          if (profile['timelineWeeks'] != null) {
            final weeks = int.tryParse(profile['timelineWeeks'].toString()) ?? 0;
            if (weeks > 0) {
              if (weeks % 4 == 0) {
                _timelineCtrl.text = (weeks ~/ 4).toString();
                _timelineUnit = 'months';
              } else {
                _timelineCtrl.text = weeks.toString();
                _timelineUnit = 'weeks';
              }
            }
          }
          if (profile['foodPreferences'] != null && profile['foodPreferences'].toString().isNotEmpty) {
            _foodPrefsCtrl.text = profile['foodPreferences'].toString();
          }
        });
      }
    } catch (e) {
      _showSnack('Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFF333333),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool _validateStep2() {
    final age = int.tryParse(_ageCtrl.text);
    final height = double.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final timeline = int.tryParse(_timelineCtrl.text);

    if (age == null || age < 10 || age > 120) {
      _showSnack('Please enter a valid age (10–120)');
      return false;
    }
    if (height == null || height < 50 || height > 300) {
      _showSnack('Please enter a valid height in cm (50–300)');
      return false;
    }
    if (weight == null || weight < 20 || weight > 500) {
      _showSnack('Please enter a valid current weight in kg (20–500)');
      return false;
    }
    if (timeline == null || timeline <= 0 || timeline > 200) {
      _showSnack('Please enter a valid timeline (1–200)');
      return false;
    }
    return true;
  }

  Future<void> _nextStep() async {
    if (_currentStep == 2 && !_validateStep2()) return;

    if (_currentStep == 3) {
      setState(() { _isLoading = true; _errorMsg = null; });
      final profile = _buildProfile();
      final prefs = _buildPreferences();
      try {
        _targets = await _service.getUserTargets(profile, prefs);
        setState(() => _isLoading = false);

        // Ask to save profile right after calculating targets
        if (_fbService.isLoggedIn && _checkProfileDiffers()) {
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Save to profile?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              content: Text("You've entered new details. Would you like to update your profile with this information?",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Skip', style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w700))),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
          if (shouldSave == true) {
            try {
              await _fbService.updateUserProfile({
                'age': int.tryParse(_ageCtrl.text),
                'weight': int.tryParse(_weightCtrl.text),
                'height': int.tryParse(_heightCtrl.text),
                'targetWeight': int.tryParse(_targetWeightCtrl.text),
                'gender': _gender,
                'activityLevel': _activityLevel,
                'timelineWeeks': _buildProfile().timelineWeeks,
                'dietaryRestrictions': _buildPreferences().dietaryPreferences.join(', '),
                if (_foodPrefsCtrl.text.trim().isNotEmpty)
                  'foodPreferences': _foodPrefsCtrl.text.trim(),
              });
            } catch (_) {}
          }
        }

        if (mounted) setState(() => _currentStep = 4);
      } catch (e) {
        setState(() { _isLoading = false; _errorMsg = e.toString(); });
      }
    } else if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }
  
  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  AiCoachProfile _buildProfile() {
    return AiCoachProfile(
      name: _goalCtrl.text.isNotEmpty ? _goalCtrl.text : 'Get Fit',
      age: int.tryParse(_ageCtrl.text) ?? 25,
      gender: _gender,
      height: double.tryParse(_heightCtrl.text) ?? 170.0,
      currentWeight: double.tryParse(_weightCtrl.text) ?? 70.0,
      targetWeight: double.tryParse(_targetWeightCtrl.text) ?? 65.0,
      timelineWeeks: _timelineUnit == 'weeks' ? (int.tryParse(_timelineCtrl.text) ?? 3) : ((int.tryParse(_timelineCtrl.text) ?? 1) * 4),
    );
  }

  AiCoachPreferences _buildPreferences() {
    final parts = <String>[..._selectedDietaryChips];
    final free = _dietaryCtrl.text.trim();
    if (free.isNotEmpty) parts.add(free);
    return AiCoachPreferences(
      helpType: _helpType,
      activityLevel: _activityLevel,
      workoutDays: _workoutDays.toInt(),
      dietaryPreferences: parts.isEmpty ? ['no restrictions'] : parts,
      foodPreferences: _foodPrefsCtrl.text.trim(),
    );
  }

  /// Generate plan via backend APIs, then optionally save profile
  Future<void> _submitAndGenerate() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    
    try {
      final profile = _buildProfile();
      final prefs = _buildPreferences();

      final finalPlan = await _service.generateFullPlan(
        target: _targets!,
        profile: profile,
        preferences: prefs,
        goal: _goalCtrl.text.isNotEmpty ? _goalCtrl.text : 'Get Fit',
      );

      if (!mounted) return;
      // Keep _isLoading = true while we deduct credits and save — this prevents
      // the frozen blank-screen glitch between generation and navigation.

      String savedPlanId = '';
      if (_fbService.isLoggedIn) {
        // Deduct 1 credit before saving the plan
        try {
          await _fbService.decrementCredits();
        } catch (e) {
          if (mounted) setState(() { _isLoading = false; _errorMsg = e.toString(); });
          return;
        }

        // Save the generated fitness plan to the subcollection for multi-plan support
        try {
          savedPlanId = await _fbService.saveUserPlan(finalPlan);
        } catch (e) {
          debugPrint('Failed to save fitness plan: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context); // close bottom sheet
        if (savedPlanId.isNotEmpty) {
          _showPostGenerationSheet(savedPlanId, finalPlan);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiCoachSchedulePlanScreen(plan: finalPlan),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _errorMsg = e.toString(); });
      }
    }
  }

  void _showPostGenerationSheet(String planId, FitnessPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Plan Created!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _fbService.setActivePlan(planId);
                  } catch (e) {
                    debugPrint('Failed to set active plan: $e');
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => AiCoachSchedulePlanScreen(plan: plan),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Use This Plan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => AiCoachSchedulePlanScreen(plan: plan),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'View Plan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _checkProfileDiffers() {
    if (_firebaseProfile == null) return true;
    final p = _firebaseProfile!;
    final currentTimelineWeeks = _buildProfile().timelineWeeks;
    final savedTimelineWeeks = int.tryParse(p['timelineWeeks']?.toString() ?? '') ?? 0;
    return (p['age']?.toString() ?? '') != _ageCtrl.text ||
           (p['weight']?.toString() ?? '') != _weightCtrl.text ||
           (p['height']?.toString() ?? '') != _heightCtrl.text ||
           (p['targetWeight']?.toString() ?? '') != _targetWeightCtrl.text ||
           (p['gender']?.toString() ?? '') != _gender ||
           (p['activityLevel']?.toString() ?? '') != _activityLevel ||
           savedTimelineWeeks != currentTimelineWeeks ||
           (p['foodPreferences']?.toString() ?? '') != _foodPrefsCtrl.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      // Tap anywhere outside a field to dismiss the keyboard.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: Color(0xFFEBEB5D), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                  ),
                ),
                Text('STEP $_currentStep OF 4', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _currentStep / 4,
                child: Container(decoration: BoxDecoration(color: const Color(0xFFEBEB5D), borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              // Swipe down over the content to dismiss the keyboard, and add
              // keyboard-height bottom padding so the submit button can be
              // scrolled above the keyboard (this sheet has a fixed height).
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Text("What's your fitness goal?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(width: 8), Text('🔥', style: TextStyle(fontSize: 20))]),
        const SizedBox(height: 32),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _goalFocusNode.hasFocus
                  ? const Color(0xFFEBEB5D).withOpacity(0.7)
                  : Colors.white.withOpacity(0.05),
              width: _goalFocusNode.hasFocus ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _goalCtrl,
                  focusNode: _goalFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Lose 6 kg in 3 months',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
              if (_goalCtrl.text.isEmpty)
                const Padding(padding: EdgeInsets.only(right: 16), child: Text('🏋️', style: TextStyle(fontSize: 18))),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _buildActionButton('Create my plan', _nextStep),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Text("Nice goal!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(width: 8), Text('🔥', style: TextStyle(fontSize: 20))]),
        const SizedBox(height: 8),
        Text('To build the best plan for you, we need a few quick details.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        
        // "Use existing profile" — fetches from Firebase REST
        GestureDetector(
          onTap: _isLoading ? null : _loadFirebaseProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFF00A2FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00A2FF).withOpacity(0.3))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A2FF)))
                    : const Icon(Icons.person_search, color: Color(0xFF00A2FF), size: 16),
                const SizedBox(width: 8),
                Text('Use my existing profile details', style: TextStyle(color: const Color(0xFF00A2FF), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        _buildFieldLabel('NAME'),
        _buildInput(_nameCtrl),
        
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('AGE'), _buildInput(_ageCtrl)])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('HEIGHT (CM)'), _buildInput(_heightCtrl)])),
        ]),

        _buildFieldLabel('GENDER'),
        Row(children: [
          Expanded(child: _genderButton('male', 'Male ♂️')),
          const SizedBox(width: 16),
          Expanded(child: _genderButton('female', 'Female ♀️')),
        ]),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('CURRENT WEIGHT (KG)'), _buildInput(_weightCtrl)])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('TARGET WEIGHT (KG)'), _buildInput(_targetWeightCtrl)])),
        ]),

        _buildFieldLabel('TARGET TIMELINE'),
        Row(children: [
          Expanded(flex: 1, child: _buildInput(_timelineCtrl)),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: () => setState(() => _timelineUnit = 'weeks'), child: Container(decoration: BoxDecoration(color: _timelineUnit == 'weeks' ? const Color(0xFF00A2FF) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Weeks', style: TextStyle(color: _timelineUnit == 'weeks' ? Colors.white : Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w900)))))),
                Expanded(child: GestureDetector(onTap: () => setState(() => _timelineUnit = 'months'), child: Container(decoration: BoxDecoration(color: _timelineUnit == 'months' ? const Color(0xFF00A2FF) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Months', style: TextStyle(color: _timelineUnit == 'months' ? Colors.white : Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w900)))))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('This helps us calculate accurate calorie & workout targets.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
        const SizedBox(height: 32),

        _buildActionButton('Continue', _nextStep),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("What would you like help with?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        Row(children: [
          _buildTypeBox('meal', '🍽️', 'Meal'),
          const SizedBox(width: 12),
          _buildTypeBox('workout', '🏋️‍♂️', 'Workout'),
          const SizedBox(width: 12),
          _buildTypeBox('both', '🔥', 'Both'),
        ]),
        const SizedBox(height: 32),
        
        _buildFieldLabel('ACTIVITY LEVEL'),
        Row(children: [
          Expanded(child: _buildActivityButton('sedentary', '🪑', 'Sedentary', 'Little to no exercise')),
          const SizedBox(width: 12),
          Expanded(child: _buildActivityButton('light', '🚶', 'Light', 'Exercise 1-2 days/wk')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildActivityButton('moderate', '🏃‍♂️', 'Moderate', 'Exercise 3-5 days/wk')),
          const SizedBox(width: 12),
          Expanded(child: _buildActivityButton('active', '💪', 'Active', 'Exercise 6-7 days/wk')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildActivityButton('very_active', '🔥', 'Very Active', 'Intense daily exercise')),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 32),

        const Text('Workout days per week', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text('${_workoutDays.toInt()} days - Balanced & sustainable', style: const TextStyle(color: Color(0xFFEBEB5D), fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: const Color(0xFF00A2FF), inactiveTrackColor: Colors.white.withOpacity(0.1), thumbColor: Colors.white, trackHeight: 4),
          child: Slider(value: _workoutDays, min: 1, max: 7, divisions: 6, onChanged: (v) => setState(() => _workoutDays = v)),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('1 Day', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900)),
          Text('7 Day', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 32),

        _buildFieldLabel('DIETARY RESTRICTIONS'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDietaryChip('vegetarian', 'VEGETARIAN'),
            _buildDietaryChip('vegan', 'VEGAN'),
            _buildDietaryChip('no dairy', 'NO DAIRY'),
            _buildDietaryChip('no eggs', 'NO EGGS'),
          ],
        ),
        const SizedBox(height: 12),
        _buildInput(_dietaryCtrl, hint: 'Any other restrictions (optional)'),
        const SizedBox(height: 24),

        _buildFieldLabel('YOUR USUAL FOODS & CUISINE'),
        const SizedBox(height: 4),
        Text(
          'Tell us what you normally eat. We\'ll build your plan around it.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
        const SizedBox(height: 10),
        _buildInput(
          _foodPrefsCtrl,
          hint: 'e.g. I eat idli for breakfast, rice-dal for lunch. I drink tea twice daily. Love biryani on weekends.',
          maxLines: 3,
          maxLength: 600,
        ),
        const SizedBox(height: 32),

        if (_errorMsg != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),

        _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEBEB5D)))
          : _buildActionButton('Calculate Targets', _nextStep),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep4() {
    if (_targets == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Your personalized daily calorie target is", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Based on your profile and goals", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Text('${_targets!.dailyCalories}', style: const TextStyle(color: Color(0xFFEBEB5D), fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
            const SizedBox(height: 8),
            Text('KCAL / DAY', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          ]),
        ),
        const SizedBox(height: 24),
        
        Row(children: [
          Expanded(child: _buildMacroBox('${_targets!.macros['protein']}g', 'PROTEIN', const Color(0xFFFF6B6B))),
          const SizedBox(width: 16),
          Expanded(child: _buildMacroBox('${_targets!.macros['carbs']}g', 'CARBS', const Color(0xFF4ECDC4))),
          const SizedBox(width: 16),
          Expanded(child: _buildMacroBox('${_targets!.macros['fat']}g', 'FAT', const Color(0xFFFFD93D))),
        ]),
        const SizedBox(height: 32),

        if (_targets!.personalizedInsight != null && _targets!.personalizedInsight!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.accentColor.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(child: Text(_targets!.personalizedInsight!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, height: 1.4))),
            ]),
          ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'This site offers health, fitness and nutritional information and is designed for educational purposes only...',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w500, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 32),

        if (_errorMsg != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),

        _isLoading
          ? Center(child: Column(children: [
              const CircularProgressIndicator(color: Color(0xFFEBEB5D)),
              const SizedBox(height: 16),
              Text('Generating your personalized plan...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('AI is crafting your tailored fitness journey', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ]))
          : _buildActionButton('Generate my plan', _submitAndGenerate),
        const SizedBox(height: 16),
      ],
    );
  }

  // --- Reusable widgets ---

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
    );
  }

  Widget _buildInput(TextEditingController ctrl,
      {String? hint, int maxLines = 1, int? maxLength}) {
    final bool multiline = maxLines != 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: multiline ? null : 48,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: ctrl,
        // Multiline fields grow to fit everything typed (min `maxLines` rows,
        // then unbounded); single-line fields stay one row and submit on done.
        minLines: multiline ? maxLines : 1,
        maxLines: multiline ? null : 1,
        maxLength: maxLength,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textInputAction:
            multiline ? TextInputAction.newline : TextInputAction.done,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
          counterStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildDietaryChip(String id, String label) {
    final active = _selectedDietaryChips.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (active) _selectedDietaryChips.remove(id);
        else _selectedDietaryChips.add(id);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A4E2C) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.15)),
        ),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56, width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEBEB5D), borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: const Color(0xFFEBEB5D).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900))),
      ),
    );
  }

  Widget _genderButton(String id, String label) {
    final active = _gender == id;
    return GestureDetector(
      onTap: () => setState(() => _gender = id),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: active ? const Color(0xFF4A4E2C) : const Color(0xFF111111), border: Border.all(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.05)), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.4), fontWeight: FontWeight.w900, fontSize: 13))),
      ),
    );
  }

  Widget _buildTypeBox(String id, String emoji, String label) {
    final active = _helpType == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _helpType = id),
        child: Container(
          height: 100,
          decoration: BoxDecoration(color: active ? Colors.transparent : const Color(0xFF111111), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.05))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }

  Widget _buildActivityButton(String id, String emoji, String label, String desc) {
    final active = _activityLevel == id;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(color: active ? const Color(0xFF111111) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? const Color(0xFFEBEB5D) : Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w500)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildMacroBox(String val, String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ]),
    );
  }
}
