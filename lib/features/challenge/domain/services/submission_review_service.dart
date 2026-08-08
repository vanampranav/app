import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'admin_audit_service.dart';
import 'challenge_notification_service.dart';
import 'leaderboard_service.dart';

class SubmissionReviewService {
  final ChallengeSubmissionRepository _submissionRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeRepository _challengeRepository;
  final AdminAuditService _auditService;
  final ChallengeNotificationService _notificationService;

  /// Optional: when present, the public leaderboard is recomputed after a
  /// review changes scores. Nullable so tests can omit it.
  final LeaderboardService? _leaderboardService;

  SubmissionReviewService({
    required ChallengeSubmissionRepository submissionRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeRepository challengeRepository,
    required AdminAuditService auditService,
    required ChallengeNotificationService notificationService,
    LeaderboardService? leaderboardService,
  })  : _submissionRepository = submissionRepository,
        _participantRepository = participantRepository,
        _challengeRepository = challengeRepository,
        _auditService = auditService,
        _notificationService = notificationService,
        _leaderboardService = leaderboardService;

  /// Best-effort refresh of the public leaderboard snapshot after a review.
  Future<void> _refreshLeaderboard(String challengeId) async {
    await _leaderboardService?.recomputeAndPublish(challengeId);
  }

  /// Max times a participant may resubmit the SAME slot (a rejected / fix-required
  /// baseline, or a given week's check-in) before they are blocked.
  static const int maxResubmissions = 3;

  Future<void> _submit(String userId, String challengeId, String type, Map<String, dynamic> data) async {
    // Check if participant is approved
    final participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
    if (participant == null || participant.status != ParticipantStatus.active) {
      throw Exception('Participant must be approved before submitting.');
    }

    // Fetch this (user, challenge)'s submissions — scoped so an approved baseline
    // in a DIFFERENT challenge can never satisfy these guards (cross-challenge
    // baseline-leak bug).
    final submissions = await _submissionRepository
        .streamSubmissionsByParticipantAndChallenge(userId, challengeId)
        .first;

    // Weekly / final require an approved baseline for THIS challenge.
    if (type != SubmissionType.baseline) {
      final hasBaseline = submissions.any((s) =>
          s.type == SubmissionType.baseline &&
          s.reviewStatus == ReviewStatus.approved);
      if (!hasBaseline) {
        throw Exception('Baseline submission must be approved before weekly or final submissions.');
      }
    }

    // Timing guards that need the challenge dates.
    if (type == SubmissionType.weeklyCheckIn || type == SubmissionType.finalSubmission) {
      final challenge = await _challengeRepository.getChallengeById(challengeId);
      final now = DateTime.now();
      final finalWindowOpen = challenge != null &&
          !now.isBefore(challenge.endDate.subtract(const Duration(days: 3)));

      if (type == SubmissionType.weeklyCheckIn) {
        // Week 0 is the "baseline week" — no check-in until week 1 (day 7).
        final wk = data['weekNumber'];
        final weekNum = wk is num ? wk.toInt() : 0;
        if (weekNum < 1) {
          throw Exception('Weekly check-ins open after your first week.');
        }
        // Weekly check-ins close once the final window opens, so the last one
        // never collides with the final submission.
        if (finalWindowOpen) {
          throw Exception('Weekly check-ins are closed. Please submit your final results instead.');
        }
      } else {
        // Final submission: only near / after the end date.
        if (challenge != null && !finalWindowOpen) {
          throw Exception('Final submission can only be submitted near or after the challenge end date.');
        }
      }
    }

    // Find the ONE submission this would replace. A weekly is keyed by its week;
    // baseline / final are singletons per (user, challenge). Newest first so we
    // update the most recent if legacy duplicate docs already exist.
    final weekNumber = data['weekNumber'];
    final slotDocs = submissions.where((s) {
      if (s.type != type) return false;
      if (type == SubmissionType.weeklyCheckIn) {
        return s.data['weekNumber'] == weekNumber;
      }
      return true; // baseline / final: one per participant
    }).toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    if (slotDocs.isNotEmpty) {
      // A pending or approved submission already occupies this slot → nothing to
      // resubmit over.
      final occupied = slotDocs.any((s) =>
          s.reviewStatus == ReviewStatus.submitted ||
          s.reviewStatus == ReviewStatus.approved);
      if (occupied) {
        if (type == SubmissionType.weeklyCheckIn) {
          throw Exception('You have already submitted your check-in for week $weekNumber.');
        }
        throw Exception('This submission is already pending review or approved.');
      }

      // Otherwise it was rejected / needs-clarification → this is a RESUBMISSION.
      // Update the SAME document in place (no new doc) and reset it to pending,
      // so the admin only ever reviews the current version and there is never a
      // stale copy to approve.
      final existing = slotDocs.first;
      if (existing.resubmitCount >= maxResubmissions) {
        throw Exception(
            'You have reached the maximum of $maxResubmissions resubmissions for this submission. Please contact support.');
      }

      final updated = existing.copyWith(
        data: data,
        reviewStatus: ReviewStatus.submitted,
        resubmitCount: existing.resubmitCount + 1,
        updatedAt: DateTime.now(),
      );
      await _submissionRepository.updateSubmission(updated);
      return;
    }

    // First submission for this slot → create a new document.
    final submission = ChallengeSubmission(
      id: '',
      challengeId: challengeId,
      userId: userId,
      type: type,
      data: data,
      reviewStatus: ReviewStatus.submitted,
      createdAt: DateTime.now(),
    );

    await _submissionRepository.createSubmission(submission);
  }

