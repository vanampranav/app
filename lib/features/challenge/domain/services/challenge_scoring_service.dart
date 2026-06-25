import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class OfficialWinnerData {
  final double? score;
  final String metric; // "bodyFatLossPoints", "weightLossPercent", "insufficientData"
  final bool isEligible;
  final String? ineligibilityReason;

  OfficialWinnerData({
    this.score,
    required this.metric,
    required this.isEligible,
    this.ineligibilityReason,
  });
}

class ChallengeScoringService {
  /// Calculates the Motivational Leaderboard Score.
  /// Used for engagement and weekly motivation.
  /// Formula: (bodyFatLossPoints * 10) + (weightLossPercent * 5) + (consistencyScore / 10)
  double calculateMotivationalLeaderboardScore({
    required double weightLossPercent,
    required double bodyFatLossPoints,
    required double consistencyScore,
  }) {
    return (bodyFatLossPoints * 10) + (weightLossPercent * 5) + (consistencyScore / 10);
  }

  /// Calculates the Official Winner Score.
  /// Used for final prize ranking.
  /// Primary: Body Fat Loss Points. Fallback: Weight Loss Percent.
  OfficialWinnerData calculateOfficialWinnerScore({
    required ChallengeParticipant participant,
    required ChallengeSubmission? baseline,
    required ChallengeSubmission? latestProgress, // Could be latest weekly or final
    required bool isChallengeCompleted,
  }) {
    // 1. Eligibility Checks
    if (participant.status == ParticipantStatus.disqualified) {
      return OfficialWinnerData(
        metric: "disqualified",
        isEligible: false,
        ineligibilityReason: "Participant is disqualified from the challenge.",
      );
    }

    if (baseline == null || baseline.reviewStatus != ReviewStatus.approved) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: "Approved baseline measurements are required for prize eligibility.",
      );
    }

    // Determine if we have progress data
    if (latestProgress == null || latestProgress.reviewStatus != ReviewStatus.approved) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: isChallengeCompleted 
            ? "Approved final submission is required for prize ranking."
            : "No approved progress data available yet.",
      );
    }

    // 2. Data Extraction
    final double bWeight = (baseline.data['weight'] as num).toDouble();
    final double? bFat = baseline.data['bodyFat'] != null ? (baseline.data['bodyFat'] as num).toDouble() : null;

    final double pWeight = (latestProgress.data['weight'] as num).toDouble();
    final double? pFat = latestProgress.data['bodyFat'] != null ? (latestProgress.data['bodyFat'] as num).toDouble() : null;

    // 3. Calculation Logic
    if (bFat != null && pFat != null) {
      final fatLoss = bFat - pFat;
      return OfficialWinnerData(
        score: fatLoss,
        metric: "bodyFatLossPoints",
        isEligible: true,
      );
    } else if (bWeight > 0) {
      final weightLossPercent = ((bWeight - pWeight) / bWeight) * 100;
      return OfficialWinnerData(
        score: weightLossPercent,
        metric: "weightLossPercent",
        isEligible: true,
        ineligibilityReason: "Body fat measurements missing; using weight loss percentage as fallback.",
      );
    }

    return OfficialWinnerData(
      metric: "insufficientData",
      isEligible: false,
      ineligibilityReason: "Required measurement data is missing or invalid.",
    );
  }

  double calculateWeightLossPercent(double baselineWeight, double currentWeight) {
    if (baselineWeight <= 0) return 0.0;
    return ((baselineWeight - currentWeight) / baselineWeight) * 100;
  }

  double calculateBodyFatLossPoints(double? baselineBF, double? currentBF) {
    if (baselineBF == null || currentBF == null) return 0.0;
    return baselineBF - currentBF;
  }

  /// Calculates consistency based on number of approved submissions relative to expected.
  /// Simple MVP version: 5 check-ins = 100%
  double calculateConsistencyScore(int approvedSubmissionsCount) {
    return (approvedSubmissionsCount / 5.0) * 100;
  }
}
