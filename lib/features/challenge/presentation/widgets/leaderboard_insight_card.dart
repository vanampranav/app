import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

class LeaderboardInsightCard extends StatelessWidget {
  final ParticipantLeaderboardInsights insights;

  const LeaderboardInsightCard({Key? key, required this.insights}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isFirst = insights.currentRank == 1;
    final bool isLast = insights.currentRank == insights.totalApprovedParticipants;
    final bool isOnly = insights.totalApprovedParticipants == 1;
    final official = insights.officialData;

    return EFCard(
      color: AppTheme.purple.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOTIVATIONAL RANK', style: AppTheme.labelSM.copyWith(color: AppTheme.purpleLight)),
                  const SizedBox(height: 4),
                  Text(
                    'Rank #${insights.currentRank}',
                    style: AppTheme.headingMD.copyWith(color: AppTheme.lime),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface3,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Of ${insights.totalApprovedParticipants} Active',
                  style: AppTheme.labelSM.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          
          if (isOnly)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusMessage(
                  'You are the only participant with approved data so far.',
                  Icons.stars_rounded,
                ),
                _buildComparisonMessage(
                  'Final prize ranking will be calculated from approved official measurements.',
                  Icons.info_outline_rounded,
                ),
              ],
            )
          else if (isFirst)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusMessage('You are currently leading the motivational leaderboard!', Icons.workspace_premium_rounded),
                if (insights.rankBelowLead != null)
                  _buildComparisonMessage(
                    'You are ${insights.rankBelowLead!.toStringAsFixed(1)} points ahead of rank #2.',
                    Icons.trending_up_rounded,
                  ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (insights.rankAboveGap != null)
                  _buildComparisonMessage(
                    'You need ${insights.rankAboveGap!.toStringAsFixed(1)} points to reach rank #${insights.currentRank - 1}.',
                    Icons.keyboard_double_arrow_up_rounded,
                  ),
                if (!isLast && insights.rankBelowLead != null)
                  _buildComparisonMessage(
                    'You are ${insights.rankBelowLead!.toStringAsFixed(1)} points ahead of rank #${insights.currentRank + 1}.',
                    Icons.trending_up_rounded,
                  )
                else if (isLast)
                   _buildStatusMessage('Keep pushing to move up from the last spot!', Icons.speed_rounded),
              ],
            ),
          
          const Divider(height: 24, color: Colors.white10),
          _buildOfficialMetricSummary(official),

          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('TOTAL LOSS', '${insights.weightLossKg.toStringAsFixed(1)} kg'),
              const SizedBox(width: 24),
              _buildMiniStat('PROGRESS', '${insights.weightLossPercent.toStringAsFixed(1)}%'),
              const Spacer(),
              _buildMiniStat('MOTIVATION', insights.currentMotivationalScore.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialMetricSummary(OfficialWinnerData data) {
    if (!data.isEligible) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.error),
            const SizedBox(width: 8),
            Text('Not currently eligible for prizes', style: AppTheme.bodySM.copyWith(color: AppTheme.error)),
          ],
        ),
      );
    }

    String label = 'Official Progress: ';
    String value = data.score?.toStringAsFixed(2) ?? '0.00';
    String unit = data.metric == 'bodyFatLossPoints' ? ' pts lost' : '% lost';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.lime),
          const SizedBox(width: 8),
          Text(label, style: AppTheme.bodySM),
          Text(value + unit, style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.lime),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonMessage(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.numericMD.copyWith(fontSize: 14)),
      ],
    );
  }
}
