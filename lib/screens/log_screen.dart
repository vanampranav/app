import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'nutrition/nutrition_log_screen.dart';
import 'workout/workout_log_screen.dart';

/// The "Log" tab: a Food ⇄ Workout segmented toggle hosting the existing
/// nutrition log and the new workout log. Both stay alive (IndexedStack) so
/// switching tabs preserves scroll/state.
class LogScreen extends StatefulWidget {
  final int initialTab; // 0 = Food, 1 = Workout
  const LogScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _toggle(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  NutritionLogScreen(),
                  WorkoutLogScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.sm),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            _segment('🍽  Food', 0),
            _segment('🏋  Workout', 1),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, int idx) {
    final selected = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(label,
              style: AppTheme.labelLG.copyWith(
                  color: selected ? Colors.black : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}
