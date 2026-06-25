import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_leaderboard_provider.dart';

class ParticipantLeaderboardScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantLeaderboardScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ParticipantLeaderboardProvider(
        challengeId: challengeId,
        challengeRepository: ctx.read<ChallengeRepository>(),
        participantRepository: ctx.read<ChallengeParticipantRepository>(),
        submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
      ),
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
      body: Consumer<ParticipantLeaderboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(provider.errorMessage!);
          }

          if (provider.leaderboard.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildHeader(provider.challenge?.title ?? ''),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: provider.leaderboard.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final entry = provider.leaderboard[i];
                    return _LeaderboardRow(entry: entry, rank: i + 1);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: double.infinity,
      color: AppTheme.surface1.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Rankings by weight loss percentage', style: AppTheme.bodySM),
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

  const _LeaderboardRow({required this.entry, required this.rank});

  String _maskUserId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

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
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTop3 ? rankColor.withOpacity(0.2) : Colors.transparent,
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
                Text(_maskUserId(entry.userId), style: AppTheme.headingSM.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Last updated: ${entry.latestSubmissionType}',
                  style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          
          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.weightLossPercentage.toStringAsFixed(1)}%',
                style: AppTheme.numericLG.copyWith(fontSize: 18, color: AppTheme.lime),
              ),
              Text(
                '${entry.weightLost.toStringAsFixed(1)} kg lost',
                style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
