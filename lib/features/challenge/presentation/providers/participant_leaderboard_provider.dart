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
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final double startingWeight;
  final double latestWeight;
  final double weightLost;
  final double weightLossPercentage;
  final double bodyFatLossPoints;
  final String latestSubmissionType;
  final DateTime lastUpdated;
  final double motivationalScore;
  final OfficialWinnerData officialData;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.startingWeight,
    required this.latestWeight,
    required this.weightLost,
    required this.weightLossPercentage,
    required this.bodyFatLossPoints,
    required this.latestSubmissionType,
    required this.lastUpdated,
    required this.motivationalScore,
    required this.officialData,
  });
}

class ParticipantLeaderboardProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final UserRepository _userRepository;
  final ChallengeScoringService _scoringService = ChallengeScoringService();

  Challenge? _challenge;
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _challengeSub;
  StreamSubscription? _participantSub;
  StreamSubscription? _submissionSub;

  Challenge? get challenge => _challenge;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ParticipantLeaderboardProvider({
    required this.challengeId,
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
    _errorMessage = null;
    notifyListeners();

    _challengeSub = _challengeRepository.streamChallengeById(challengeId).listen((data) {
      _challenge = data;
      notifyListeners();
    });

    // We need both participants and submissions to build the leaderboard
    // Listening to both and recalculating when either changes
    _listenToData();
  }

  void _listenToData() {
    Stream<List<ChallengeParticipant>> participantsStream = 
        _participantRepository.streamParticipantsByChallenge(challengeId);
    
    Stream<List<ChallengeSubmission>> submissionsStream = 
        _submissionRepository.streamSubmissionsByChallenge(challengeId);

    // Combine streams to rebuild leaderboard
    _participantSub = participantsStream.listen((participants) async {
      final submissions = await submissionsStream.first;
      await _buildLeaderboard(participants, submissions);
    }, onError: (err) => _handleError(err.toString()));

    _submissionSub = submissionsStream.listen((submissions) async {
      final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;
      await _buildLeaderboard(participants, submissions);
    }, onError: (err) => _handleError(err.toString()));
  }

  Future<void> _buildLeaderboard(List<ChallengeParticipant> participants, List<ChallengeSubmission> submissions) async {
    try {
      final activeParticipants = participants
          .where((p) => p.status != ParticipantStatus.withdrawn)
          .toList();
      final activeUserIds = activeParticipants.map((p) => p.userId).toList();

      if (activeUserIds.isEmpty) {
        _leaderboard = [];
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

      List<LeaderboardEntry> entries = [];
      final bool isChallengeCompleted = _challenge?.status == ChallengeStatus.completed;

      userSubs.forEach((userId, subs) {
        try {
          final participant = activeParticipants.firstWhere((p) => p.userId == userId);
          final baseline = subs.firstWhere((s) => s.type == SubmissionType.baseline);
          
          // Sort subs by date to find latest
          subs.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          final latest = subs.first;

          final double startW = (baseline.data['weight'] as num).toDouble();
          final double latestW = (latest.data['weight'] as num).toDouble();
          final double lostW = startW - latestW;
          final double pctW = _scoringService.calculateWeightLossPercent(startW, latestW);

          final double? startBF = baseline.data['bodyFat'] != null ? (baseline.data['bodyFat'] as num).toDouble() : null;
          final double? latestBF = latest.data['bodyFat'] != null ? (latest.data['bodyFat'] as num).toDouble() : null;
          final double lostBF = _scoringService.calculateBodyFatLossPoints(startBF, latestBF);

          // 1. Motivational Score
          final double consistency = _scoringService.calculateConsistencyScore(subs.length);
          final double motivationalScore = _scoringService.calculateMotivationalLeaderboardScore(
            weightLossPercent: pctW,
            bodyFatLossPoints: lostBF,
            consistencyScore: consistency,
          );

          // 2. Official Winner Score
          final officialData = _scoringService.calculateOfficialWinnerScore(
            participant: participant,
            baseline: baseline,
            latestProgress: latest,
            isChallengeCompleted: isChallengeCompleted,
          );

          String latestLabel = latest.type;
          if (latest.type == SubmissionType.weeklyCheckIn) {
            latestLabel = 'Week ${latest.data['weekNumber']}';
          } else if (latest.type == SubmissionType.finalSubmission) {
            latestLabel = 'Final';
          } else {
            latestLabel = 'Baseline';
          }

          // Privacy: format name
          final userProfile = userMap[userId];
          final String displayName = UserRepository.formatName(
            userProfile, 
            fallbackId: userId,
            leaderboardDisplayName: participant.leaderboardDisplayName,
          );

          entries.add(LeaderboardEntry(
            userId: userId,
            displayName: displayName,
            startingWeight: startW,
            latestWeight: latestW,
            weightLost: lostW,
            weightLossPercentage: pctW,
            bodyFatLossPoints: lostBF,
            latestSubmissionType: latestLabel,
            lastUpdated: latest.createdAt ?? DateTime.now(),
            motivationalScore: motivationalScore,
            officialData: officialData,
          ));
        } catch (_) {
          // Skip users without baseline or participants matching issues
        }
      });

      // Sort by motivational score descending for primary view
      entries.sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));
      
      _leaderboard = entries;
      _isLoading = false;
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
    _challengeSub?.cancel();
    _submissionSub?.cancel();
    _participantSub?.cancel();
    super.dispose();
  }
}
