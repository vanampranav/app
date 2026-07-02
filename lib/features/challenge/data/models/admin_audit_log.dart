import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_parsing.dart';

class AdminAuditLog {
  final String id;
  final String adminId;
  final String? challengeId; // Added to easily filter all logs for a challenge
  final String action; // e.g. update_payment, disqualify_participant
  final String targetCollection; // e.g. challenges, paymentRecords
  final String targetId;
  final Map<String, dynamic>? previousData;
  final Map<String, dynamic>? newData;
  final String? reason;
  final DateTime? createdAt;

  AdminAuditLog({
    required this.id,
    required this.adminId,
    this.challengeId,
    required this.action,
    required this.targetCollection,
    required this.targetId,
    this.previousData,
    this.newData,
    this.reason,
    this.createdAt,
  });

  AdminAuditLog copyWith({
    String? id,
    String? adminId,
    String? challengeId,
    String? action,
    String? targetCollection,
    String? targetId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? newData,
    String? reason,
    DateTime? createdAt,
  }) {
    return AdminAuditLog(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      challengeId: challengeId ?? this.challengeId,
      action: action ?? this.action,
      targetCollection: targetCollection ?? this.targetCollection,
      targetId: targetId ?? this.targetId,
      previousData: previousData ?? this.previousData,
      newData: newData ?? this.newData,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'challengeId': challengeId,
      'action': action,
      'targetCollection': targetCollection,
      'targetId': targetId,
      'previousData': previousData,
      'newData': newData,
      'reason': reason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory AdminAuditLog.fromMap(Map<String, dynamic> map, String documentId) {
    return AdminAuditLog(
      id: documentId,
      adminId: map['adminId'] ?? '',
      challengeId: map['challengeId'],
      action: map['action'] ?? '',
      targetCollection: map['targetCollection'] ?? '',
      targetId: map['targetId'] ?? '',
      previousData: map['previousData'],
      newData: map['newData'],
      reason: map['reason'],
      createdAt: parseFirestoreDate(map['createdAt']),
    );
  }

  factory AdminAuditLog.fromFirestore(DocumentSnapshot doc) {
    return AdminAuditLog.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
