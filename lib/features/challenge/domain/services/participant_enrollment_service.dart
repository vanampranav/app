import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'admin_audit_service.dart';
import 'challenge_notification_service.dart';

class ParticipantEnrollmentService {
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeRepository _challengeRepository;
  final AdminAuditService _auditService;
  final ChallengeNotificationService _notificationService;

  ParticipantEnrollmentService({
    required ChallengeParticipantRepository participantRepository,
    required ChallengeRepository challengeRepository,
    required AdminAuditService auditService,
    required ChallengeNotificationService notificationService,
  })  : _participantRepository = participantRepository,
        _challengeRepository = challengeRepository,
        _auditService = auditService,
        _notificationService = notificationService;

  Future<void> joinChallenge({
    required String userId,
    required String challengeId,
    String? leaderboardDisplayName,
    ChallengePackage? package,
  }) async {
    // Check if already joined
    final existing = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
    if (existing != null) {
      throw Exception('User has already joined this challenge.');
    }

    // Check challenge status
    final challenge = await _challengeRepository.getChallengeById(challengeId);
    if (challenge == null) {
      throw Exception('Challenge not found.');
    }

    if (challenge.status != ChallengeStatus.registrationOpen) {
      throw Exception('Challenge is not open for registration.');
    }

    if (kDebugMode) {
      debugPrint('Enrollment: Attempting join for User: $userId in Challenge: $challengeId');
    }

    // TODO: Future payment integration must use this snapshot to avoid price mismatch.
    final participant = ChallengeParticipant(
      id: '', // Firestore will generate
      challengeId: challengeId,
      userId: userId,
      status: ParticipantStatus.joined,
      paymentStatus: PaymentStatus.pending,
      amountDue: package?.packagePrice ?? 0.0,
      currency: package?.currency,
      leaderboardDisplayName: leaderboardDisplayName,
      selectedPackageId: package?.id,
      selectedPackageName: package?.name,
      selectedPackagePrice: package?.packagePrice,
      selectedPackageCurrency: package?.currency,
      selectedShopifyVariantsSnapshot: package?.shopifyVariants.map((v) => v.toMap()).toList(),
      packageSelectedAt: package != null ? DateTime.now() : null,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _participantRepository.joinChallenge(participant);

    // Notification is a best-effort side effect: a successful join must never
    // fail because the notification write was rejected (e.g. Firestore rules).
    try {
      await _notificationService.notifyParticipantJoined(userId, challenge.title, challengeId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Enrollment: join notification failed (non-fatal): $e');
      }
    }
  }

  Future<void> cancelParticipation(String userId, String challengeId) async {
    final participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
    if (participant == null) {
      throw Exception('Participant record not found.');
    }

    final updatedParticipant = participant.copyWith(
      status: ParticipantStatus.withdrawn,
      eligibleForPrizes: false,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);
  }

  Future<void> approveParticipant(String challengeId, String userId, String adminId) async {
    final participant = await _participantRepository.getParticipant(challengeId, userId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }

    final previousData = participant.toMap();
    
    // Recalculate eligibility
    final bool isPaymentEligible = participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived;
    final bool isEligible = isPaymentEligible && 
                            participant.baselineSubmitted && 
                            !participant.disqualified;

    final updatedParticipant = participant.copyWith(
      status: ParticipantStatus.active,
      eligibleForPrizes: isEligible,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: participant.challengeId,
      action: 'approve_participant',
      targetCollection: FirestoreCollections.challengeParticipants,
      targetId: userId,
      previousData: previousData,
      newData: updatedParticipant.toMap(),
    );
    
    final challenge = await _challengeRepository.getChallengeById(participant.challengeId);
    if (challenge != null) {
      await _notificationService.notifyParticipantApproved(participant.userId, challenge.title, challenge.id);
    }
  }

  Future<void> rejectParticipant(String challengeId, String userId, String adminId, String reason) async {
    final participant = await _participantRepository.getParticipant(challengeId, userId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }

    final previousData = participant.toMap();
    final updatedParticipant = participant.copyWith(
      status: ParticipantStatus.disqualified,
      adminAdjustmentReason: reason,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: participant.challengeId,
      action: 'reject_participant',
      targetCollection: FirestoreCollections.challengeParticipants,
      targetId: userId,
      previousData: previousData,
      newData: updatedParticipant.toMap(),
      reason: reason,
    );

    // Tell the participant their entry was rejected (best-effort — a failed
    // notification must not fail the rejection the admin just performed).
    try {
      final challenge = await _challengeRepository.getChallengeById(participant.challengeId);
      if (challenge != null) {
        await _notificationService.notifyParticipantRejected(
            participant.userId, challenge.title, challenge.id, reason);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Enrollment: reject notification failed (non-fatal): $e');
      }
    }
  }
}
