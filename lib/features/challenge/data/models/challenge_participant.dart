import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeParticipant {
  final String id;
  final String challengeId;
  final String userId;
  final String status; // ParticipantStatus
  final String paymentStatus; // PaymentStatus
  final String? paymentRecordId;
  final DateTime? joinedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Admin fields
  final String? lastUpdatedByAdminId;
  final String? adminNotes;
  final String? adminAdjustmentReason;
  final Map<String, dynamic>? adminMetaData;

  ChallengeParticipant({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    this.paymentRecordId,
    this.joinedAt,
    this.createdAt,
    this.updatedAt,
    this.lastUpdatedByAdminId,
    this.adminNotes,
    this.adminAdjustmentReason,
    this.adminMetaData,
  });

  ChallengeParticipant copyWith({
    String? id,
    String? challengeId,
    String? userId,
    String? status,
    String? paymentStatus,
    String? paymentRecordId,
    DateTime? joinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastUpdatedByAdminId,
    String? adminNotes,
    String? adminAdjustmentReason,
    Map<String, dynamic>? adminMetaData,
  }) {
    return ChallengeParticipant(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentRecordId: paymentRecordId ?? this.paymentRecordId,
      joinedAt: joinedAt ?? this.joinedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedByAdminId: lastUpdatedByAdminId ?? this.lastUpdatedByAdminId,
      adminNotes: adminNotes ?? this.adminNotes,
      adminAdjustmentReason: adminAdjustmentReason ?? this.adminAdjustmentReason,
      adminMetaData: adminMetaData ?? this.adminMetaData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'userId': userId,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentRecordId': paymentRecordId,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedByAdminId': lastUpdatedByAdminId,
      'adminNotes': adminNotes,
      'adminAdjustmentReason': adminAdjustmentReason,
      'adminMetaData': adminMetaData,
    };
  }

  factory ChallengeParticipant.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengeParticipant(
      id: documentId,
      challengeId: map['challengeId'] ?? '',
      userId: map['userId'] ?? '',
      status: map['status'] ?? 'invited',
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentRecordId: map['paymentRecordId'],
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      lastUpdatedByAdminId: map['lastUpdatedByAdminId'],
      adminNotes: map['adminNotes'],
      adminAdjustmentReason: map['adminAdjustmentReason'],
      adminMetaData: map['adminMetaData'],
    );
  }

  factory ChallengeParticipant.fromFirestore(DocumentSnapshot doc) {
    return ChallengeParticipant.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
