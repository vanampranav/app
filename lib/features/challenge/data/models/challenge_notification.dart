import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeNotification {
  final String id;
  final String recipientUserId;
  final String? challengeId;
  final String title;
  final String body;
  final String type; // challengeJoined, paymentApproved, submissionApproved, submissionRejected, resubmissionRequested, weeklyCheckInOpen, weeklyCheckInDue, system
  final String category; // challenge, payment, achievement, system
  final String priority; // low, normal, high
  final Map<String, dynamic>? data; 
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String? deepLink;

  // Admin fields
  final String? createdByAdminId;

  ChallengeNotification({
    required this.id,
    required this.recipientUserId,
    this.challengeId,
    required this.title,
    required this.body,
    required this.type,
    this.category = 'challenge',
    this.priority = 'normal',
    this.data,
    this.isRead = false,
    this.readAt,
    this.createdAt,
    this.deepLink,
    this.createdByAdminId,
  });

  ChallengeNotification copyWith({
    String? id,
    String? recipientUserId,
    String? challengeId,
    String? title,
    String? body,
    String? type,
    String? category,
    String? priority,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    String? deepLink,
    String? createdByAdminId,
  }) {
    return ChallengeNotification(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      challengeId: challengeId ?? this.challengeId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      deepLink: deepLink ?? this.deepLink,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientUserId': recipientUserId,
      'challengeId': challengeId,
      'title': title,
      'body': body,
      'type': type,
      'category': category,
      'priority': priority,
      'data': data,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'deepLink': deepLink,
      'createdByAdminId': createdByAdminId,
    };
  }

  factory ChallengeNotification.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengeNotification(
      id: documentId,
      recipientUserId: map['recipientUserId'] ?? '',
      challengeId: map['challengeId'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      category: map['category'] ?? 'challenge',
      priority: map['priority'] ?? 'normal',
      data: map['data'],
      isRead: map['isRead'] ?? false,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      deepLink: map['deepLink'],
      createdByAdminId: map['createdByAdminId'],
    );
  }

  factory ChallengeNotification.fromFirestore(DocumentSnapshot doc) {
    return ChallengeNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
