import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';

class ChallengePackageRepository {
  final FirebaseFirestore _firestore;

  ChallengePackageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _packagesCollection(String challengeId) => _firestore
      .collection(FirestoreCollections.challenges)
      .doc(challengeId)
      .collection('packages');

  Future<List<ChallengePackage>> getActivePackages(String challengeId) async {
    try {
      final snapshot = await _packagesCollection(challengeId)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();
      return snapshot.docs
          .map((doc) => ChallengePackage.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active packages: $e');
    }
  }

  Future<List<ChallengePackage>> getAllPackages(String challengeId) async {
    try {
      final snapshot = await _packagesCollection(challengeId)
          .orderBy('displayOrder')
          .get();
      return snapshot.docs
          .map((doc) => ChallengePackage.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all packages: $e');
    }
  }

  Future<ChallengePackage?> getPackage(String challengeId, String packageId) async {
    try {
      final doc = await _packagesCollection(challengeId).doc(packageId).get();
      if (!doc.exists) return null;
      return ChallengePackage.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get package: $e');
    }
  }

  Future<void> savePackage(ChallengePackage package) async {
    try {
      await _packagesCollection(package.challengeId)
          .doc(package.id.isEmpty ? null : package.id)
          .set(package.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save package: $e');
    }
  }

  Future<void> updatePackage(ChallengePackage package) async {
    try {
      await _packagesCollection(package.challengeId)
          .doc(package.id)
          .update(package.toFirestore());
    } catch (e) {
      throw Exception('Failed to update package: $e');
    }
  }

  Future<void> deletePackage(String challengeId, String packageId) async {
    try {
      await _packagesCollection(challengeId).doc(packageId).delete();
    } catch (e) {
      throw Exception('Failed to delete package: $e');
    }
  }
}
