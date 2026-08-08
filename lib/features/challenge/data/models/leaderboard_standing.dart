import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_parsing.dart';

/// A PUBLIC-SAFE leaderboard row, stored at
/// `challenges/{challengeId}/leaderboard/{userId}`.
///
/// This is the ONLY challenge data a non-admin participant reads to render the
/// leaderboard. It deliberately contains NO absolute weights, body-fat photos,
/// or payment/eligibility fields — only the derived competition metrics that a
/// leaderboard is meant to show. It is written server-side (by an admin-context
/// recompute); participants have read-only access via security rules.
class LeaderboardStanding {
  final String userId;
  final String displayName;
  final double motivationalScore; // includes bonusPoints below
  final double weightLossPercent;
  final double bodyFatLossPoints;
  final double consistencyScore;
  final double bonusPoints; // admin manual adjustment folded into motivationalScore
  final String latestSubmissionType; // raw: baseline | weeklyCheckIn | finalSubmission
  final String latestSubmissionLabel; // display: "Week 3" / "Final" / "Baseline"
  final int? latestWeekNumber;
  final DateTime? lastUpdated;

  // Official winner metric (sanitized snapshot of OfficialWinnerData).
  final double? officialScore;
  final String officialMetric;
  final bool officialEligible;
  final String? officialIneligibilityReason;

  // Normalized components of the composite official score (relative % changes).
  final double bodyFatChangePercent;
  final double muscleGainPercent;

  final DateTime? updatedAt;

  LeaderboardStanding({
    required this.userId,
    required this.displayName,
    required this.motivationalScore,
    required this.weightLossPercent,
    required this.bodyFatLossPoints,
    required this.consistencyScore,
    this.bonusPoints = 0,
    required this.latestSubmissionType,
    required this.latestSubmissionLabel,
    this.latestWeekNumber,
    this.lastUpdated,
    this.officialScore,
    this.officialMetric = 'insufficientData',
    this.officialEligible = false,
    this.officialIneligibilityReason,
    this.bodyFatChangePercent = 0,
    this.muscleGainPercent = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'motivationalScore': motivationalScore,
      'weightLossPercent': weightLossPercent,
      'bodyFatLossPoints': bodyFatLossPoints,
      'consistencyScore': consistencyScore,
      'bonusPoints': bonusPoints,
      'latestSubmissionType': latestSubmissionType,
      'latestSubmissionLabel': latestSubmissionLabel,
      'latestWeekNumber': latestWeekNumber,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'officialScore': officialScore,
      'officialMetric': officialMetric,
      'officialEligible': officialEligible,
      'officialIneligibilityReason': officialIneligibilityReason,
      'bodyFatChangePercent': bodyFatChangePercent,
      'muscleGainPercent': muscleGainPercent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory LeaderboardStanding.fromMap(Map<String, dynamic> map, String documentId) {
    return LeaderboardStanding(
      userId: (map['userId'] ?? documentId).toString(),
      displayName: (map['displayName'] ?? 'Participant').toString(),
      motivationalScore: parseDoubleOr(map['motivationalScore'], 0),
      weightLossPercent: parseDoubleOr(map['weightLossPercent'], 0),
      bodyFatLossPoints: parseDoubleOr(map['bodyFatLossPoints'], 0),
      consistencyScore: parseDoubleOr(map['consistencyScore'], 0),
      bonusPoints: parseDoubleOr(map['bonusPoints'], 0),
      latestSubmissionType: (map['latestSubmissionType'] ?? 'baseline').toString(),
      latestSubmissionLabel: (map['latestSubmissionLabel'] ?? 'Baseline').toString(),
      latestWeekNumber: map['latestWeekNumber'] == null
          ? null
          : parseIntOr(map['latestWeekNumber'], 0),
      lastUpdated: parseFirestoreDate(map['lastUpdated']),
      officialScore:
          map['officialScore'] == null ? null : parseDoubleOr(map['officialScore'], 0),
      officialMetric: (map['officialMetric'] ?? 'insufficientData').toString(),
      officialEligible: map['officialEligible'] == true,
      officialIneligibilityReason: map['officialIneligibilityReason']?.toString(),
      bodyFatChangePercent: parseDoubleOr(map['bodyFatChangePercent'], 0),
      muscleGainPercent: parseDoubleOr(map['muscleGainPercent'], 0),
      updatedAt: parseFirestoreDate(map['updatedAt']),
    );
  }

  factory LeaderboardStanding.fromFirestore(DocumentSnapshot doc) {
    return LeaderboardStanding.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
