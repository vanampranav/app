import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_parsing.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final double registrationFee;
  final int maxParticipants;
  final String prizeDescription;
  final String rulesSummary;
  final bool baselineRequired;
  final bool finalPhotoRequired;
  final String status; // ChallengeStatus
  final List<String> rules;
  final List<String> prizeDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Admin fields
  final String createdByAdminId;
  final String? lastUpdatedByAdminId;
  final String? adminNotes;
  final Map<String, dynamic>? overrideFlags;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.registrationFee,
    required this.maxParticipants,
    required this.prizeDescription,
    required this.rulesSummary,
    this.baselineRequired = true,
    this.finalPhotoRequired = true,
    required this.status,
    this.rules = const [],
    this.prizeDetails = const [],
    this.createdAt,
    this.updatedAt,
    required this.createdByAdminId,
    this.lastUpdatedByAdminId,
    this.adminNotes,
    this.overrideFlags,
  });

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? registrationDeadline,
    double? registrationFee,
    int? maxParticipants,
    String? prizeDescription,
    String? rulesSummary,
    bool? baselineRequired,
    bool? finalPhotoRequired,
    String? status,
    List<String>? rules,
    List<String>? prizeDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByAdminId,
    String? lastUpdatedByAdminId,
    String? adminNotes,
    Map<String, dynamic>? overrideFlags,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      registrationFee: registrationFee ?? this.registrationFee,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      rulesSummary: rulesSummary ?? this.rulesSummary,
      baselineRequired: baselineRequired ?? this.baselineRequired,
      finalPhotoRequired: finalPhotoRequired ?? this.finalPhotoRequired,
      status: status ?? this.status,
      rules: rules ?? this.rules,
      prizeDetails: prizeDetails ?? this.prizeDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      lastUpdatedByAdminId: lastUpdatedByAdminId ?? this.lastUpdatedByAdminId,
      adminNotes: adminNotes ?? this.adminNotes,
      overrideFlags: overrideFlags ?? this.overrideFlags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'registrationFee': registrationFee,
      'maxParticipants': maxParticipants,
      'prizeDescription': prizeDescription,
      'rulesSummary': rulesSummary,
      'baselineRequired': baselineRequired,
      'finalPhotoRequired': finalPhotoRequired,
      'status': status,
      'rules': rules,
      'prizeDetails': prizeDetails,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByAdminId': createdByAdminId,
      'lastUpdatedByAdminId': lastUpdatedByAdminId,
      'adminNotes': adminNotes,
      'overrideFlags': overrideFlags,
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map, String documentId) {
    return Challenge(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startDate: parseFirestoreDateOr(map['startDate'], DateTime.now()),
      endDate: parseFirestoreDateOr(map['endDate'], DateTime.now()),
      registrationDeadline: parseFirestoreDate(map['registrationDeadline']) ?? parseFirestoreDateOr(map['startDate'], DateTime.now()),
      registrationFee: parseDoubleOr(map['registrationFee'], 0.0),
      maxParticipants: parseIntOr(map['maxParticipants'], 0),
      prizeDescription: map['prizeDescription'] ?? '',
      rulesSummary: map['rulesSummary'] ?? '',
      baselineRequired: map['baselineRequired'] ?? true,
      finalPhotoRequired: map['finalPhotoRequired'] ?? true,
      status: map['status'] ?? 'draft',
      rules: List<String>.from(map['rules'] ?? []),
      prizeDetails: List<String>.from(map['prizeDetails'] ?? []),
      createdAt: parseFirestoreDate(map['createdAt']),
      updatedAt: parseFirestoreDate(map['updatedAt']),
      createdByAdminId: map['createdByAdminId'] ?? '',
      lastUpdatedByAdminId: map['lastUpdatedByAdminId'],
      adminNotes: map['adminNotes'],
      overrideFlags: map['overrideFlags'],
    );
  }

  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    return Challenge.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
