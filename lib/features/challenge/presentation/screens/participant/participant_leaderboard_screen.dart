import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_leaderboard_provider.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/leaderboard_insight_card.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/participant_progress_chart.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/score_breakdown_card.dart';

class ParticipantLeaderboardScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantLeaderboardScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.id ?? '';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => ParticipantLeaderboardProvider(
            challengeId: challengeId,
            challengeRepository: ctx.read<ChallengeRepository>(),
            participantRepository: ctx.read<ChallengeParticipantRepository>(),
            submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
            userRepository: ctx.read<UserRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LeaderboardInsightsProvider(
            challengeId: challengeId,
            userId: userId,
            challengeRepository: ctx.read<ChallengeRepository>(),
            participantRepository: ctx.read<ChallengeParticipantRepository>(),
            submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
            userRepository: ctx.read<UserRepository>(),
          ),
        ),
      ],
      child: const _ParticipantLeaderboardContent(),
    );
  }
}

class _ParticipantLeaderboardContent extends StatelessWidget {
  const _ParticipantLeaderboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Leaderboard', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer2<ParticipantLeaderboardProvider, LeaderboardInsightsProvider>(
        builder: (context, leaderboardProvider, insightsProvider, _) {
          if (leaderboardProvider.isLoading || insightsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
          }

          if (leaderboardProvider.errorMessage != null) {
            return _buildErrorState(leaderboardProvider.errorMessage!);
          }

          if (leaderboardProvider.leaderboard.isEmpty) {
            return _buildEmptyState();
          }

          final insights = insightsProvider.insights;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(leaderboardProvider.challenge?.title ?? ''),
              ),

              // Personal Insights
              if (insights != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LeaderboardInsightCard(insights: insights),
                        const SizedBox(height: 24),
                        ParticipantProgressChart(points: insights.progressPoints),
                        const SizedBox(height: 24),
                        ScoreBreakdownCard(insights: insights),
                        const SizedBox(height: 40),
                        _buildSectionTitle('LEADERBOARD RANKINGS'),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildMissingBaselineState(),
                  ),
                ),

              // Global Leaderboard List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final entry = leaderboardProvider.leaderboard[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LeaderboardRow(
                          entry: entry, 
                          rank: i + 1,
                          isMe: entry.userId == insightsProvider.userId,
                        ),
                      );
                    },
                    childCount: leaderboardProvider.leaderboard.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTheme.labelMD.copyWith(letterSpacing: 2.0));
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: double.infinity,
      color: AppTheme.surface1.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Rankings below include consistency points for motivation.', style: AppTheme.bodySM),
          const Text('Official prizes use approved physical measurements only.', style: TextStyle(fontSize: 9, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildMissingBaselineState() {
    return EFCard(
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.textTertiary, size: 32),
          const SizedBox(height: 16),
          Text(
            'Your baseline has not been approved yet. Once approved, your leaderboard insights will appear here.',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.leaderboard_outlined, color: AppTheme.textTertiary, size: 64),
            const SizedBox(height: 24),
            const Text(
              'No approved data yet.',
              style: AppTheme.headingSM,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'The leaderboard will appear once baseline and progress submissions are approved by admins.',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMD.copyWith(color: AppTheme.error)),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isMe;

  const _LeaderboardRow({required this.entry, required this.rank, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = rank <= 3;
    final Color rankColor = rank == 1 
        ? const Color(0xFFFFD700) // Gold
        : rank == 2 
            ? const Color(0xFFC0C0C0) // Silver
            : rank == 3 
                ? const Color(0xFFCD7F32) // Bronze
                : AppTheme.textTertiary;

    return EFCard(
      padding: const EdgeInsets.all(16),
      color: isMe ? AppTheme.lime.withValues(alpha: 0.05) : null,
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTop3 ? rankColor.withValues(alpha: 0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: isTop3 ? Border.all(color: rankColor, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTheme.numericMD.copyWith(
                  fontSize: 14, 
                  color: isTop3 ? rankColor : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.displayName,
                        style: AppTheme.headingSM.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.lime,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated: ${entry.latestSubmissionType}',
                  style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.motivationalScore.toStringAsFixed(1),
                style: AppTheme.numericLG.copyWith(fontSize: 18, color: AppTheme.lime),
              ),
              Text(
                '${entry.weightLossPercentage.toStringAsFixed(1)}% progress',
                style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
