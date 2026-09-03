import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';

class ChallengeParticipantRepository {
  final FirebaseFirestore _firestore;

  ChallengeParticipantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference _participantDoc(String challengeId, String userId) => _firestore
      .collection(FirestoreCollections.challenges)
      .doc(challengeId)
      .collection('participants')
      .doc(userId);

  Future<void> joinChallenge(ChallengeParticipant participant) async {
    try {
      final docRef = _participantDoc(participant.challengeId, participant.userId);
      if (kDebugMode) {
        debugPrint('Enrollment: Writing to path: ${docRef.path}');
      }
      await docRef.set(
        participant.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to join challenge: $e');
    }
  }

  Future<void> updateParticipant(ChallengeParticipant participant) async {
    try {
      final docRef = _participantDoc(participant.challengeId, participant.userId);
      if (kDebugMode) {
        debugPrint('Enrollment: Updating path: ${docRef.path}');
      }
      await docRef.update(participant.toFirestore());
    } catch (e) {
      throw Exception('Failed to update participant: $e');
    }
  }

  Future<ChallengeParticipant?> getParticipant(String challengeId, String userId) async {
    try {
      final doc = await _participantDoc(challengeId, userId).get();
      if (!doc.exists) return null;
      return ChallengeParticipant.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get participant: $e');
    }
  }

  // Helper for backward compatibility or when we only have the participant's own fields
  Future<ChallengeParticipant?> getParticipantFromObject(ChallengeParticipant p) async {
    return getParticipant(p.challengeId, p.userId);
  }

  Future<ChallengeParticipant?> getParticipantByUserAndChallenge(
      String userId, String challengeId) async {
    return getParticipant(challengeId, userId);
  }

  Stream<ChallengeParticipant?> streamParticipant(String challengeId, String userId) {
    return _participantDoc(challengeId, userId)
        .snapshots()
        .map((doc) => doc.exists ? ChallengeParticipant.fromFirestore(doc) : null);
  }

  Stream<List<ChallengeParticipant>> streamParticipantsByChallenge(
      String challengeId) {
    return _firestore
        .collection(FirestoreCollections.challenges)
        .doc(challengeId)
        .collection('participants')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeParticipant.fromFirestore(doc))
            .toList());
  }

  /// One-shot read of all participants for a challenge. Uses a plain get()
  /// (server-preferred, falling back to cache only when offline) instead of
  /// streamParticipantsByChallenge(...).first — that stream serves the offline
  /// cache first, which let a leaderboard recompute re-publish a stale/deleted
  /// participant still lingering in a client's cache. Use this for recompute.
  Future<List<ChallengeParticipant>> getParticipantsByChallenge(
      String challengeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.challenges)
          .doc(challengeId)
          .collection('participants')
          .get();
      return snapshot.docs
          .map((doc) => ChallengeParticipant.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get participants: $e');
    }
  }

  Stream<List<ChallengeParticipant>> streamParticipantsByUser(String userId) {
    // This now requires a collectionGroup query
    return _firestore
        .collectionGroup('participants')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeParticipant.fromFirestore(doc))
            .toList());
  }

  Future<bool> hasParticipantsWithPackage(String challengeId, String packageId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.challenges)
          .doc(challengeId)
          .collection('participants')
          .where('selectedPackageId', isEqualTo: packageId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check participants with package: $e');
    }
  }
}
