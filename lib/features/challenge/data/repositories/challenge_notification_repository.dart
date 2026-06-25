import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_notification.dart';

class ChallengeNotificationRepository {
  final FirebaseFirestore _firestore;

  ChallengeNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.notifications);

  Future<void> createNotification(ChallengeNotification notification) async {
    try {
      await _collection
          .doc(notification.id.isEmpty ? null : notification.id)
          .set(
            notification.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Stream<List<ChallengeNotification>> streamNotificationsForUser(
      String userId) {
    return _collection
        .where('recipientUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeNotification.fromFirestore(doc))
            .toList());
  }

  Stream<List<ChallengeNotification>> streamUnreadNotificationsForUser(
      String userId) {
    return _collection
        .where('recipientUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeNotification.fromFirestore(doc))
            .toList());
  }
}
