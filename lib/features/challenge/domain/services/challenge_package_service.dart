import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_package_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';

class ChallengePackageService {
  final ChallengePackageRepository _packageRepository;
  final ChallengeParticipantRepository _participantRepository;

  ChallengePackageService({
    required ChallengePackageRepository packageRepository,
    required ChallengeParticipantRepository participantRepository,
  })  : _packageRepository = packageRepository,
        _participantRepository = participantRepository;

  Future<List<ChallengePackage>> getActivePackages(String challengeId) async {
    return _packageRepository.getActivePackages(challengeId);
  }

  Future<List<ChallengePackage>> getAllPackages(String challengeId) async {
    return _packageRepository.getAllPackages(challengeId);
  }

  Future<ChallengePackage?> getPackage(String challengeId, String packageId) async {
    return _packageRepository.getPackage(challengeId, packageId);
  }

  Future<void> savePackage(ChallengePackage package) async {
    await _packageRepository.savePackage(package);
  }

  Future<void> updatePackage(ChallengePackage package) async {
    await _packageRepository.updatePackage(package);
  }

  Future<void> deactivatePackage(String challengeId, String packageId) async {
    final package = await _packageRepository.getPackage(challengeId, packageId);
    if (package != null) {
      await _packageRepository.updatePackage(package.copyWith(isActive: false));
    }
  }

  Future<void> deletePackage(String challengeId, String packageId) async {
    final hasParticipants = await _participantRepository.hasParticipantsWithPackage(challengeId, packageId);
    if (hasParticipants) {
      throw Exception('Cannot delete package because participants are already enrolled. Deactivate it instead.');
    }
    await _packageRepository.deletePackage(challengeId, packageId);
  }
}
