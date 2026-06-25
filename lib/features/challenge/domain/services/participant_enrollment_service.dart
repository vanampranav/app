import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
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

    final participant = ChallengeParticipant(
      id: '', // Firestore will generate
      challengeId: challengeId,
      userId: userId,
      status: ParticipantStatus.joined,
      paymentStatus: PaymentStatus.pending,
      leaderboardDisplayName: leaderboardDisplayName,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _participantRepository.joinChallenge(participant);
    await _notificationService.notifyParticipantJoined(userId, challenge.title, challengeId);
  }

  Future<void> cancelParticipation(String userId, String challengeId) async {
    final participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
    if (participant == null) {
      throw Exception('Participant record not found.');
    }

    final updatedParticipant = participant.copyWith(
      status: ParticipantStatus.withdrawn,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);
  }

  Future<void> approveParticipant(String participantId, String adminId) async {
    final participant = await _participantRepository.getParticipant(participantId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }

    final previousData = participant.toMap();
    final updatedParticipant = participant.copyWith(
      status: ParticipantStatus.active,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: participant.challengeId,
      action: 'approve_participant',
      targetCollection: FirestoreCollections.challengeParticipants,
      targetId: participantId,
      previousData: previousData,
      newData: updatedParticipant.toMap(),
    );
    
    final challenge = await _challengeRepository.getChallengeById(participant.challengeId);
    if (challenge != null) {
      await _notificationService.notifyPaymentApproved(participant.userId, challenge.title, challenge.id);
    }
  }

  Future<void> rejectParticipant(String participantId, String adminId, String reason) async {
    final participant = await _participantRepository.getParticipant(participantId);
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
      targetId: participantId,
      previousData: previousData,
      newData: updatedParticipant.toMap(),
      reason: reason,
    );
  }
}
