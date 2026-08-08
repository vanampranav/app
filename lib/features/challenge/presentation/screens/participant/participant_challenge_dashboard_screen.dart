import 'package:flutter/foundation.dart';
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
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_results_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_payment_recovery_screen.dart';
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

        if (kDebugMode) {
          debugPrint('Dashboard: Participant Doc Path: challenges/${participant.challengeId}/participants/${participant.userId}');
          debugPrint('Dashboard: paymentStatus: ${participant.paymentStatus}');
          debugPrint('Dashboard: eligibleForPrizes: ${participant.eligibleForPrizes}');
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(
              challenge.title,
              style: AppTheme.headingMD,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            color: AppTheme.lime,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(challenge, participant),
                  const SizedBox(height: 24),
                  _buildPaymentStatusCard(context, participant),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY STATUS', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
                    const SizedBox(height: 4),
                    _StatusBadge(status: participant.status, type: 'participant'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('PRIZE ELIGIBILITY', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
                    const SizedBox(height: 4),
                    _EligibilityBadge(isEligible: participant.eligibleForPrizes),
                  ],
                ),
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

  Widget _buildPaymentStatusCard(BuildContext context, ChallengeParticipant participant) {
    return EFCard(
      color: AppTheme.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PAYMENT STATUS', style: AppTheme.labelMD.copyWith(letterSpacing: 2)),
              _StatusBadge(status: participant.paymentStatus, type: 'payment'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniMetric('AMOUNT DUE', '${participant.amountDue} ${participant.currency ?? "USD"}'),
              const SizedBox(width: 32),
              _buildMiniMetric('COLLECTED', '${participant.amountCollected} ${participant.currency ?? "USD"}', 
                  color: participant.amountCollected >= participant.amountDue ? AppTheme.lime : Colors.amber),
            ],
          ),
          if (participant.paymentStatus == PaymentStatus.pending) ...[
            const Divider(height: 24, color: Colors.white10),
            Text(
              'Your enrollment has been received. Payment verification is pending.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
          if (participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived) ...[
            const Divider(height: 24, color: Colors.white10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.lime, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Payment Verified',
                  style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (participant.paymentStatus == PaymentStatus.failed) ...[
            const Divider(height: 24, color: Colors.white10),
            Text(
              'PAYMENT VERIFICATION FAILED',
              style: AppTheme.labelSM.copyWith(color: AppTheme.error, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              participant.paymentFailureReason ?? 'We could not verify your payment. Please submit updated proof.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            EFButton(
              label: 'Submit Payment Proof',
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => ParticipantPaymentRecoveryScreen(challengeId: participant.challengeId))
              ),
              height: 36,
            ),
          ],
          if (participant.paymentStatus == PaymentStatus.pendingReview) ...[
            const Divider(height: 24, color: Colors.white10),
            Row(
              children: [
                const Icon(Icons.hourglass_bottom_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Updated proof submitted. Admin review in progress.',
                    style: AppTheme.bodySM.copyWith(color: Colors.amber),
                  ),
                ),
              ],
            ),
          ],
          if (participant.paymentStatus == PaymentStatus.partiallyPaid) ...[
            const Divider(height: 24, color: Colors.white10),
            Text(
              'PARTIALLY PAID',
              style: AppTheme.labelSM.copyWith(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Remaining balance: ${participant.amountDue - participant.amountCollected} ${participant.currency ?? "USD"}',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            EFButton(
              label: 'Pay Remaining Balance',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ParticipantPaymentSubmissionScreen(challengeId: participant.challengeId)),
              ),
              height: 36,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.numericMD.copyWith(fontSize: 16, color: color ?? AppTheme.textPrimary)),
      ],
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

  // Plain-English status for a submitted baseline, so "why is check-in locked?"
  // is obvious from the Submit Baseline card itself.
  String _baselineStatusText(String reviewStatus) {
    switch (reviewStatus) {
      case ReviewStatus.approved:
        return 'Baseline approved';
      case ReviewStatus.needsClarification:
        return 'Needs changes — please resubmit';
      case ReviewStatus.rejected:
        return 'Rejected — please resubmit';
      default:
        return 'Submitted — awaiting organizer approval';
    }
  }

  Widget _buildResultsBanner(BuildContext context, Challenge challenge) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ParticipantChallengeResultsScreen(
                  challengeId: challenge.id))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.18),
            AppTheme.lime.withValues(alpha: 0.10),
          ]),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Results are in!', style: AppTheme.headingSM),
                  const SizedBox(height: 2),
                  Text('See your final rank and the winners.',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lime.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.lime, size: 20),
              SizedBox(width: 8),
              Text('HOW THIS CHALLENGE WORKS', style: AppTheme.labelSM),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Submit your payment proof to start.\n'
            '2. Submit your baseline (photos & weight) once the organizer approves your entry.\n'
            '3. Log a weekly check-in each week after your baseline is approved.\n'
            '4. Complete the final submission near the end date.',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context, ParticipantChallengeDashboardProvider provider, Challenge challenge, ChallengeParticipant participant) {
    final paymentStatus = participant.paymentStatus;
    final participantStatus = participant.status;
    final baseline = provider.baselineSubmission;
    
    // Availability Rules
    final canSubmitInitialPayment = paymentStatus == PaymentStatus.pending ||
        paymentStatus == PaymentStatus.partiallyPaid;
    final canSubmitRecoveryPayment = paymentStatus == PaymentStatus.failed;
    // Baseline requires the participant to be APPROVED (active). The service
    // rejects any other status, so the button must stay locked until then —
    // otherwise the user taps and gets a raw exception.
    final canSubmitBaseline = participantStatus == ParticipantStatus.active;
    final now = DateTime.now();
    final baselineApproved = baseline != null && baseline.reviewStatus == ReviewStatus.approved;
    // Weekly check-ins open after the first week and close once the final
    // window (last 3 days) opens, so the last one doesn't collide with the final.
    final firstCheckInOpen = now.isAfter(challenge.startDate.add(const Duration(days: 7)));
    final finalWindowOpen = now.isAfter(challenge.endDate.subtract(const Duration(days: 3)));
    final canSubmitWeekly = baselineApproved && firstCheckInOpen && !finalWindowOpen;
    final canSubmitFinal = baselineApproved && finalWindowOpen;

    String paymentSubtitle = 'Required to start challenge';
    if (paymentStatus == PaymentStatus.paid || paymentStatus == PaymentStatus.waived) {
      paymentSubtitle = 'Payment Verified';
    } else if (paymentStatus == PaymentStatus.pendingReview) {
      paymentSubtitle = 'Review in Progress';
    } else if (paymentStatus == PaymentStatus.failed) {
      paymentSubtitle = 'Action Required: Verification Failed';
    }

    return Column(
      children: [
        if (challenge.status == 'completed') ...[
          _buildResultsBanner(context, challenge),
          const SizedBox(height: 16),
        ] else ...[
          _buildStepsBanner(),
          const SizedBox(height: 16),
        ],
        _ActionCard(
          title: 'Submit Payment Proof',
          icon: Icons.payments_outlined,
          isEnabled: canSubmitInitialPayment || canSubmitRecoveryPayment,
          subtitle: paymentSubtitle,
          onTap: () {
            if (canSubmitRecoveryPayment) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantPaymentRecoveryScreen(challengeId: challenge.id)));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantPaymentSubmissionScreen(challengeId: challenge.id)));
            }
          },
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Submit Baseline',
          icon: Icons.straighten_rounded,
          isEnabled: canSubmitBaseline,
          status: baseline?.reviewStatus,
          subtitle: !canSubmitBaseline
              ? 'Available after the organizer approves your entry'
              : (baseline == null ? 'Photos & initial weight' : _baselineStatusText(baseline.reviewStatus)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantBaselineSubmissionScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Weekly Check-In',
          icon: Icons.event_available_rounded,
          isEnabled: canSubmitWeekly,
          subtitle: !baselineApproved
              ? 'Locked until the organizer approves your baseline'
              : (!firstCheckInOpen
                  ? 'Opens after your first week'
                  : (finalWindowOpen ? 'Closed — submit your Final results' : 'Log your progress')),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantWeeklyCheckinScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Final Submission',
          icon: Icons.emoji_events_outlined,
          isEnabled: canSubmitFinal,
          subtitle: !canSubmitFinal ? 'Unlocks in the final days of the challenge' : 'Final results',
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
        case 'paid':
        case 'waived': color = AppTheme.lime; break;
        case 'pending':
        case 'partiallyPaid': color = Colors.amber; break;
        case 'refunded': color = Colors.blue; break;
        case 'failed':
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

class _EligibilityBadge extends StatelessWidget {
  final bool isEligible;
  const _EligibilityBadge({required this.isEligible});

  @override
  Widget build(BuildContext context) {
    final color = isEligible ? AppTheme.lime : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isEligible ? 'ELIGIBLE' : 'NOT ELIGIBLE',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
