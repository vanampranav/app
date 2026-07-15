import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_package_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'admin_audit_service.dart';

class ChallengeService {
  final ChallengeRepository _challengeRepository;
  final AdminAuditService _auditService;
  final ChallengePackageRepository _packageRepository;

  ChallengeService({
    required ChallengeRepository challengeRepository,
    required AdminAuditService auditService,
    required ChallengePackageRepository packageRepository,
  })  : _challengeRepository = challengeRepository,
        _auditService = auditService,
        _packageRepository = packageRepository;

  Future<void> createDraftChallenge({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime registrationDeadline,
    required double registrationFee,
    required int maxParticipants,
    required String prizeDescription,
    required String rulesSummary,
    required bool baselineRequired,
    required bool finalPhotoRequired,
    required String adminId,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw Exception('End date must be after start date.');
    }
    
    if (registrationDeadline.isAfter(startDate)) {
      throw Exception('Registration deadline must be before or equal to start date.');
    }

    final challenge = Challenge(
      id: '', // Firestore will generate
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      registrationDeadline: registrationDeadline,
      registrationFee: registrationFee,
      maxParticipants: maxParticipants,
      prizeDescription: prizeDescription,
      rulesSummary: rulesSummary,
      baselineRequired: baselineRequired,
      finalPhotoRequired: finalPhotoRequired,
      status: ChallengeStatus.draft,
      createdByAdminId: adminId,
      createdAt: DateTime.now(),
    );

    await _challengeRepository.createChallenge(challenge);
  }

  Future<void> activateChallenge(String challengeId, String adminId) async {
    final challenge = await _challengeRepository.getChallengeById(challengeId);
    if (challenge == null) {
      throw Exception('Challenge not found.');
    }

    if (challenge.status != ChallengeStatus.draft) {
      throw Exception('Only draft challenges can be activated.');
    }

    // Validation before activation
    if (challenge.title.isEmpty || challenge.description.isEmpty) {
      throw Exception('Challenge must have a title and description.');
    }
    
    if (challenge.endDate.isBefore(challenge.startDate)) {
      throw Exception('End date must be after start date.');
    }

    // A challenge can't be joined without an active package to select, so block
    // opening registration until at least one exists (prevents the participant
    // "No Packages" dead-end).
    final activePackages = await _packageRepository.getActivePackages(challengeId);
    if (activePackages.isEmpty) {
      throw Exception('Please connect the challenge to a package to make it active.');
    }

    final updatedChallenge = challenge.copyWith(
      status: ChallengeStatus.registrationOpen,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _challengeRepository.updateChallenge(updatedChallenge);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: challengeId,
      action: 'activate_challenge',
      targetCollection: FirestoreCollections.challenges,
      targetId: challengeId,
      previousData: challenge.toMap(),
      newData: updatedChallenge.toMap(),
    );
  }

  /// Permanently deletes a challenge (used for cleaning up test challenges).
  /// Note: this removes the challenge document; its participant/package
  /// subcollections are not recursively deleted (fine for test cleanup).
  Future<void> deleteChallenge(String challengeId, String adminId) async {
    final challenge = await _challengeRepository.getChallengeById(challengeId);
    await _challengeRepository.deleteChallenge(challengeId);
    await _auditService.logAction(
      adminId: adminId,
      challengeId: challengeId,
      action: 'delete_challenge',
      targetCollection: FirestoreCollections.challenges,
      targetId: challengeId,
      previousData: challenge?.toMap(),
      newData: null,
    );
  }

  Future<void> updateChallengeConfig(Challenge challenge, String adminId) async {
    final original = await _challengeRepository.getChallengeById(challenge.id);
    
    if (challenge.status != ChallengeStatus.draft) {
       if (challenge.status == ChallengeStatus.completed || challenge.status == ChallengeStatus.cancelled) {
         throw Exception('Completed or cancelled challenges cannot be edited.');
       }
    }

    final updatedChallenge = challenge.copyWith(
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );
    await _challengeRepository.updateChallenge(updatedChallenge);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: challenge.id,
      action: 'update_challenge_config',
      targetCollection: FirestoreCollections.challenges,
      targetId: challenge.id,
      previousData: original?.toMap(),
      newData: updatedChallenge.toMap(),
    );
  }

  Future<void> closeChallenge(String challengeId, String adminId) async {
    final challenge = await _challengeRepository.getChallengeById(challengeId);
    if (challenge == null) {
      throw Exception('Challenge not found.');
    }

    final updatedChallenge = challenge.copyWith(
      status: ChallengeStatus.completed,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _challengeRepository.updateChallenge(updatedChallenge);

    await _auditService.logAction(
      adminId: adminId,
      challengeId: challengeId,
      action: 'close_challenge',
      targetCollection: FirestoreCollections.challenges,
      targetId: challengeId,
      previousData: challenge.toMap(),
      newData: updatedChallenge.toMap(),
    );
  }

  Stream<List<Challenge>> streamActiveChallenges() {
    return _challengeRepository.streamActiveChallenges();
  }
}
