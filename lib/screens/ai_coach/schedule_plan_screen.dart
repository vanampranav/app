import 'package:flutter/material.dart';
import '../../models/ai_coach_models.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';
import '../profile_screen.dart';
import '../../services/analytics_service.dart';

const List<String> _MEAL_TIMES = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

const Map<String, String> _MEAL_ICONS = {
  'Breakfast': '☀️',
  'Lunch': '🍽️',
  'Snacks': '🍯',
  'Dinner': '🌙',
};

class AiCoachSchedulePlanScreen extends StatefulWidget {
  final FitnessPlan plan;

  const AiCoachSchedulePlanScreen({Key? key, required this.plan}) : super(key: key);

  @override
  State<AiCoachSchedulePlanScreen> createState() => _AiCoachSchedulePlanScreenState();
}

class _AiCoachSchedulePlanScreenState extends State<AiCoachSchedulePlanScreen> {
  int _selectedDayIndex = 0;
  String _activeTab = 'meals'; // 'meals', 'workout', 'suggestions'
  bool _isDownloading = false;

  Future<void> _downloadPDF() async {
    if (_isDownloading) return;
    if (!mounted) return;
    setState(() => _isDownloading = true);
    try {
      await PdfService.sharePlanPDF(widget.plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Generate the 7 calendar dates starting from generatedDate
  List<_ScheduleDate> get _scheduleDates {
    final start = widget.plan.generatedDate;
    const shortDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return List.generate(7, (i) {
      final date = start.add(Duration(days: i));
      return _ScheduleDate(
        dayName: shortDays[date.weekday % 7],
        dateNum: date.day.toString().padLeft(2, '0'),
      );
    });
  }

  void _prevDay() => setState(() => _selectedDayIndex = (_selectedDayIndex - 1).clamp(0, 6));
  void _nextDay() => setState(() => _selectedDayIndex = (_selectedDayIndex + 1).clamp(0, 6));

  @override
  Widget build(BuildContext context) {
    final dates = _scheduleDates;
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            // === TOP NAV ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentColor),
                      child: const Center(child: Icon(Icons.arrow_back, color: Colors.black, size: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Weekly Schedule', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                  // Download button
                  GestureDetector(
                    onTap: _downloadPDF,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Center(
                        child: _isDownloading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppTheme.accentColor, strokeWidth: 2))
                            : const Icon(Icons.download_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Favorite button
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: const Center(child: Icon(Icons.favorite_border, color: Colors.white, size: 20)),
                  ),
                ],
              ),
            ),

            // === DATE SELECTOR (7 days from gen date) ===
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _selectedDayIndex > 0 ? _prevDay : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_left, size: 28, color: _selectedDayIndex == 0 ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
                    ),
                  ),
                  ...List.generate(7, (idx) {
                    final d = dates[idx];
                    final isActive = idx == _selectedDayIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = idx),
                        child: Column(
                          children: [
                            // Yellow dot
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 6, width: 6,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? AppTheme.accentColor : Colors.transparent,
                                boxShadow: isActive ? [BoxShadow(color: AppTheme.accentColor.withOpacity(0.8), blurRadius: 8)] : [],
                              ),
                            ),
                            Text(d.dateNum, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF454545), fontSize: isActive ? 18 : 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(d.dayName, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                            const SizedBox(height: 6),
                            // Yellow underline
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 2, width: isActive ? 20 : 0,
                              decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(1)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _selectedDayIndex < 6 ? _nextDay : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, size: 28, color: _selectedDayIndex == 6 ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
                    ),
                  ),
                ],
              ),
            ),

            // === PLAN BOX ===
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111111),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  border: Border(top: BorderSide(color: Color(0xFF212121))),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Plan Header
                        Container(
                          color: const Color(0xFF1A1C14),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('PLAN GOAL: ', style: TextStyle(color: const Color(0xFF898989), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                  Expanded(child: Text(widget.plan.goal, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildHeaderChip('📅', 'DURATION: ', '7 DAYS'),
                                  const SizedBox(width: 12),
                                  _buildHeaderChip('🔥', '', '${widget.plan.dailyCalories} KCAL'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Tabs
                        Container(
                          color: const Color(0xFF0C0C0C).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTab('meals', '🍴', 'MEAL PLANS'),
                              _buildTab('workout', '🏋️', 'WORKOUT'),
                              _buildTab('suggestions', '💡', 'PLAN SUGGESTIONS'),
                            ],
                          ),
                        ),
                        Container(height: 1, color: const Color(0xFF212121)),

                        // Tab Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildTabContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // === BOTTOM NAV ===
            Container(
              height: 85,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavIcon(Icons.auto_awesome, 'AI ASSISTANT', false, () => Navigator.pop(context)),
                  _buildNavIcon(Icons.calendar_today_outlined, 'WEEKLY SCHEDULE', true, () {}),
                  _buildNavIcon(Icons.person_outline, 'PROFILE', false, () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProfileScreen(
                          showAiCoachNav: true,
                          onAiAssistantTap: () {
                            Navigator.pop(context); // pop Profile → Schedule
                            Navigator.pop(context); // pop Schedule → AI Coach
                          },
                          onWeeklyScheduleTap: () => Navigator.pop(context),
                        )));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab Content ---

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'meals': return _buildMealsTab();
      case 'workout': return _buildWorkoutTab();
      case 'suggestions': return _buildSuggestionsTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildMealsTab() {
    final dayMeals = widget.plan.weeklyMeals[_selectedDayIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Intake header
        Row(
          children: [
            const Text('DAILY INTAKE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.accentColor.withOpacity(0.2))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 14)),
                  Text('${widget.plan.dailyCalories} kcal', style: const TextStyle(color: AppTheme.accentColor, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Meal Time accordions
        ..._MEAL_TIMES.map((mealTime) {
          final items = dayMeals.mealsByTime[mealTime] ?? [];
          return _buildMealAccordion(mealTime, items, expanded: mealTime == 'Breakfast');
        }),
      ],
    );
  }

  Widget _buildWorkoutTab() {
    final workout = widget.plan.weeklyWorkouts[_selectedDayIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Focus header
        Row(
          children: [
            const Text('FOCUS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
            const SizedBox(width: 12),
            Container(width: 20, height: 1, color: Colors.white.withOpacity(0.2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                workout.isRestDay ? 'REST & RECOVERY' : widget.plan.workoutFocus,
                style: const TextStyle(color: AppTheme.accentColor, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Workout accordion
        _buildWorkoutAccordion(workout),
      ],
    );
  }

  Widget _buildSuggestionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personalized Suggestions card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF212121)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.expand_more, color: const Color(0xFF898989), size: 18),
                    const SizedBox(width: 8),
                    const Text('Personalized Suggestions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFF212121)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Meal Plan Focus', style: TextStyle(color: AppTheme.accentColor, fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                            'Consistency is the key to achieving your "${widget.plan.goal}" goal. Focus on hitting your daily ${widget.plan.dailyCalories} kcal target and staying hydrated.',
                            style: TextStyle(color: const Color(0xFF898989), fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.thumb_down_outlined, color: const Color(0xFF898989), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.thumb_up_outlined, color: const Color(0xFF898989), size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Daily tips
        const Text('💡 Tips for today', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _buildTipCard('🥤', 'Stay Hydrated', 'Drink at least 8 glasses of water throughout the day.'),
        _buildTipCard('😴', 'Quality Sleep', 'Aim for 7-9 hours of sleep for optimal recovery.'),
        _buildTipCard('🧘', 'Mindfulness', 'Take 5 minutes for deep breathing or meditation.'),
        _buildTipCard('📊', 'Track Progress', 'Log your meals and workouts to stay accountable.'),
      ],
    );
  }

  // --- UI Builders ---

  Widget _buildHeaderChip(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF0C0C0C), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF212121))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          if (label.isNotEmpty) Text(label, style: TextStyle(color: const Color(0xFF898989), fontSize: 9, fontWeight: FontWeight.w900)),
          Text(value, style: const TextStyle(color: AppTheme.accentColor, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTab(String id, String icon, String label) {
    final isActive = _activeTab == id;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = id);
        AnalyticsService.logAiCoachUsed('view_$id');
        if (id == 'workout') {
          AnalyticsService.logWorkoutPlanViewed(widget.plan.workoutFocus);
        }
      },
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: TextStyle(fontSize: 14, color: isActive ? Colors.white : Colors.white.withOpacity(0.4))),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: isActive ? AppTheme.accentColor : const Color(0xFF898989),
                fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0,
              )),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3, width: isActive ? 60 : 0,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive ? [BoxShadow(color: AppTheme.accentColor.withOpacity(0.5), blurRadius: 8)] : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealAccordion(String mealTime, List<MealItem> items, {bool expanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF212121)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          iconColor: Colors.white,
          collapsedIconColor: const Color(0xFF898989),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.expand_more, color: const Color(0xFF898989), size: 16),
                  const SizedBox(width: 8),
                  Text(mealTime.toUpperCase(), style: TextStyle(color: const Color(0xFF898989), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              Text(_MEAL_ICONS[mealTime] ?? '', style: const TextStyle(fontSize: 16)),
            ],
          ),
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No meals planned for this time.', style: TextStyle(color: const Color(0xFF454545), fontSize: 10)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                child: Column(
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(item.quantity.toUpperCase(), style: const TextStyle(color: AppTheme.accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF212121).withOpacity(0.5))),
                          child: Row(
                            children: [
                              Text('🔥 ${item.calories} KCAL', style: TextStyle(color: const Color(0xFF898989), fontSize: 10, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFF454545), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('💪 ${item.macro}', style: TextStyle(color: const Color(0xFF898989), fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutAccordion(DayWorkout workout) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF212121)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: Colors.white,
          collapsedIconColor: const Color(0xFF898989),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.expand_more, color: const Color(0xFF898989), size: 16),
                  const SizedBox(width: 8),
                  Text(workout.name.toUpperCase(), style: TextStyle(color: const Color(0xFF898989), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              Row(
                children: [
                  if (workout.duration.isNotEmpty && !workout.duration.contains('0'))
                    Text(workout.duration.toUpperCase(), style: const TextStyle(color: AppTheme.accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  const Text('🏋️', style: TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
          children: [
            if (workout.isRestDay)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('😌', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text('Active Recovery Day', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Rest, stretch, and let your body recover. Light walking or yoga is encouraged.', textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF898989), fontSize: 12, height: 1.5)),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (workout.duration.isNotEmpty && !workout.duration.contains('0'))
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF212121).withOpacity(0.5))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⏱️ ', style: TextStyle(fontSize: 12)),
                            Text(workout.duration.toUpperCase(), style: TextStyle(color: const Color(0xFF898989), fontSize: 10, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ...workout.exercises.map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentColor,
                              boxShadow: [BoxShadow(color: AppTheme.accentColor.withOpacity(0.5), blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(ex, style: TextStyle(color: const Color(0xFF898989), fontSize: 12, fontWeight: FontWeight.w700))),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(String emoji, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF212121)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: const Color(0xFF898989), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, bool active, VoidCallback onTap) {
    if (active) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.5), size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDate {
  final String dayName;
  final String dateNum;
  _ScheduleDate({required this.dayName, required this.dateNum});
}
