import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL POINTS', style: AppTheme.labelMD.copyWith(letterSpacing: 2, color: AppTheme.lime)),
                  Text(
                    breakdown.totalLeaderboardScore.toStringAsFixed(1),
                    style: AppTheme.numericLG.copyWith(color: AppTheme.lime, fontSize: 30),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Earned across your approved check-ins. Points only go up — a poor week never costs you points.',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
              const Divider(height: 32, color: Colors.white10),
              Text('YOUR BEST TRANSFORMATION SO FAR', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _buildScoreItem('Body fat (50%)', breakdown.fatLossScore, Icons.monitor_weight_outlined, suffix: '%'),
              const SizedBox(height: 12),
              _buildScoreItem('Weight (30%)', breakdown.weightLossScore, Icons.fitness_center_rounded, suffix: '%'),
              const SizedBox(height: 12),
              _buildScoreItem('Muscle (20%)', breakdown.muscleGainScore, Icons.sports_gymnastics_rounded, suffix: '%'),
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
                  Text('PRIZE ELIGIBILITY', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
                  _buildEligibilityBadge(official.isEligible),
                ],
              ),
              const SizedBox(height: 20),
              if (official.isEligible) ...[
                Text(
                  insights.isProjectedOfficialRanking
                      ? "You're on track for prizes. Winners are decided from approved official measurements, so keep your submissions up to date."
                      : 'Your final measurements are approved — you are ranked for prizes.',
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

  Widget _buildScoreItem(String label, double score, IconData icon, {String suffix = ''}) {
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
          '${score.toStringAsFixed(1)}$suffix',
          style: AppTheme.numericMD.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}
