import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';

/// Read/write access to the sanitized public leaderboard at
/// `challenges/{challengeId}/leaderboard/{userId}`.
///
/// Reads are open to any signed-in user (security-rule enforced); writes are
/// admin-only. Participants stream [streamStandings]; the admin-context
/// recompute calls [publishStandings].
class LeaderboardRepository {
  final FirebaseFirestore _firestore;

  LeaderboardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _collection(String challengeId) => _firestore
      .collection(FirestoreCollections.challenges)
      .doc(challengeId)
      .collection('leaderboard');

  Stream<List<LeaderboardStanding>> streamStandings(String challengeId) {
    return _collection(challengeId).snapshots().map((snapshot) => snapshot.docs
        .map((doc) => LeaderboardStanding.fromFirestore(doc))
        .toList());
  }

  Future<List<LeaderboardStanding>> getStandings(String challengeId) async {
    final snap = await _collection(challengeId).get();
    return snap.docs.map((d) => LeaderboardStanding.fromFirestore(d)).toList();
  }

  /// Upserts the given standings and deletes any stale rows no longer present.
  /// One batched write so the leaderboard flips atomically.
  Future<void> publishStandings(
      String challengeId, List<LeaderboardStanding> standings) async {
    final col = _collection(challengeId);
    final existing = await col.get();
    final keepIds = standings.map((s) => s.userId).toSet();

    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      if (!keepIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final s in standings) {
      batch.set(col.doc(s.userId), s.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }
}
