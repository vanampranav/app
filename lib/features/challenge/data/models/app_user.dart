import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final List<String> enrolledChallengeIds;
  final bool isAdmin;
  final String role; // user, admin, superAdmin
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Admin fields
  final String? createdByAdminId;
  final String? lastUpdatedByAdminId;
  final String? adminNotes;
  final Map<String, dynamic>? adminMetaData;

  AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    this.enrolledChallengeIds = const [],
    this.isAdmin = false,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
    this.createdByAdminId,
    this.lastUpdatedByAdminId,
    this.adminNotes,
    this.adminMetaData,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
    List<String>? enrolledChallengeIds,
    bool? isAdmin,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByAdminId,
    String? lastUpdatedByAdminId,
    String? adminNotes,
    Map<String, dynamic>? adminMetaData,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      enrolledChallengeIds: enrolledChallengeIds ?? this.enrolledChallengeIds,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      lastUpdatedByAdminId: lastUpdatedByAdminId ?? this.lastUpdatedByAdminId,
      adminNotes: adminNotes ?? this.adminNotes,
      adminMetaData: adminMetaData ?? this.adminMetaData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'enrolledChallengeIds': enrolledChallengeIds,
      'isAdmin': isAdmin,
      'role': role,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdByAdminId': createdByAdminId,
      'lastUpdatedByAdminId': lastUpdatedByAdminId,
      'adminNotes': adminNotes,
      'adminMetaData': adminMetaData,
    };
  }

  /// Parses a date that may be stored as a Firestore Timestamp (SDK-written
  /// docs), an ISO-8601 String (REST-written docs, e.g. the AI Coach/profile
  /// flow), epoch millis, or a DateTime. Returns null on anything unparseable.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] ?? '',
      firstName: map['firstName'],
      lastName: map['lastName'],
      phoneNumber: map['phoneNumber'],
      profileImageUrl: map['profileImageUrl'],
      enrolledChallengeIds: List<String>.from(map['enrolledChallengeIds'] ?? []),
      isAdmin: map['isAdmin'] ?? false,
      role: (map['role'] ?? 'user').toString().trim(),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      createdByAdminId: map['createdByAdminId'],
      lastUpdatedByAdminId: map['lastUpdatedByAdminId'],
      adminNotes: map['adminNotes'],
      adminMetaData: map['adminMetaData'],
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
