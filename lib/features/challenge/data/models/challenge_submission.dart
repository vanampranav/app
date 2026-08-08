import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_parsing.dart';

class ChallengeSubmission {
  final String id;
  final String challengeId;
  final String userId;
  final String type; // SubmissionType
  final Map<String, dynamic> data; // weights, measurements, image urls
  final String reviewStatus; // ReviewStatus
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // How many times the participant has resubmitted THIS slot (baseline, or a
  // given week's check-in). Used to cap resubmissions.
  final int resubmitCount;

  // Admin fields
  final String? lastUpdatedByAdminId;
  final String? adminReviewNotes;
  final Map<String, dynamic>? overrideFlags;

  ChallengeSubmission({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.type,
    required this.data,
    required this.reviewStatus,
    this.createdAt,
    this.updatedAt,
    this.resubmitCount = 0,
    this.lastUpdatedByAdminId,
    this.adminReviewNotes,
    this.overrideFlags,
  });

  ChallengeSubmission copyWith({
    String? id,
    String? challengeId,
    String? userId,
    String? type,
    Map<String, dynamic>? data,
    String? reviewStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? resubmitCount,
    String? lastUpdatedByAdminId,
    String? adminReviewNotes,
    Map<String, dynamic>? overrideFlags,
  }) {
    return ChallengeSubmission(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resubmitCount: resubmitCount ?? this.resubmitCount,
      lastUpdatedByAdminId: lastUpdatedByAdminId ?? this.lastUpdatedByAdminId,
      adminReviewNotes: adminReviewNotes ?? this.adminReviewNotes,
      overrideFlags: overrideFlags ?? this.overrideFlags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'userId': userId,
      'type': type,
      'data': data,
      'reviewStatus': reviewStatus,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'resubmitCount': resubmitCount,
      'lastUpdatedByAdminId': lastUpdatedByAdminId,
      'adminReviewNotes': adminReviewNotes,
      'overrideFlags': overrideFlags,
    };
  }

  factory ChallengeSubmission.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengeSubmission(
      id: documentId,
      challengeId: map['challengeId'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'baseline',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      reviewStatus: map['reviewStatus'] ?? 'submitted',
      createdAt: parseFirestoreDate(map['createdAt']),
      updatedAt: parseFirestoreDate(map['updatedAt']),
      resubmitCount: parseIntOr(map['resubmitCount'], 0),
      lastUpdatedByAdminId: map['lastUpdatedByAdminId'],
      adminReviewNotes: map['adminReviewNotes'],
      overrideFlags: map['overrideFlags'],
    );
  }

  factory ChallengeSubmission.fromFirestore(DocumentSnapshot doc) {
    return ChallengeSubmission.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