  Future<void> submitBaseline(String userId, String challengeId, Map<String, dynamic> data) async {
    await _submit(userId, challengeId, SubmissionType.baseline, data);
  }

  Future<void> submitWeeklyCheckIn(String userId, String challengeId, Map<String, dynamic> data) async {
    await _submit(userId, challengeId, SubmissionType.weeklyCheckIn, data);
  }

  Future<void> submitFinalSubmission(String userId, String challengeId, Map<String, dynamic> data) async {
    await _submit(userId, challengeId, SubmissionType.finalSubmission, data);
  }

  Future<void> approveSubmission(String submissionId, String adminId) async {
    final submission = await _submissionRepository.getSubmission(submissionId);
    if (submission == null) {
      throw Exception('Submission not found.');
    }

    final previousData = submission.toMap();
    final updatedSubmission = submission.copyWith(
      reviewStatus: ReviewStatus.approved,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _submissionRepository.updateSubmission(updatedSubmission);

    // If baseline is approved, update participant record
    if (submission.type == SubmissionType.baseline) {
      final participant = await _participantRepository.getParticipantByUserAndChallenge(submission.userId, submission.challengeId);
      if (participant != null) {
        // Recalculate eligibility
        final bool isPaymentEligible = participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived;
        final bool isEligible = isPaymentEligible && 
                                participant.status == ParticipantStatus.active && 
                                !participant.disqualified;

        await _participantRepository.updateParticipant(participant.copyWith(
          baselineSubmitted: true,
          eligibleForPrizes: isEligible,
          updatedAt: DateTime.now(),
        ));
      }
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: submission.challengeId,
      action: 'approve_submission',
      targetCollection: FirestoreCollections.challengeSubmissions,
      targetId: submissionId,
      previousData: previousData,
      newData: updatedSubmission.toMap(),
    );

    final challenge = await _challengeRepository.getChallengeById(submission.challengeId);
    if (challenge != null) {
      await _notificationService.notifySubmissionApproved(submission.userId, challenge.title, submission.type, submission.challengeId);
    }

    await _refreshLeaderboard(submission.challengeId);
  }

  Future<void> rejectSubmission(String submissionId, String adminId, String reason) async {
    final submission = await _submissionRepository.getSubmission(submissionId);
    if (submission == null) {
      throw Exception('Submission not found.');
    }

    final previousData = submission.toMap();
    final updatedSubmission = submission.copyWith(
      reviewStatus: ReviewStatus.rejected,
      adminReviewNotes: reason,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _submissionRepository.updateSubmission(updatedSubmission);

    // If baseline is approved, update participant record
    if (submission.type == SubmissionType.baseline) {
      final participant = await _participantRepository.getParticipantByUserAndChallenge(submission.userId, submission.challengeId);
      if (participant != null) {
        // Recalculate eligibility
        final bool isPaymentEligible = participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived;
        final bool isEligible = isPaymentEligible && 
                                participant.status == ParticipantStatus.active && 
                                !participant.disqualified;

        // Baseline was REJECTED — it is not approved, so it must NOT unlock
        // weekly/final. Clear the flag and recompute eligibility.
        await _participantRepository.updateParticipant(participant.copyWith(
          baselineSubmitted: false,
          eligibleForPrizes: false,
          updatedAt: DateTime.now(),
        ));
      }
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: submission.challengeId,
      action: 'reject_submission',
      targetCollection: FirestoreCollections.challengeSubmissions,
      targetId: submissionId,
      previousData: previousData,
      newData: updatedSubmission.toMap(),
      reason: reason,
    );

    final challenge = await _challengeRepository.getChallengeById(submission.challengeId);
    if (challenge != null) {
      await _notificationService.notifySubmissionRejected(submission.userId, challenge.title, submission.type, submission.challengeId);
    }

    await _refreshLeaderboard(submission.challengeId);
  }

  Future<void> requestResubmission(String submissionId, String adminId, String reason) async {
    final submission = await _submissionRepository.getSubmission(submissionId);
    if (submission == null) {
      throw Exception('Submission not found.');
    }

    final previousData = submission.toMap();
    final updatedSubmission = submission.copyWith(
      reviewStatus: ReviewStatus.needsClarification,
      adminReviewNotes: reason,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _submissionRepository.updateSubmission(updatedSubmission);

    // If baseline is approved, update participant record
    if (submission.type == SubmissionType.baseline) {
      final participant = await _participantRepository.getParticipantByUserAndChallenge(submission.userId, submission.challengeId);
      if (participant != null) {
        // Recalculate eligibility
        final bool isPaymentEligible = participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived;
        final bool isEligible = isPaymentEligible && 
                                participant.status == ParticipantStatus.active && 
                                !participant.disqualified;

        // Resubmission requested — baseline is not approved, so it must NOT
        // unlock weekly/final. Clear the flag and recompute eligibility.
        await _participantRepository.updateParticipant(participant.copyWith(
          baselineSubmitted: false,
          eligibleForPrizes: false,
          updatedAt: DateTime.now(),
        ));
      }
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: submission.challengeId,
      action: 'request_resubmission',
      targetCollection: FirestoreCollections.challengeSubmissions,
      targetId: submissionId,
      previousData: previousData,
      newData: updatedSubmission.toMap(),
      reason: reason,
    );

    final challenge = await _challengeRepository.getChallengeById(submission.challengeId);
    if (challenge != null) {
      await _notificationService.notifyResubmissionRequested(submission.userId, challenge.title, submission.type, submission.challengeId);
    }

    await _refreshLeaderboard(submission.challengeId);
  }
}
