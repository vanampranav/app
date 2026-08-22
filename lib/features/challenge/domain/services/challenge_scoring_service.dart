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

/// A participant's ACCUMULATED challenge points, plus their best transformation
/// so far (baseline → best value per measurement) for display.
class AccumulatedScore {
  final double points; // accumulated performance points — never negative
  final double bodyFatChangePercent; // baseline → best body fat (display only)
  final double weightLossPercent; // baseline → best weight (display only)
  final double muscleGainPercent; // baseline → best muscle (display only)

  const AccumulatedScore({
    this.points = 0,
    this.bodyFatChangePercent = 0,
    this.weightLossPercent = 0,
    this.muscleGainPercent = 0,
  });
}

/// One check-in's point award, for the "+X points" reveal after approval (§16).
class CheckinAward {
  final String submissionId;
  final double points; // points earned by THIS check-in
  final double runningTotal; // accumulated total after this check-in
  // Change since the PREVIOUS check-in (or baseline for the first). Negative
  // weight / body-fat = lost (good); positive muscle = gained (good). Null when
  // that measurement is missing on either side.
  final double? weightDelta;
  final double? bodyFatDelta;
  final double? muscleDelta;

  const CheckinAward({
    required this.submissionId,
    required this.points,
    required this.runningTotal,
    this.weightDelta,
    this.bodyFatDelta,
    this.muscleDelta,
  });
}

