import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_leaderboard_provider.dart';
import 'package:elefit_app/features/challenge/presentation/providers/leaderboard_insights_provider.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/leaderboard_insight_card.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/participant_progress_chart.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/score_breakdown_card.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/leaderboard_scoring_help_card.dart';

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
            leaderboardRepository: ctx.read<LeaderboardRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LeaderboardInsightsProvider(
            challengeId: challengeId,
            userId: userId,
            challengeRepository: ctx.read<ChallengeRepository>(),
            submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
            leaderboardRepository: ctx.read<LeaderboardRepository>(),
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

              // "How to score & climb" explainer (collapsible, shown to everyone)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(child: LeaderboardScoringHelpCard()),
              ),

              // Published winners (only after the admin declares results)
              if (leaderboardProvider.challenge?.resultsPublished == true &&
                  (leaderboardProvider.challenge?.winners.isNotEmpty ?? false))
                SliverToBoxAdapter(
                  child: _buildWinnersBanner(leaderboardProvider.challenge!),
                ),

              // Personal insight card + the rankings heading. The rankings list
              // now sits high (right under your insight card); the progress-trend
              // chart moves below it.
              if (insights != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LeaderboardInsightCard(insights: insights),
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

              // Global Leaderboard List (moved up — was below the progress chart)
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

              // Score breakdown + Progress trend chart (moved BELOW the rankings)
              if (insights != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScoreBreakdownCard(insights: insights),
                        const SizedBox(height: 24),
                        ParticipantProgressChart(points: insights.progressPoints),
                      ],
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

  Widget _buildWinnersBanner(Challenge challenge) {
    final podium = challenge.winners.where((w) => !w.isSpecialAward).toList()
      ..sort((a, b) => a.place.compareTo(b.place));
    final special = challenge.winners.where((w) => w.isSpecialAward).toList();

    Color medal(int place) => place == 1
        ? const Color(0xFFFFD700)
        : place == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: EFCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Text('WINNERS',
                  style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
            ]),
            const SizedBox(height: 14),
            ...podium.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.emoji_events, color: medal(w.place), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(w.displayName, style: AppTheme.bodyLG)),
                    Text(w.awardLabel,
                        style: AppTheme.bodySM
                            .copyWith(color: AppTheme.textSecondary)),
                  ]),
                )),
            ...special.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    const Icon(Icons.workspace_premium_outlined,
                        color: AppTheme.lime, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(w.displayName, style: AppTheme.bodyLG)),
                    Text(w.awardLabel,
                        style: AppTheme.bodySM.copyWith(color: AppTheme.lime)),
                  ]),
                )),
          ],
        ),
      ),
    );
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
          const Text('Ranked by points earned at every check-in — body fat, weight & muscle.', style: AppTheme.bodySM),
          const Text('Prizes need a verified payment + an approved final submission.', style: TextStyle(fontSize: 9, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
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
    final String? medal =
        rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;

    return EFCard(
      padding: const EdgeInsets.all(16),
      color: isMe ? AppTheme.lime.withValues(alpha: 0.05) : null,
      child: Row(
        children: [
          // Medal for the top 3, otherwise a plain rank number.
          SizedBox(
            width: 36,
            height: 36,
            child: medal != null
                ? Center(child: Text(medal, style: const TextStyle(fontSize: 26)))
                : Center(
                    child: Text(
                      '$rank',
                      style: AppTheme.numericMD.copyWith(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          
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
            children: entry.latestSubmissionType == 'Not started'
                ? [
                    Text('—', style: AppTheme.numericLG.copyWith(fontSize: 18, color: AppTheme.textTertiary)),
                    Text('Not started', style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textSecondary)),
                  ]
                : [
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
