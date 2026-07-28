import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

class ProgressPoint {
  final String label;
  final int? weekNumber;
  final double weightKg;
  final double? bodyFatPercent;
  final DateTime submittedAt;
  final String submissionType;

  ProgressPoint({
    required this.label,
    this.weekNumber,
    required this.weightKg,
    this.bodyFatPercent,
    required this.submittedAt,
    required this.submissionType,
  });
}

class ScoreBreakdown {
  final double fatLossScore;
  final double weightLossScore;
  final double consistencyScore;
  final double totalLeaderboardScore;

  ScoreBreakdown({
    required this.fatLossScore,
    required this.weightLossScore,
    required this.consistencyScore,
    required this.totalLeaderboardScore,
  });
}

class ParticipantLeaderboardInsights {
  final String participantId;
  final int currentRank;
  final int totalApprovedParticipants;
  final double currentMotivationalScore;
  final double baselineWeightKg;
  final double currentWeightKg;
  final double weightLossKg;
  final double weightLossPercent;
  final double? baselineBodyFatPercent;
  final double? currentBodyFatPercent;
  final double? bodyFatLossPoints;
  final double? rankAboveGap;
  final double? rankBelowLead;
  final List<ProgressPoint> progressPoints;
  final ScoreBreakdown scoreBreakdown;
  final OfficialWinnerData officialData;
  final bool isProjectedOfficialRanking;

  ParticipantLeaderboardInsights({
    required this.participantId,
    required this.currentRank,
    required this.totalApprovedParticipants,
    required this.currentMotivationalScore,
    required this.baselineWeightKg,
    required this.currentWeightKg,
    required this.weightLossKg,
    required this.weightLossPercent,
    this.baselineBodyFatPercent,
    this.currentBodyFatPercent,
    this.bodyFatLossPoints,
    this.rankAboveGap,
    this.rankBelowLead,
    required this.progressPoints,
    required this.scoreBreakdown,
    required this.officialData,
    required this.isProjectedOfficialRanking,
  });
}

