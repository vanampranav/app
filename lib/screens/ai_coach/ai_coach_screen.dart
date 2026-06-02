import 'package:flutter/material.dart';
import '../../models/ai_coach_models.dart';
import '../../services/firebase_rest_service.dart';
import '../../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _fbService.init().then((_) { if (mounted) setState(() {}); });
  }

  Future<void> _openMyPlans() async {
    // Ensure tokens are loaded before checking login state
    await _fbService.init();
    if (!_fbService.isLoggedIn) {
      _showSnack('Please sign in first via the Profile tab.');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlansSheet(
        fbService: _fbService,
        onNewPlan: () {
          Navigator.pop(context);
          _openWizard();
        },
      ),
    );
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

  Future<void> _openSchedule() async {
    await _fbService.init();
    if (!_fbService.isLoggedIn) {
      _showSnack('Please sign in first via the Profile tab.');
      return;
    }
    _showSnack('Loading your plan…');
    try {
      final summaries = await _fbService.getUserPlans();
      if (summaries.isEmpty) {
        _showSnack('No plan yet — create one first!');
        return;
      }
      final plan = await _fbService.getPlanById(summaries.first.id);
      if (plan == null) {
        _showSnack('Could not load plan. Please try again.');
        return;
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => AiCoachSchedulePlanScreen(plan: plan)));
    } catch (_) {
      _showSnack('Failed to load plan. Please try again.');
    }
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
                    Image.asset('assets/images/elefit_logo.png', height: 24,
                        errorBuilder: (_, __, ___) => const Text('ELEFIT.',
                            style: TextStyle(color: AppTheme.accentColor, fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic))),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
                        ),
                        child: const Center(child: Icon(Icons.close, color: AppTheme.accentColor, size: 24)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
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
                  Text('Ready to continue your fitness journey?',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  _buildActionCard(
                    icon: '🏋️‍♂️',
                    title: 'My fitness plans',
                    subtitle: 'View all your personalized schedules',
                    onTap: _openMyPlans,
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    icon: '✨',
                    title: 'Start a new plan',
                    subtitle: 'Create a fresh fitness goal',
                    onTap: _openWizard,
                  ),
                ],
              ),
            ),

            // Bottom Nav
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: Container(
                height: 80,
                decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(40)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavIcon(Icons.auto_awesome, 'AI ASSISTANT', true, () {}),
                    _buildNavIcon(Icons.calendar_today_outlined, 'WEEKLY SCHEDULE', false, _openSchedule),
                    _buildNavIcon(Icons.person_outline, 'PROFILE', false, () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ProfileScreen(
                            showAiCoachNav: true,
                            onAiAssistantTap: () => Navigator.pop(context),
                            onWeeklyScheduleTap: () {
                              Navigator.pop(context);
                              _openSchedule();
                            },
                          )));
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
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
          decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.black, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ]),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

// ── Plans bottom sheet ────────────────────────────────────────────────────────

class _PlansSheet extends StatefulWidget {
  final FirebaseRestService fbService;
  final VoidCallback onNewPlan;

  const _PlansSheet({required this.fbService, required this.onNewPlan});

  @override
  State<_PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends State<_PlansSheet> {
  List<FitnessPlanSummary> _plans = [];
  bool _isLoading = true;
  String? _loadingPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await widget.fbService.getUserPlans();
      if (mounted) setState(() { _plans = plans; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load plans: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _openPlan(FitnessPlanSummary s) async {
    if (_loadingPlanId != null) return;
    setState(() => _loadingPlanId = s.id);
    try {
      final plan = await widget.fbService.getPlanById(s.id);
      if (!mounted) return;
      if (plan == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load plan.')));
        return;
      }
      Navigator.pop(context); // close sheet
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a1, __) => AiCoachSchedulePlanScreen(plan: plan),
          transitionsBuilder: (_, a1, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 340),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _loadingPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('My Fitness Plans',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onNewPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.black, size: 16),
                        SizedBox(width: 4),
                        Text('New', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          Flexible(
            child: _isLoading
                ? _buildSkeleton()
                : _plans.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        shrinkWrap: true,
                        itemCount: _plans.length,
                        itemBuilder: (_, i) => _buildPlanRow(_plans[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRow(FitnessPlanSummary s) {
    final isLoading = _loadingPlanId == s.id;
    return GestureDetector(
      onTap: () => _openPlan(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isLoading ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLoading ? AppTheme.accentColor.withOpacity(0.35) : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🏋️', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_fmtDate(s.generatedDate),
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.w600)),
                      if (s.dailyCalories > 0) ...[
                        Text('  ·  ', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
                        Text('🔥 ${s.dailyCalories} kcal',
                            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  if (s.goal.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(s.goal,
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor))
            else
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text('No plans yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Tap "New" above to generate your first AI fitness plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, i) => _SkeletonRow(),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
  }
}

// Shimmer skeleton row
class _SkeletonRow extends StatefulWidget {
  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.04, end: 0.12).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            _bone(42, 42, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bone(130, 13),
                const SizedBox(height: 7),
                _bone(90, 10),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bone(double w, double h, {double radius = 6}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(_anim.value),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
