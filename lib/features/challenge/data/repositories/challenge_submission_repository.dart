import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';

class ChallengeSubmissionRepository {
  final FirebaseFirestore _firestore;

  ChallengeSubmissionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.challengeSubmissions);

  Future<void> createSubmission(ChallengeSubmission submission) async {
    try {
      await _collection.doc(submission.id.isEmpty ? null : submission.id).set(
            submission.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to create submission: $e');
    }
  }

  Future<void> updateSubmission(ChallengeSubmission submission) async {
    try {
      await _collection.doc(submission.id).update(submission.toFirestore());
    } catch (e) {
      throw Exception('Failed to update submission: $e');
    }
  }

  Future<ChallengeSubmission?> getSubmission(String submissionId) async {
    try {
      final doc = await _collection.doc(submissionId).get();
      if (!doc.exists) return null;
      return ChallengeSubmission.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get submission: $e');
    }
  }

  /// WARNING: returns the user's submissions across **every** challenge.
  /// Any caller working within a single challenge MUST filter the result by
  /// `challengeId`, or use [streamSubmissionsByParticipantAndChallenge] instead —
  /// otherwise an approved baseline in one challenge can leak into another.
  Stream<List<ChallengeSubmission>> streamSubmissionsByParticipant(
      String userId) {
    // Note: The prompt asked for participantId, but the model uses userId.
    // Assuming participant matches by userId in the context of challengeSubmissions.
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmission.fromFirestore(doc))
            .toList());
  }

  /// Challenge-scoped variant: only the given user's submissions for ONE
  /// challenge. Prefer this for any per-challenge logic (submission guards,
  /// eligibility) so cross-challenge data can never leak in.
  ///
  /// Uses two equality filters and no `orderBy`, so it needs NO composite
  /// index (equality-only queries are served by automatic single-field
  /// indexes). Sort in memory if order matters.
  Stream<List<ChallengeSubmission>> streamSubmissionsByParticipantAndChallenge(
      String userId, String challengeId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('challengeId', isEqualTo: challengeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmission.fromFirestore(doc))
            .toList());
  }

  Stream<List<ChallengeSubmission>> streamSubmissionsByChallenge(
      String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmission.fromFirestore(doc))
            .toList());
  }

  Stream<List<ChallengeSubmission>> streamPendingReviewSubmissions(
      String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .where('reviewStatus', isEqualTo: ReviewStatus.submitted)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmission.fromFirestore(doc))
            .toList());
  }
}
