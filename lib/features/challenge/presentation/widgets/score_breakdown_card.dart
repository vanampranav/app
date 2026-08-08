import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

class ScoreBreakdownCard extends StatelessWidget {
  final ParticipantLeaderboardInsights insights;

  const ScoreBreakdownCard({Key? key, required this.insights}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final breakdown = insights.scoreBreakdown;
    final official = insights.officialData;

    return Column(
      children: [
        EFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEADERBOARD SCORE', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
              const SizedBox(height: 20),
              _buildScoreItem('Weight Loss', breakdown.weightLossScore, Icons.fitness_center_rounded),
              const SizedBox(height: 12),
              _buildScoreItem('Body Fat Loss', breakdown.fatLossScore, Icons.monitor_weight_outlined),
              const SizedBox(height: 12),
              _buildScoreItem('Consistency', breakdown.consistencyScore, Icons.event_repeat_rounded),
              const Divider(height: 32, color: Colors.white10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'MOTIVATIONAL SCORE',
                      style: AppTheme.labelLG.copyWith(color: AppTheme.lime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    breakdown.totalLeaderboardScore.toStringAsFixed(1),
                    style: AppTheme.numericLG.copyWith(color: AppTheme.lime, fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This score is motivational and includes consistency to help you stay engaged.',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EFCard(
          color: official.isEligible ? AppTheme.surface2 : AppTheme.error.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('OFFICIAL PROGRESS', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
                  _buildEligibilityBadge(official.isEligible),
                ],
              ),
              const SizedBox(height: 20),
              if (official.isEligible) ...[
                _buildOfficialMetricRow(official),
                if (official.metric == 'compositeScore') ...[
                  const SizedBox(height: 16),
                  _buildComponentRow('Body Fat % Change (50%)', official.bodyFatChangePercent),
                  const SizedBox(height: 8),
                  _buildComponentRow('Weight Loss (30%)', official.weightLossPercent),
                  const SizedBox(height: 8),
                  _buildComponentRow('Muscle Gain (20%)', official.muscleGainPercent),
                ],
                const SizedBox(height: 12),
                Text(
                  insights.isProjectedOfficialRanking 
                      ? 'Final prize winners are determined using approved official measurements only. Current progress is projected.'
                      : 'Official ranking based on approved final measurements.',
                  style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        official.ineligibilityReason ?? 'Not eligible for prizes.',
                        style: AppTheme.bodySM.copyWith(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEligibilityBadge(bool eligible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (eligible ? AppTheme.lime : AppTheme.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (eligible ? AppTheme.lime : AppTheme.error).withValues(alpha: 0.3)),
      ),
      child: Text(
        eligible ? 'ELIGIBLE' : 'NOT ELIGIBLE',
        style: TextStyle(color: eligible ? AppTheme.lime : AppTheme.error, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildComponentRow(String label, double percent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text('${percent.toStringAsFixed(1)}%',
            style: AppTheme.numericMD.copyWith(fontSize: 14)),
      ],
    );
  }

  Widget _buildOfficialMetricRow(OfficialWinnerData data) {
    String label = 'Official Score';
    String unit = '';
    if (data.metric == 'compositeScore') {
      label = 'Participant Score';
      unit = '';
    } else if (data.metric == 'bodyFatLossPoints') {
      label = 'Body Fat Points Lost';
      unit = ' pts';
    } else if (data.metric == 'weightLossPercent') {
      label = 'Weight Loss';
      unit = '%';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${data.score?.toStringAsFixed(2) ?? "0.00"}$unit',
          style: AppTheme.numericLG.copyWith(color: AppTheme.textPrimary, fontSize: 20),
        ),
      ],
    );
  }

  Widget _buildScoreItem(String label, double score, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (score / 100).clamp(0, 1),
                  backgroundColor: AppTheme.surface3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    score > 0 ? AppTheme.lime : AppTheme.textTertiary,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          score.toStringAsFixed(1),
          style: AppTheme.numericMD.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}
