import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';

class ChallengeParticipantRepository {
  final FirebaseFirestore _firestore;

  ChallengeParticipantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.challengeParticipants);

  Future<void> joinChallenge(ChallengeParticipant participant) async {
    try {
      await _collection.doc(participant.id.isEmpty ? null : participant.id).set(
            participant.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to join challenge: $e');
    }
  }

  Future<void> updateParticipant(ChallengeParticipant participant) async {
    try {
      await _collection.doc(participant.id).update(participant.toFirestore());
    } catch (e) {
      throw Exception('Failed to update participant: $e');
    }
  }

  Future<ChallengeParticipant?> getParticipant(String participantId) async {
    try {
      final doc = await _collection.doc(participantId).get();
      if (!doc.exists) return null;
      return ChallengeParticipant.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  Future<ChallengeParticipant?> getParticipantByUserAndChallenge(
      String userId, String challengeId) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .where('challengeId', isEqualTo: challengeId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return ChallengeParticipant.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get participant by user and challenge: $e');
    }
  }

  Stream<List<ChallengeParticipant>> streamParticipantsByChallenge(
      String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeParticipant.fromFirestore(doc))
            .toList());
  }

  Stream<List<ChallengeParticipant>> streamParticipantsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeParticipant.fromFirestore(doc))
            .toList());
  }
}
