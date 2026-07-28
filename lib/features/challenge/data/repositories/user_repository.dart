import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.users);

  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _collection.doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    try {
      // Firestore 'in' queries are limited to 30 values in newer SDKs, 10 in older.
      // We'll chunk it by 10 for safety.
      List<AppUser> users = [];
      for (var i = 0; i < userIds.length; i += 10) {
        final chunk = userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
        final snapshot = await _collection.where(FieldPath.documentId, whereIn: chunk).get();
        users.addAll(snapshot.docs.map((doc) => AppUser.fromFirestore(doc)));
      }
      return users;
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  static String formatName(AppUser? user, {bool adminView = false, String fallbackId = '', String? leaderboardDisplayName}) {
    // 1. Priority: Nickname
    if (leaderboardDisplayName != null && leaderboardDisplayName.isNotEmpty) {
      if (adminView && user?.email != null && user!.email.isNotEmpty) {
        return '$leaderboardDisplayName (${user.email})';
      }
      return leaderboardDisplayName;
    }

    // 2. Priority: Real Name
    if (user == null || (user.firstName == null && user.lastName == null)) {
      if (adminView && user?.email != null && user!.email.isNotEmpty) {
        return user.email;
      }
      if (fallbackId.isEmpty) return 'Participant';
      final suffix =
          fallbackId.length >= 4 ? fallbackId.substring(0, 4) : fallbackId;
      return 'User $suffix';
    }
    
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    
    String name = 'Participant';
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      name = '$firstName ${lastName[0]}.';
    } else if (firstName.isNotEmpty) {
      name = firstName;
    } else if (lastName.isNotEmpty) {
      name = lastName;
    }

    if (adminView && user.email.isNotEmpty) {
      return '$name (${user.email})';
    }
    
    return name;
  }
}
