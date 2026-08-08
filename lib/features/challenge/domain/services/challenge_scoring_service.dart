import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class OfficialWinnerData {
  final double? score;
  final String metric; // "compositeScore", "insufficientData", "disqualified", ...
  final bool isEligible;
  final String? ineligibilityReason;

  // Normalized component contributions that make up the composite score
  // (each is a relative % change; see ChallengeScoringService for the weights).
  final double bodyFatChangePercent; // (startBF - endBF)/startBF * 100
  final double weightLossPercent; // (startWt - endWt)/startWt * 100
  final double muscleGainPercent; // (endMuscle - startMuscle)/startMuscle * 100

  OfficialWinnerData({
    this.score,
    required this.metric,
    required this.isEligible,
    this.ineligibilityReason,
    this.bodyFatChangePercent = 0,
    this.weightLossPercent = 0,
    this.muscleGainPercent = 0,
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

  /// The weighted Participant Score used to decide winners.
  ///
  /// Winners are determined by normalized progress across three areas:
  ///   • Body Fat % Change  (50%)  = (StartBF − EndBF) / StartBF × 100
  ///   • Weight Loss        (30%)  = (StartWt − EndWt) / StartWt × 100
  ///   • Muscle Gain        (20%)  = (EndMuscle − StartMuscle) / StartMuscle × 100
  /// Final = (BF% × 0.5) + (WeightLoss% × 0.3) + (MuscleGain% × 0.2)
  static const double bodyFatWeight = 0.5;
  static const double weightLossWeight = 0.3;
  static const double muscleGainWeight = 0.2;

  double calculateCompositeScore({
    required double bodyFatChangePercent,
    required double weightLossPercent,
    required double muscleGainPercent,
  }) {
    return (bodyFatChangePercent * bodyFatWeight) +
        (weightLossPercent * weightLossWeight) +
        (muscleGainPercent * muscleGainWeight);
  }

  /// Relative % body-fat change (positive = fat lost). Guards start ≤ 0.
  double calculateBodyFatChangePercent(double? startBF, double? endBF) {
    if (startBF == null || endBF == null || startBF <= 0) return 0.0;
    return ((startBF - endBF) / startBF) * 100;
  }

  /// Relative % muscle gain (positive = muscle gained). Guards start ≤ 0.
  double calculateMuscleGainPercent(double? startMuscle, double? endMuscle) {
    if (startMuscle == null || endMuscle == null || startMuscle <= 0) return 0.0;
    return ((endMuscle - startMuscle) / startMuscle) * 100;
  }

  /// Calculates the Official Winner Score (the weighted composite above).
  /// Used for final prize ranking. Start = approved baseline, End = latest
  /// approved progress (the final submission once the challenge completes).
  OfficialWinnerData calculateOfficialWinnerScore({
    required ChallengeParticipant participant,
    required ChallengeSubmission? baseline,
    required ChallengeSubmission? latestProgress, // Could be latest weekly or final
    required bool isChallengeCompleted,
  }) {
    // 1. Eligibility Checks
    if (participant.status == ParticipantStatus.disqualified || participant.disqualified) {
      return OfficialWinnerData(
        metric: "disqualified",
        isEligible: false,
        ineligibilityReason: "Participant is disqualified from the challenge.",
      );
    }

    if (!participant.eligibleForPrizes) {
      return OfficialWinnerData(
        metric: "paymentPending",
        isEligible: false,
        ineligibilityReason: "Payment must be verified for prize eligibility.",
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

    // 2. Data Extraction (null-safe — never crash on missing/invalid values)
    final double? bWeightN = (baseline.data['weight'] as num?)?.toDouble();
    final double? bFat = (baseline.data['bodyFat'] as num?)?.toDouble();
    final double? bMuscle = (baseline.data['muscleMass'] as num?)?.toDouble();

    final double? pWeightN = (latestProgress.data['weight'] as num?)?.toDouble();
    final double? pFat = (latestProgress.data['bodyFat'] as num?)?.toDouble();
    final double? pMuscle = (latestProgress.data['muscleMass'] as num?)?.toDouble();

    final double bWeight = bWeightN ?? 0;

    // Weight is a required field, so a non-positive baseline weight means the
    // measurement data is unusable — nothing to normalize against.
    if (bWeight <= 0) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: "Required measurement data is missing or invalid.",
      );
    }

    // 3. Weighted composite score (each component is a relative % change; a
    // missing body-fat / muscle pair contributes 0 for that component).
    final double bfPercent = calculateBodyFatChangePercent(bFat, pFat);
    final double weightPercent = calculateWeightLossPercent(bWeight, pWeightN ?? 0);
    final double musclePercent = calculateMuscleGainPercent(bMuscle, pMuscle);

    final double composite = calculateCompositeScore(
      bodyFatChangePercent: bfPercent,
      weightLossPercent: weightPercent,
      muscleGainPercent: musclePercent,
    );

    return OfficialWinnerData(
      score: composite,
      metric: "compositeScore",
      isEligible: true,
      bodyFatChangePercent: bfPercent,
      weightLossPercent: weightPercent,
      muscleGainPercent: musclePercent,
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
