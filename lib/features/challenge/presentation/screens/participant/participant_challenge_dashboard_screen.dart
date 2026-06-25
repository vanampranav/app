import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_challenge_dashboard_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_payment_submission_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_baseline_submission_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_weekly_checkin_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_final_submission_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_my_submissions_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_leaderboard_screen.dart';

class ParticipantChallengeDashboardScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantChallengeDashboardScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => ParticipantChallengeDashboardProvider(
        challengeId: challengeId,
        userId: userId,
        challengeRepository: ctx.read<ChallengeRepository>(),
        participantRepository: ctx.read<ChallengeParticipantRepository>(),
        submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
        paymentRepository: ctx.read<PaymentRecordRepository>(),
      ),
      child: const _ParticipantChallengeDashboardContent(),
    );
  }
}

class _ParticipantChallengeDashboardContent extends StatelessWidget {
  const _ParticipantChallengeDashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ParticipantChallengeDashboardProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: Center(child: CircularProgressIndicator(color: AppTheme.lime)),
          );
        }

        if (provider.errorMessage != null) {
          return _buildErrorScaffold(provider.errorMessage!);
        }

        final challenge = provider.challenge!;
        final participant = provider.participant!;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(challenge.title, style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // Streams handle refresh automatically, but we can trigger a reload if needed
            },
            color: AppTheme.lime,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(challenge, participant),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ACTIONS'),
                  const SizedBox(height: 16),
                  _buildActionCards(context, provider, challenge, participant),
                  const SizedBox(height: 32),
                  _buildSectionTitle('CHALLENGE INFO'),
                  const SizedBox(height: 16),
                  _buildChallengeInfo(challenge),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(Challenge challenge, ChallengeParticipant participant) {
    return EFCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY STATUS', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
                  const SizedBox(height: 4),
                  _StatusBadge(status: participant.status, type: 'participant'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('PAYMENT', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
                  const SizedBox(height: 4),
                  _StatusBadge(status: participant.paymentStatus, type: 'payment'),
                ],
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          Row(
            children: [
              Expanded(child: _buildTimelineInfo('Start', challenge.startDate)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimelineInfo('End', challenge.endDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineInfo(String label, DateTime date) {
    final df = DateFormat('MMM dd, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 10, color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(df.format(date), style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context, ParticipantChallengeDashboardProvider provider, Challenge challenge, ChallengeParticipant participant) {
    final paymentStatus = participant.paymentStatus;
    final participantStatus = participant.status;
    final baseline = provider.baselineSubmission;
    
    // Availability Rules
    final canSubmitPayment = paymentStatus == PaymentStatus.pending || paymentStatus == PaymentStatus.rejected;
    final canSubmitBaseline = participantStatus == ParticipantStatus.active || participantStatus == ParticipantStatus.joined;
    final canSubmitWeekly = baseline != null && baseline.reviewStatus == ReviewStatus.approved;
    
    final now = DateTime.now();
    final canSubmitFinal = canSubmitWeekly && now.isAfter(challenge.endDate.subtract(const Duration(days: 3)));

    return Column(
      children: [
        _ActionCard(
          title: 'Submit Payment Proof',
          icon: Icons.payments_outlined,
          isEnabled: canSubmitPayment,
          subtitle: paymentStatus == PaymentStatus.paid ? 'Payment Verified' : 'Required to start challenge',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantPaymentSubmissionScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Submit Baseline',
          icon: Icons.straighten_rounded,
          isEnabled: canSubmitBaseline,
          status: baseline?.reviewStatus,
          subtitle: baseline == null ? 'Photos & initial weight' : 'Status: ${baseline.reviewStatus}',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantBaselineSubmissionScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Weekly Check-In',
          icon: Icons.event_available_rounded,
          isEnabled: canSubmitWeekly,
          subtitle: !canSubmitWeekly ? 'Available after baseline approval' : 'Log your progress',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantWeeklyCheckinScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Final Submission',
          icon: Icons.emoji_events_outlined,
          isEnabled: canSubmitFinal,
          subtitle: !canSubmitFinal ? 'Available at end of challenge' : 'Final results',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantFinalSubmissionScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'My Submissions',
          icon: Icons.history_rounded,
          isEnabled: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantMySubmissionsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Leaderboard',
          icon: Icons.leaderboard_outlined,
          isEnabled: true,
          subtitle: 'See standings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantLeaderboardScreen(challengeId: challenge.id))),
        ),
      ],
    );
  }

  Widget _buildChallengeInfo(Challenge challenge) {
    return EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRIZE', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(challenge.prizeDescription, style: AppTheme.bodyMD.copyWith(color: AppTheme.lime)),
          const SizedBox(height: 20),
          Text('RULES', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(challenge.rulesSummary, style: AppTheme.bodyMD),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTheme.labelMD.copyWith(letterSpacing: 2.0));
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMD),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;
  final String? status;

  const _ActionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? AppTheme.lime : AppTheme.textTertiary;
    
    return EFCard(
      onTap: isEnabled ? onTap : null,
      color: isEnabled ? AppTheme.surface1 : AppTheme.surface1.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelLG.copyWith(color: isEnabled ? Colors.white : AppTheme.textTertiary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTheme.bodySM.copyWith(color: isEnabled ? AppTheme.textSecondary : AppTheme.textTertiary, fontSize: 11)),
                ],
              ],
            ),
          ),
          if (isEnabled)
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary)
          else
            const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary, size: 18),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String type;

  const _StatusBadge({Key? key, required this.status, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (type == 'participant') {
      switch (status) {
        case 'active': color = AppTheme.lime; break;
        case 'joined':
        case 'invited': color = Colors.blue; break;
        case 'completed': color = Colors.green; break;
        case 'withdrawn':
        case 'disqualified': color = AppTheme.error; break;
        default: color = Colors.grey;
      }
    } else {
      switch (status) {
        case 'paid': color = AppTheme.lime; break;
        case 'pending': color = Colors.amber; break;
        case 'waived': color = Colors.blue; break;
        case 'refunded':
        case 'rejected': color = AppTheme.error; break;
        default: color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
