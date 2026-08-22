import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';

/// Collapsible "How this challenge works" card — mirrors the style of
/// [LeaderboardScoringHelpCard]. Shown on the participant dashboard.
class ChallengeStepsHelpCard extends StatelessWidget {
  const ChallengeStepsHelpCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EFCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Strip the default ExpansionTile divider lines for a cleaner card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppTheme.lime,
          collapsedIconColor: AppTheme.lime,
          leading: const Icon(Icons.flag_outlined, color: AppTheme.lime),
          title: const Text('How This Challenge Works', style: AppTheme.headingSM),
          subtitle: Text('Tap to see the steps.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
          children: [
            _step(1, 'Submit Payment Proof',
                'Pay to secure your spot. We\'ll verify your payment.',
                Icons.payments_outlined),
            _step(2, 'Submit Your Baseline',
                'Add your starting photos, weight, body fat, and muscle details.',
                Icons.straighten_rounded),
            _step(3, 'Weekly Check-Ins',
                'Update your progress every week to earn points.',
                Icons.event_available_rounded),
            _step(4, 'Final Submission',
                'Submit your final measurements to complete the challenge and qualify for prizes.',
                Icons.emoji_events_outlined),
          ],
        ),
      ),
    );
  }

  Widget _step(int n, String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.lime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$n',
                  style: const TextStyle(
                      color: AppTheme.lime, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.w700)),
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
}
