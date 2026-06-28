import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeParticipant {
  final String id;
  final String challengeId;
  final String userId;
  final String status; // ParticipantStatus
  final String paymentStatus; // PaymentStatus
  final String? paymentMethod; // PaymentMethod
  final double amountDue;
  final double amountCollected;
  final String? currency;
  final String? paymentReference;
  final DateTime? paidAt;
  final String? paymentNotes;
  final String? verifiedByAdminId;
  final DateTime? paymentUpdatedAt;
  final String? latestPaymentRecordId;
  final String? paymentFailureReason;
  final DateTime? paymentFailedAt;
  final String? paymentFailedByAdminId;
  final String? paymentProofUrl;
  final DateTime? paymentProofSubmittedAt;
  final String? paymentProofNotes;
  final DateTime? paymentReviewedAt;
  final bool eligibleForPrizes;
  final bool disqualified;
  final String? disqualificationReason;
  final DateTime? disqualifiedAt;
  final String? disqualifiedByAdminId;
  final DateTime? reinstatedAt;
  final String? reinstatedByAdminId;
  final bool baselineSubmitted;
  final String? selectedPackageId;
  final String? selectedPackageName;
  final double? selectedPackagePrice;
  final String? selectedPackageCurrency;
  final List<Map<String, dynamic>>? selectedShopifyVariantsSnapshot;
  final DateTime? packageSelectedAt;
  final String? leaderboardDisplayName;
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
    this.paymentMethod,
    this.amountDue = 0.0,
    this.amountCollected = 0.0,
    this.currency,
    this.paymentReference,
    this.paidAt,
    this.paymentNotes,
    this.verifiedByAdminId,
    this.paymentUpdatedAt,
    this.latestPaymentRecordId,
    this.paymentFailureReason,
    this.paymentFailedAt,
    this.paymentFailedByAdminId,
    this.paymentProofUrl,
    this.paymentProofSubmittedAt,
    this.paymentProofNotes,
    this.paymentReviewedAt,
    this.eligibleForPrizes = false,
    this.disqualified = false,
    this.disqualificationReason,
    this.disqualifiedAt,
    this.disqualifiedByAdminId,
    this.reinstatedAt,
    this.reinstatedByAdminId,
    this.baselineSubmitted = false,
    this.selectedPackageId,
    this.selectedPackageName,
    this.selectedPackagePrice,
    this.selectedPackageCurrency,
    this.selectedShopifyVariantsSnapshot,
    this.packageSelectedAt,
    this.leaderboardDisplayName,
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
    String? paymentMethod,
    double? amountDue,
    double? amountCollected,
    String? currency,
    String? paymentReference,
    DateTime? paidAt,
    String? paymentNotes,
    String? verifiedByAdminId,
    DateTime? paymentUpdatedAt,
    String? latestPaymentRecordId,
    String? paymentFailureReason,
    DateTime? paymentFailedAt,
    String? paymentFailedByAdminId,
    String? paymentProofUrl,
    DateTime? paymentProofSubmittedAt,
    String? paymentProofNotes,
    DateTime? paymentReviewedAt,
    bool? eligibleForPrizes,
    bool? disqualified,
    String? disqualificationReason,
    DateTime? disqualifiedAt,
    String? disqualifiedByAdminId,
    DateTime? reinstatedAt,
    String? reinstatedByAdminId,
    bool? baselineSubmitted,
    String? selectedPackageId,
    String? selectedPackageName,
    double? selectedPackagePrice,
    String? selectedPackageCurrency,
    List<Map<String, dynamic>>? selectedShopifyVariantsSnapshot,
    DateTime? packageSelectedAt,
    String? leaderboardDisplayName,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountDue: amountDue ?? this.amountDue,
      amountCollected: amountCollected ?? this.amountCollected,
      currency: currency ?? this.currency,
      paymentReference: paymentReference ?? this.paymentReference,
      paidAt: paidAt ?? this.paidAt,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
      paymentUpdatedAt: paymentUpdatedAt ?? this.paymentUpdatedAt,
      latestPaymentRecordId: latestPaymentRecordId ?? this.latestPaymentRecordId,
      paymentFailureReason: paymentFailureReason ?? this.paymentFailureReason,
      paymentFailedAt: paymentFailedAt ?? this.paymentFailedAt,
      paymentFailedByAdminId: paymentFailedByAdminId ?? this.paymentFailedByAdminId,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentProofSubmittedAt: paymentProofSubmittedAt ?? this.paymentProofSubmittedAt,
      paymentProofNotes: paymentProofNotes ?? this.paymentProofNotes,
      paymentReviewedAt: paymentReviewedAt ?? this.paymentReviewedAt,
      eligibleForPrizes: eligibleForPrizes ?? this.eligibleForPrizes,
      disqualified: disqualified ?? this.disqualified,
      disqualificationReason: disqualificationReason ?? this.disqualificationReason,
      disqualifiedAt: disqualifiedAt ?? this.disqualifiedAt,
      disqualifiedByAdminId: disqualifiedByAdminId ?? this.disqualifiedByAdminId,
      reinstatedAt: reinstatedAt ?? this.reinstatedAt,
      reinstatedByAdminId: reinstatedByAdminId ?? this.reinstatedByAdminId,
      baselineSubmitted: baselineSubmitted ?? this.baselineSubmitted,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      selectedPackageName: selectedPackageName ?? this.selectedPackageName,
      selectedPackagePrice: selectedPackagePrice ?? this.selectedPackagePrice,
      selectedPackageCurrency: selectedPackageCurrency ?? this.selectedPackageCurrency,
      selectedShopifyVariantsSnapshot: selectedShopifyVariantsSnapshot ?? this.selectedShopifyVariantsSnapshot,
      packageSelectedAt: packageSelectedAt ?? this.packageSelectedAt,
      leaderboardDisplayName: leaderboardDisplayName ?? this.leaderboardDisplayName,
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
      'paymentMethod': paymentMethod,
      'amountDue': amountDue,
      'amountCollected': amountCollected,
      'currency': currency,
      'paymentReference': paymentReference,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paymentNotes': paymentNotes,
      'verifiedByAdminId': verifiedByAdminId,
      'paymentUpdatedAt': paymentUpdatedAt != null ? Timestamp.fromDate(paymentUpdatedAt!) : FieldValue.serverTimestamp(),
      'latestPaymentRecordId': latestPaymentRecordId,
      'paymentFailureReason': paymentFailureReason,
      'paymentFailedAt': paymentFailedAt != null ? Timestamp.fromDate(paymentFailedAt!) : null,
      'paymentFailedByAdminId': paymentFailedByAdminId,
      'paymentProofUrl': paymentProofUrl,
      'paymentProofSubmittedAt': paymentProofSubmittedAt != null ? Timestamp.fromDate(paymentProofSubmittedAt!) : null,
      'paymentProofNotes': paymentProofNotes,
      'paymentReviewedAt': paymentReviewedAt != null ? Timestamp.fromDate(paymentReviewedAt!) : null,
      'eligibleForPrizes': eligibleForPrizes,
      'disqualified': disqualified,
      'disqualificationReason': disqualificationReason,
      'disqualifiedAt': disqualifiedAt != null ? Timestamp.fromDate(disqualifiedAt!) : null,
      'disqualifiedByAdminId': disqualifiedByAdminId,
      'reinstatedAt': reinstatedAt != null ? Timestamp.fromDate(reinstatedAt!) : null,
      'reinstatedByAdminId': reinstatedByAdminId,
      'baselineSubmitted': baselineSubmitted,
      'selectedPackageId': selectedPackageId,
      'selectedPackageName': selectedPackageName,
      'selectedPackagePrice': selectedPackagePrice,
      'selectedPackageCurrency': selectedPackageCurrency,
      'selectedShopifyVariantsSnapshot': selectedShopifyVariantsSnapshot,
      'packageSelectedAt': packageSelectedAt != null ? Timestamp.fromDate(packageSelectedAt!) : null,
      'leaderboardDisplayName': leaderboardDisplayName,
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
      paymentMethod: map['paymentMethod'],
      amountDue: (map['amountDue'] as num?)?.toDouble() ?? 0.0,
      amountCollected: (map['amountCollected'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'],
      paymentReference: map['paymentReference'],
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      paymentNotes: map['paymentNotes'],
      verifiedByAdminId: map['verifiedByAdminId'],
      paymentUpdatedAt: (map['paymentUpdatedAt'] as Timestamp?)?.toDate(),
      latestPaymentRecordId: map['latestPaymentRecordId'],
      paymentFailureReason: map['paymentFailureReason'],
      paymentFailedAt: (map['paymentFailedAt'] as Timestamp?)?.toDate(),
      paymentFailedByAdminId: map['paymentFailedByAdminId'],
      paymentProofUrl: map['paymentProofUrl'],
      paymentProofSubmittedAt: (map['paymentProofSubmittedAt'] as Timestamp?)?.toDate(),
      paymentProofNotes: map['paymentProofNotes'],
      paymentReviewedAt: (map['paymentReviewedAt'] as Timestamp?)?.toDate(),
      eligibleForPrizes: map['eligibleForPrizes'] ?? false,
      disqualified: map['disqualified'] ?? false,
      disqualificationReason: map['disqualificationReason'],
      disqualifiedAt: (map['disqualifiedAt'] as Timestamp?)?.toDate(),
      disqualifiedByAdminId: map['disqualifiedByAdminId'],
      reinstatedAt: (map['reinstatedAt'] as Timestamp?)?.toDate(),
      reinstatedByAdminId: map['reinstatedByAdminId'],
      baselineSubmitted: map['baselineSubmitted'] ?? false,
      selectedPackageId: map['selectedPackageId'],
      selectedPackageName: map['selectedPackageName'],
      selectedPackagePrice: (map['selectedPackagePrice'] as num?)?.toDouble(),
      selectedPackageCurrency: map['selectedPackageCurrency'],
      selectedShopifyVariantsSnapshot: (map['selectedShopifyVariantsSnapshot'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      packageSelectedAt: (map['packageSelectedAt'] as Timestamp?)?.toDate(),
      leaderboardDisplayName: map['leaderboardDisplayName'],
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
