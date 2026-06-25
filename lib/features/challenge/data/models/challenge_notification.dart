import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeNotification {
  final String id;
  final String recipientUserId;
  final String title;
  final String body;
  final String type; // system, challenge_update, payment_reminder
  final Map<String, dynamic>? data; // e.g. challengeId
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  // Admin fields
  final String? createdByAdminId;

  ChallengeNotification({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    this.readAt,
    this.createdAt,
    this.createdByAdminId,
  });

  ChallengeNotification copyWith({
    String? id,
    String? recipientUserId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    String? createdByAdminId,
  }) {
    return ChallengeNotification(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientUserId': recipientUserId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdByAdminId': createdByAdminId,
    };
  }

  factory ChallengeNotification.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengeNotification(
      id: documentId,
      recipientUserId: map['recipientUserId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      data: map['data'],
      isRead: map['isRead'] ?? false,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdByAdminId: map['createdByAdminId'],
    );
  }

  factory ChallengeNotification.fromFirestore(DocumentSnapshot doc) {
    return ChallengeNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
