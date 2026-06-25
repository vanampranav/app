import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/admin_audit_log.dart';

class AdminAuditLogRepository {
  final FirebaseFirestore _firestore;

  AdminAuditLogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.adminAuditLogs);

  Future<void> createAuditLog(AdminAuditLog auditLog) async {
    try {
      await _collection.doc(auditLog.id.isEmpty ? null : auditLog.id).set(
            auditLog.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to create audit log: $e');
    }
  }

  Stream<List<AdminAuditLog>> streamAuditLogsByChallenge(String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminAuditLog.fromFirestore(doc))
            .toList());
  }

  Stream<List<AdminAuditLog>> streamAuditLogsByAdmin(String adminId) {
    return _collection
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminAuditLog.fromFirestore(doc))
            .toList());
  }
}