/// The current user's own leaderboard insights.
///
/// Ranking context (rank, total, gaps, others' scores, the user's own official
/// metric) comes from the PUBLIC sanitized standings — no permission-denied.
/// The private progress chart + absolute weights come from the user's OWN
/// submissions, which security rules let them read.
class LeaderboardInsightsProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final LeaderboardRepository _leaderboardRepository;

  bool _isLoading = true;
  String? _errorMessage;
  ParticipantLeaderboardInsights? _insights;
  Challenge? _challenge;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ParticipantLeaderboardInsights? get insights => _insights;
  Challenge? get challenge => _challenge;

  StreamSubscription? _standingsSub;

  LeaderboardInsightsProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeSubmissionRepository submissionRepository,
    required LeaderboardRepository leaderboardRepository,
  })  : _challengeRepository = challengeRepository,
        _submissionRepository = submissionRepository,
        _leaderboardRepository = leaderboardRepository {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();

    _challengeRepository.getChallengeById(challengeId).then((c) {
      _challenge = c;
      _standingsSub = _leaderboardRepository
          .streamStandings(challengeId)
          .listen((standings) async {
        await _process(standings);
      }, onError: (err) => _handleError(err.toString()));
    });
  }

  Future<void> _process(List<LeaderboardStanding> standings) async {
    try {
      final ranked = [...standings]
        ..sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));

      final rankIndex = ranked.indexWhere((s) => s.userId == userId);
      if (rankIndex < 0) {
        // Not on the leaderboard yet (no approved baseline).
        _insights = null;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      final myStanding = ranked[rankIndex];
      final currentRank = rankIndex + 1;

      double? rankAboveGap;
      if (rankIndex > 0) {
        rankAboveGap =
            ranked[rankIndex - 1].motivationalScore - myStanding.motivationalScore;
      }
      double? rankBelowLead;
      if (rankIndex < ranked.length - 1) {
        rankBelowLead =
            myStanding.motivationalScore - ranked[rankIndex + 1].motivationalScore;
      }

      // Private data — the user's OWN approved submissions for this challenge.
      final ownSubs = await _submissionRepository
          .streamSubmissionsByParticipantAndChallenge(userId, challengeId)
          .first;
      final approved = ownSubs
          .where((s) => s.reviewStatus == ReviewStatus.approved)
          .toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));

      double baselineWeight = 0, currentWeight = 0, weightLossKg = 0;
      double? baselineBodyFat, currentBodyFat;
      List<ProgressPoint> progressPoints = [];

      if (approved.isNotEmpty) {
        final baseline = approved.firstWhere(
          (s) => s.type == SubmissionType.baseline,
          orElse: () => approved.first,
        );
        final latest = approved.last;

        baselineWeight = (baseline.data['weight'] as num?)?.toDouble() ?? 0;
        currentWeight = (latest.data['weight'] as num?)?.toDouble() ?? 0;
        weightLossKg = baselineWeight - currentWeight;
        baselineBodyFat = baseline.data['bodyFat'] != null
            ? (baseline.data['bodyFat'] as num).toDouble()
            : null;
        currentBodyFat = latest.data['bodyFat'] != null
            ? (latest.data['bodyFat'] as num).toDouble()
            : null;

        progressPoints = approved.map((s) {
          String label = 'Baseline';
          if (s.type == SubmissionType.weeklyCheckIn) {
            label = 'Week ${s.data['weekNumber']}';
          } else if (s.type == SubmissionType.finalSubmission) {
            label = 'Final';
          }
          return ProgressPoint(
            label: label,
            weekNumber: s.data['weekNumber'] is num
                ? (s.data['weekNumber'] as num).toInt()
                : null,
            weightKg: (s.data['weight'] as num?)?.toDouble() ?? 0,
            bodyFatPercent: s.data['bodyFat'] != null
                ? (s.data['bodyFat'] as num).toDouble()
                : null,
            submittedAt: s.createdAt ?? DateTime.now(),
            submissionType: s.type,
          );
        }).toList();
      }

      // Score components come from the sanitized standing (already computed the
      // same way), so the breakdown matches the ranking exactly.
      final double fatLossContribution = myStanding.bodyFatLossPoints * 10;
      final double weightLossContribution = myStanding.weightLossPercent * 5;

      final bool isCompleted = _challenge?.status == ChallengeStatus.completed;

      _insights = ParticipantLeaderboardInsights(
        participantId: userId,
        currentRank: currentRank,
        totalApprovedParticipants: ranked.length,
        currentMotivationalScore: myStanding.motivationalScore,
        baselineWeightKg: baselineWeight,
        currentWeightKg: currentWeight,
        weightLossKg: weightLossKg,
        weightLossPercent: myStanding.weightLossPercent,
        baselineBodyFatPercent: baselineBodyFat,
        currentBodyFatPercent: currentBodyFat,
        bodyFatLossPoints: myStanding.bodyFatLossPoints,
        rankAboveGap: rankAboveGap,
        rankBelowLead: rankBelowLead,
        progressPoints: progressPoints,
        scoreBreakdown: ScoreBreakdown(
          fatLossScore: fatLossContribution,
          weightLossScore: weightLossContribution,
          consistencyScore: myStanding.consistencyScore,
          totalLeaderboardScore: myStanding.motivationalScore,
        ),
        officialData: OfficialWinnerData(
          score: myStanding.officialScore,
          metric: myStanding.officialMetric,
          isEligible: myStanding.officialEligible,
          ineligibilityReason: myStanding.officialIneligibilityReason,
        ),
        isProjectedOfficialRanking: !isCompleted,
      );

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String msg) {
    _errorMessage = msg;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _standingsSub?.cancel();
    super.dispose();
  }
}
