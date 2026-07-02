import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';

class ChallengeRepository {
  final FirebaseFirestore _firestore;

  ChallengeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.challenges);

  Future<void> createChallenge(Challenge challenge) async {
    try {
      await _collection.doc(challenge.id.isEmpty ? null : challenge.id).set(
            challenge.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  Future<void> updateChallenge(Challenge challenge) async {
    try {
      await _collection.doc(challenge.id).update(challenge.toFirestore());
    } catch (e) {
      throw Exception('Failed to update challenge: $e');
    }
  }

  Future<Challenge?> getChallengeById(String challengeId) async {
    try {
      final doc = await _collection.doc(challengeId).get();
      if (!doc.exists) return null;
      return Challenge.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get challenge: $e');
    }
  }

  Stream<List<Challenge>> streamActiveChallenges() {
    return _collection
        .where('status', whereIn: [
          ChallengeStatus.registrationOpen,
          ChallengeStatus.active
        ])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Challenge.fromFirestore(doc)).toList());
  }

  Stream<List<Challenge>> streamAllChallenges() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Challenge.fromFirestore(doc)).toList());
  }

  Stream<Challenge?> streamChallengeById(String challengeId) {
    return _collection
        .doc(challengeId)
        .snapshots()
        .map((doc) => doc.exists ? Challenge.fromFirestore(doc) : null);
  }

  Future<void> deleteChallenge(String challengeId) async {
    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge != null && challenge.status == ChallengeStatus.draft) {
        await _collection.doc(challengeId).delete();
      } else {
        throw Exception('Only draft challenges can be deleted.');
      }
    } catch (e) {
      throw Exception('Failed to delete challenge: $e');
    }
  }
}