/// Parses a possibly-String Firestore numeric field without throwing (REST /
/// AI-Coach docs sometimes store numbers as Strings, so a hard `as num` cast
/// would crash the scoring pass).
double? _asNum(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

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

  /// The weighted weekly improvement is multiplied by this to make larger, more
  /// motivating leaderboard numbers (per the recommended model).
  static const double pointsScale = 10.0;

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

  /// A participant's ACCUMULATED challenge points.
  ///
  /// Points are earned at every approved check-in for genuine improvement and
  /// ADDED to a running total — a great week is banked, and a poor week awards 0
  /// but never subtracts (so scores never go down or negative). To stop a
  /// participant farming the same transformation by yo-yoing, improvement is
  /// measured **beyond their best-so-far** for each measurement: returning to an
  /// already-achieved best earns nothing; only beating a personal best earns new
  /// points.
  ///
  /// weekly = (bodyFat% × 0.5) + (weight% × 0.3) + (muscle% × 0.2), each a
  /// relative % improvement past that measurement's previous best; the week's
  /// points = max(0, weekly) × 10, summed across all approved check-ins.
  ///
  /// Pure: pass ONLY approved, non-baseline submissions.
  AccumulatedScore calculateAccumulatedPoints({
    required ChallengeSubmission baseline,
    required List<ChallengeSubmission> approvedProgress,
  }) {
    final double? baseWt = _asNum(baseline.data['weight']);
    final double? baseBF = _asNum(baseline.data['bodyFat']);
    final double? baseMus = _asNum(baseline.data['muscleMass']);

    // Running personal bests (lower weight / body fat is better; higher muscle).
    double? bestWt = baseWt;
    double? bestBF = baseBF;
    double? bestMus = baseMus;

    // Replay check-ins in chronological order.
    final ordered = [...approvedProgress]
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    double total = 0;
    for (final s in ordered) {
      final double? wt = _asNum(s.data['weight']);
      final double? bf = _asNum(s.data['bodyFat']);
      final double? mus = _asNum(s.data['muscleMass']);

      final double wImp =
          (bestWt != null && bestWt > 0 && wt != null && wt < bestWt)
              ? (bestWt - wt) / bestWt * 100
              : 0;
      final double bfImp =
          (bestBF != null && bestBF > 0 && bf != null && bf < bestBF)
              ? (bestBF - bf) / bestBF * 100
              : 0;
      final double musImp =
          (bestMus != null && bestMus > 0 && mus != null && mus > bestMus)
              ? (mus - bestMus) / bestMus * 100
              : 0;

      final double weekly = calculateCompositeScore(
        bodyFatChangePercent: bfImp,
        weightLossPercent: wImp,
        muscleGainPercent: musImp,
      );
      if (weekly > 0) total += weekly * pointsScale;

      // Advance the personal bests.
      if (wt != null && (bestWt == null || wt < bestWt)) bestWt = wt;
      if (bf != null && (bestBF == null || bf < bestBF)) bestBF = bf;
      if (mus != null && (bestMus == null || mus > bestMus)) bestMus = mus;
    }

    // Display = total transformation so far (baseline → best per measurement).
    final double dispBf = (baseBF != null && bestBF != null && baseBF > 0)
        ? (baseBF - bestBF) / baseBF * 100
        : 0;
    final double dispWt = (baseWt != null && bestWt != null && baseWt > 0)
        ? (baseWt - bestWt) / baseWt * 100
        : 0;
    final double dispMus = (baseMus != null && bestMus != null && baseMus > 0)
        ? (bestMus - baseMus) / baseMus * 100
        : 0;

    return AccumulatedScore(
      points: total,
      bodyFatChangePercent: dispBf,
      weightLossPercent: dispWt,
      muscleGainPercent: dispMus,
    );
  }

  /// Per-check-in awards, chronological — the SAME points model as
  /// [calculateAccumulatedPoints], broken out so the app can show a participant
  /// exactly how much a given check-in earned (§16), plus the change since their
  /// previous check-in. Pass ONLY approved, non-baseline submissions.
  List<CheckinAward> calculateCheckinAwards({
    required ChallengeSubmission baseline,
    required List<ChallengeSubmission> approvedProgress,
  }) {
    double? bestWt = _asNum(baseline.data['weight']);
    double? bestBF = _asNum(baseline.data['bodyFat']);
    double? bestMus = _asNum(baseline.data['muscleMass']);
    // Previous check-in values (for the raw delta) — start at the baseline.
    double? prevWt = bestWt, prevBF = bestBF, prevMus = bestMus;

    final ordered = [...approvedProgress]
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    double total = 0;
    final awards = <CheckinAward>[];
    for (final s in ordered) {
      final double? wt = _asNum(s.data['weight']);
      final double? bf = _asNum(s.data['bodyFat']);
      final double? mus = _asNum(s.data['muscleMass']);

      final double wImp =
          (bestWt != null && bestWt > 0 && wt != null && wt < bestWt)
              ? (bestWt - wt) / bestWt * 100 : 0;
      final double bfImp =
          (bestBF != null && bestBF > 0 && bf != null && bf < bestBF)
              ? (bestBF - bf) / bestBF * 100 : 0;
      final double musImp =
          (bestMus != null && bestMus > 0 && mus != null && mus > bestMus)
              ? (mus - bestMus) / bestMus * 100 : 0;
      final double weekly = calculateCompositeScore(
        bodyFatChangePercent: bfImp, weightLossPercent: wImp, muscleGainPercent: musImp);
      final double points = weekly > 0 ? weekly * pointsScale : 0;
      total += points;

      awards.add(CheckinAward(
        submissionId: s.id,
        points: points,
        runningTotal: total,
        weightDelta: (wt != null && prevWt != null) ? wt - prevWt : null,
        bodyFatDelta: (bf != null && prevBF != null) ? bf - prevBF : null,
        muscleDelta: (mus != null && prevMus != null) ? mus - prevMus : null,
      ));

      if (wt != null && (bestWt == null || wt < bestWt)) bestWt = wt;
      if (bf != null && (bestBF == null || bf < bestBF)) bestBF = bf;
      if (mus != null && (bestMus == null || mus > bestMus)) bestMus = mus;
      if (wt != null) prevWt = wt;
      if (bf != null) prevBF = bf;
      if (mus != null) prevMus = mus;
    }
    return awards;
  }

  /// Calculates the Official Winner Score = the participant's ACCUMULATED points
  /// (see [calculateAccumulatedPoints]). Once the challenge is COMPLETED, an
  /// approved FINAL submission is required to be prize-eligible.
  OfficialWinnerData calculateOfficialWinnerScore({
    required ChallengeParticipant participant,
    required ChallengeSubmission? baseline,
    required List<ChallengeSubmission> approvedProgress,
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

    // Consider only APPROVED, non-baseline submissions.
    final approved = approvedProgress
        .where((s) =>
            s.reviewStatus == ReviewStatus.approved &&
            s.type != SubmissionType.baseline)
        .toList();

    if (approved.isEmpty) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: "No approved progress data available yet.",
      );
    }

    // Winning requires an approved FINAL once the challenge has closed — even if
    // the peak score comes from an earlier week.
    if (isChallengeCompleted &&
        !approved.any((s) => s.type == SubmissionType.finalSubmission)) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: "Approved final submission is required for prize ranking.",
      );
    }

    // Weight is a required field, so a non-positive baseline weight means the
    // measurement data is unusable — nothing to normalize against.
    final double bWeight = _asNum(baseline.data['weight']) ?? 0;
    if (bWeight <= 0) {
      return OfficialWinnerData(
        metric: "insufficientData",
        isEligible: false,
        ineligibilityReason: "Required measurement data is missing or invalid.",
      );
    }

    final acc = calculateAccumulatedPoints(
        baseline: baseline, approvedProgress: approved);

    return OfficialWinnerData(
      score: acc.points,
      metric: "compositeScore",
      isEligible: true,
      bodyFatChangePercent: acc.bodyFatChangePercent,
      weightLossPercent: acc.weightLossPercent,
      muscleGainPercent: acc.muscleGainPercent,
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
