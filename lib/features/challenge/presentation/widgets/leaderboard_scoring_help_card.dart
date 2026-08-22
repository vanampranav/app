import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';

/// A collapsible explainer on the leaderboard: how the score is built and how a
/// participant can climb. Purely informational — safe to show to everyone.
class LeaderboardScoringHelpCard extends StatelessWidget {
  const LeaderboardScoringHelpCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EFCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Strip the default ExpansionTile divider lines for a cleaner card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppTheme.lime,
          collapsedIconColor: AppTheme.lime,
          leading: const Icon(Icons.emoji_events_outlined, color: AppTheme.lime),
          title: const Text('How to score & climb the leaderboard',
              style: AppTheme.headingSM),
          subtitle: Text('Tap to see how points work',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
          children: [
            _sectionLabel('YOU EARN POINTS AT EVERY CHECK-IN'),
            const SizedBox(height: 6),
            Text(
              'Each approved check-in adds points for how much you improved. Points stack up over the challenge and never go down — a poor week simply earns 0, it never takes points away.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _sectionLabel('IMPROVEMENT IS WEIGHTED'),
            const SizedBox(height: 10),
            _weightRow('Body fat lost', '50%', Icons.local_fire_department_rounded,
                'The biggest driver — losing body fat earns the most points.'),
            _weightRow('Weight lost', '30%', Icons.monitor_weight_outlined,
                '% of body weight you drop.'),
            _weightRow('Muscle gained', '20%', Icons.fitness_center_rounded,
                'Building or keeping muscle while you lean out.'),
            const Divider(height: 28, color: Colors.white10),
            _sectionLabel('HOW TO EARN MORE'),
            const SizedBox(height: 10),
            _tip('Check in EVERY week — each approved check-in is a chance to earn points.'),
            _tip('Beat your previous best to earn NEW points. (Just returning to an old best earns nothing — no farming.)'),
            _tip('Focus on body fat first — it\'s worth the most (50%).'),
            _tip('Gain or protect muscle while losing fat for the 20% share.'),
            _tip('Send clear photos and accurate measurements so they get approved fast — only approved check-ins count.'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lime.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.lime.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.workspace_premium_outlined,
                      color: AppTheme.lime, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To win a prize you also need a verified payment and an approved FINAL submission at the end.',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary, letterSpacing: 1.2));

  Widget _weightRow(String label, String weight, IconData icon, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.surface2, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppTheme.lime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(weight,
                          style: const TextStyle(
                              color: AppTheme.lime, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.lime),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.bodySM)),
        ],
      ),
    );
  }
}
