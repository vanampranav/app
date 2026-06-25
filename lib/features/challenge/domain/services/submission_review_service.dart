import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'admin_audit_service.dart';
import 'challenge_notification_service.dart';

class SubmissionReviewService {
  final ChallengeSubmissionRepository _submissionRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeRepository _challengeRepository;
  final AdminAuditService _auditService;
  final ChallengeNotificationService _notificationService;

  SubmissionReviewService({
    required ChallengeSubmissionRepository submissionRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeRepository challengeRepository,
    required AdminAuditService auditService,
    required ChallengeNotificationService notificationService,
  })  : _submissionRepository = submissionRepository,
        _participantRepository = participantRepository,
        _challengeRepository = challengeRepository,
        _auditService = auditService,
        _notificationService = notificationService;

  Future<void> _submit(String userId, String challengeId, String type, Map<String, dynamic> data) async {
    // Check if participant is approved
    final participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
    if (participant == null || participant.status != ParticipantStatus.active) {
      throw Exception('Participant must be approved before submitting.');
    }

    // Check if baseline is needed
    if (type != SubmissionType.baseline) {
      final submissions = await _submissionRepository.streamSubmissionsByParticipant(userId).first;
      final hasBaseline = submissions.any((s) => s.type == SubmissionType.baseline && s.reviewStatus == ReviewStatus.approved);
      if (!hasBaseline) {
        throw Exception('Baseline submission must be approved before weekly or final submissions.');
      }
    }

    // Final submission check
    if (type == SubmissionType.finalSubmission) {
      final challenge = await _challengeRepository.getChallengeById(challengeId);
      if (challenge != null) {
        final now = DateTime.now();
        // Allow final submission up to 3 days before end date
        if (now.isBefore(challenge.endDate.subtract(const Duration(days: 3)))) {
          throw Exception('Final submission can only be submitted near or after the challenge end date.');
        }
      }
    }

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
      await _notificationService.notifySubmissionApproved(submission.userId, challenge.title, submission.type);
    }
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
  }
}
