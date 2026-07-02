import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_leaderboard_provider.dart';
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

class LeaderboardInsightsProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final UserRepository _userRepository;
  final ChallengeScoringService _scoringService = ChallengeScoringService();

  bool _isLoading = true;
  String? _errorMessage;
  ParticipantLeaderboardInsights? _insights;
  Challenge? _challenge;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ParticipantLeaderboardInsights? get insights => _insights;
  Challenge? get challenge => _challenge;

  StreamSubscription? _dataSub;

  LeaderboardInsightsProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeSubmissionRepository submissionRepository,
    required UserRepository userRepository,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository,
        _userRepository = userRepository {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();

    // Fetch challenge first
    _challengeRepository.getChallengeById(challengeId).then((c) {
      _challenge = c;
      _listenToData();
    });
  }

  void _listenToData() {
    // We combine participants and submissions to build the full context
    final participantsStream = _participantRepository.streamParticipantsByChallenge(challengeId);
    final submissionsStream = _submissionRepository.streamSubmissionsByChallenge(challengeId);

    _dataSub = participantsStream.listen((participants) async {
      final submissions = await submissionsStream.first;
      await _processData(participants, submissions);
    }, onError: (err) => _handleError(err.toString()));
  }

  Future<void> _processData(List<ChallengeParticipant> participants, List<ChallengeSubmission> submissions) async {
    try {
      final activeParticipants = participants.where((p) => p.status != ParticipantStatus.withdrawn).toList();
      final activeUserIds = activeParticipants.map((p) => p.userId).toList();

      if (activeUserIds.isEmpty) {
        _insights = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch user profiles for all active participants
      final users = await _userRepository.getUsersByIds(activeUserIds);
      final userMap = {for (var u in users) u.id: u};

      final approvedSubmissions = submissions
          .where((s) => s.reviewStatus == ReviewStatus.approved)
          .toList();

      Map<String, List<ChallengeSubmission>> userSubs = {};
      for (var s in approvedSubmissions) {
        if (activeUserIds.contains(s.userId)) {
          userSubs.putIfAbsent(s.userId, () => []).add(s);
        }
      }

      final bool isChallengeCompleted = _challenge?.status == ChallengeStatus.completed;

      // Build motivational leaderboard for all
      List<LeaderboardEntry> leaderboard = [];
      userSubs.forEach((uId, subs) {
        try {
          final participant = activeParticipants.firstWhere((p) => p.userId == uId);
          final baseline = subs.firstWhere((s) => s.type == SubmissionType.baseline);
          subs.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          final latest = subs.first;

          final double startW = (baseline.data['weight'] as num).toDouble();
          final double latestW = (latest.data['weight'] as num).toDouble();
          final double lostW = startW - latestW;
          final double pctW = _scoringService.calculateWeightLossPercent(startW, latestW);

          final double? startBF = baseline.data['bodyFat'] != null ? (baseline.data['bodyFat'] as num).toDouble() : null;
          final double? latestBF = latest.data['bodyFat'] != null ? (latest.data['bodyFat'] as num).toDouble() : null;
          final double lostBF = _scoringService.calculateBodyFatLossPoints(startBF, latestBF);

          final double consistency = _scoringService.calculateConsistencyScore(subs.length);
          final double mScore = _scoringService.calculateMotivationalLeaderboardScore(
            weightLossPercent: pctW,
            bodyFatLossPoints: lostBF,
            consistencyScore: consistency,
          );

          final offData = _scoringService.calculateOfficialWinnerScore(
            participant: participant,
            baseline: baseline,
            latestProgress: latest,
            isChallengeCompleted: isChallengeCompleted,
          );

          leaderboard.add(LeaderboardEntry(
            userId: uId,
            displayName: UserRepository.formatName(
              userMap[uId], 
              fallbackId: uId,
              leaderboardDisplayName: participant.leaderboardDisplayName,
            ),
            startingWeight: startW,
            latestWeight: latestW,
            weightLost: lostW,
            weightLossPercentage: pctW,
            bodyFatLossPoints: lostBF,
            latestSubmissionType: latest.type,
            lastUpdated: latest.createdAt ?? DateTime.now(),
            motivationalScore: mScore,
            officialData: offData,
          ));
        } catch (_) {}
      });

      // Sort by motivational score descending
      leaderboard.sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));

      // Current user context
      if (!userSubs.containsKey(userId)) {
        _insights = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final mySubs = userSubs[userId]!;
      mySubs.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));

      final baseline = mySubs.firstWhere((s) => s.type == SubmissionType.baseline);
      final latest = mySubs.last;

      final double baselineWeight = (baseline.data['weight'] as num).toDouble();
      final double? baselineBodyFat = baseline.data['bodyFat'] != null ? (baseline.data['bodyFat'] as num).toDouble() : null;
      
      final double currentWeight = (latest.data['weight'] as num).toDouble();
      final double? currentBodyFat = latest.data['bodyFat'] != null ? (latest.data['bodyFat'] as num).toDouble() : null;

      final weightLossKg = baselineWeight - currentWeight;
      final weightLossPercent = _scoringService.calculateWeightLossPercent(baselineWeight, currentWeight);
      final bodyFatLoss = _scoringService.calculateBodyFatLossPoints(baselineBodyFat, currentBodyFat);

      final rankIndex = leaderboard.indexWhere((e) => e.userId == userId);
      final currentRank = rankIndex + 1;

      final myEntry = leaderboard[rankIndex];

      double? rankAboveGap;
      if (rankIndex > 0) {
        rankAboveGap = leaderboard[rankIndex - 1].motivationalScore - myEntry.motivationalScore;
      }

      double? rankBelowLead;
      if (rankIndex >= 0 && rankIndex < leaderboard.length - 1) {
        rankBelowLead = myEntry.motivationalScore - leaderboard[rankIndex + 1].motivationalScore;
      }

      // Build progress points
      List<ProgressPoint> progressPoints = mySubs.map((s) {
        String label = 'Baseline';
        if (s.type == SubmissionType.weeklyCheckIn) {
          label = 'Week ${s.data['weekNumber']}';
        } else if (s.type == SubmissionType.finalSubmission) {
          label = 'Final';
        }
        
        return ProgressPoint(
          label: label,
          weekNumber: s.data['weekNumber'],
          weightKg: (s.data['weight'] as num).toDouble(),
          bodyFatPercent: s.data['bodyFat'] != null ? (s.data['bodyFat'] as num).toDouble() : null,
          submittedAt: s.createdAt ?? DateTime.now(),
          submissionType: s.type,
        );
      }).toList();

      final double consistency = _scoringService.calculateConsistencyScore(mySubs.length);
      final double fatLossContribution = bodyFatLoss * 10;
      final double weightLossContribution = weightLossPercent * 5;
      final double totalMScore = fatLossContribution + weightLossContribution + (consistency / 10);

      _insights = ParticipantLeaderboardInsights(
        participantId: userId,
        currentRank: currentRank,
        totalApprovedParticipants: leaderboard.length,
        currentMotivationalScore: totalMScore,
        baselineWeightKg: baselineWeight,
        currentWeightKg: currentWeight,
        weightLossKg: weightLossKg,
        weightLossPercent: weightLossPercent,
        baselineBodyFatPercent: baselineBodyFat,
        currentBodyFatPercent: currentBodyFat,
        bodyFatLossPoints: bodyFatLoss,
        rankAboveGap: rankAboveGap,
        rankBelowLead: rankBelowLead,
        progressPoints: progressPoints,
        scoreBreakdown: ScoreBreakdown(
          fatLossScore: fatLossContribution,
          weightLossScore: weightLossContribution,
          consistencyScore: consistency,
          totalLeaderboardScore: totalMScore,
        ),
        officialData: myEntry.officialData,
        isProjectedOfficialRanking: !isChallengeCompleted,
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
    _dataSub?.cancel();
    super.dispose();
  }
}
