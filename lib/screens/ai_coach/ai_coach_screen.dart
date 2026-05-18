import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_coach_models.dart';
import '../../services/firebase_rest_service.dart';
import '../../widgets/main_layout.dart';
import 'schedule_plan_screen.dart';
import 'ai_coach_wizard.dart';
import '../profile_screen.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({Key? key}) : super(key: key);

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final FirebaseRestService _fbService = FirebaseRestService();
  bool _isLoadingPlan = false;

  @override
  void initState() {
    super.initState();
    _fbService.init();
  }

  Future<void> _loadSavedPlan() async {
    if (!_fbService.isLoggedIn) {
      _showSnack('Please sign in first via the Profile tab.');
      return;
    }

    setState(() => _isLoadingPlan = true);
    try {
      final profile = await _fbService.getUserProfile();
      if (profile != null && profile['fitnessPlan'] != null) {
        final planJson = jsonDecode(profile['fitnessPlan'] as String);
        final plan = FitnessPlan.fromJson(planJson);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AiCoachSchedulePlanScreen(plan: plan)));
        }
      } else {
        _showSnack('No saved plan found. Start a new plan to create one!');
      }
    } catch (e) {
      _showSnack('Failed to load plan: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
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

  void _openWizard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: const AiCoachWizard(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background Image (Fallback to generic runner placeholder matching theme)
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/elefit_logo.png', height: 24, errorBuilder: (context, error, stackTrace) => const Text('ELEFIT.', style: TextStyle(color: AppTheme.accentColor, fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic))),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
                      ),
                      child: const Center(
                        child: Icon(Icons.close, color: AppTheme.accentColor, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Box
          Positioned(
            left: 20, right: 20, top: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Welcome Back!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    SizedBox(width: 8),
                    Text('👋', style: TextStyle(fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Ready to continue your fitness journey?', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 32),

                _buildActionCard(
                  icon: '🏋️‍♂️',
                  title: 'My fitness plans',
                  subtitle: _isLoadingPlan ? 'Loading...' : 'View your personalized schedule',
                  onTap: _isLoadingPlan ? () {} : _loadSavedPlan,
                ),
                const SizedBox(height: 16),
                
                // Button 2: Start a new plan
                _buildActionCard(
                  icon: '✨',
                  title: 'Start a new plan',
                  subtitle: 'Create a fresh fitness goal',
                  onTap: _openWizard,
                ),
              ],
            ),
          ),

          // Mock Bottom Nav
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavIcon(Icons.auto_awesome, 'AI ASSISTANT', true, () {}),
                  _buildNavIcon(Icons.calendar_today_outlined, 'WEEKLY SCHEDULE', false, () {}),
                  _buildNavIcon(Icons.person_outline, 'PROFILE', false, () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout(currentIndex: 5, child: ProfileScreen())));
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildActionCard({required String icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF222222).withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, bool active, VoidCallback onTap) {
    if (active) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.5), size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
