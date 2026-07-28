import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

/// A single leaderboard row for the UI. Built from the sanitized
/// [LeaderboardStanding] — it carries NO absolute weights (those are private
/// and not shown on the participant leaderboard).
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final double weightLossPercentage;
  final double bodyFatLossPoints;
  final String latestSubmissionType; // display label, e.g. "Week 3"
  final DateTime lastUpdated;
  final double motivationalScore;
  final OfficialWinnerData officialData;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.weightLossPercentage,
    required this.bodyFatLossPoints,
    required this.latestSubmissionType,
    required this.lastUpdated,
    required this.motivationalScore,
    required this.officialData,
  });

  factory LeaderboardEntry.fromStanding(LeaderboardStanding s) {
    return LeaderboardEntry(
      userId: s.userId,
      displayName: s.displayName,
      weightLossPercentage: s.weightLossPercent,
      bodyFatLossPoints: s.bodyFatLossPoints,
      latestSubmissionType: s.latestSubmissionLabel,
      lastUpdated: s.lastUpdated ?? DateTime.now(),
      motivationalScore: s.motivationalScore,
      officialData: OfficialWinnerData(
        score: s.officialScore,
        metric: s.officialMetric,
        isEligible: s.officialEligible,
        ineligibilityReason: s.officialIneligibilityReason,
      ),
    );
  }
}

/// Reads the PUBLIC leaderboard snapshot (`challenges/{id}/leaderboard`) that an
/// admin-context recompute publishes. Participants have read-only access, so
/// this no longer triggers the permission-denied error the old raw-data reads
/// caused.
class ParticipantLeaderboardProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeRepository _challengeRepository;
  final LeaderboardRepository _leaderboardRepository;

  Challenge? _challenge;
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _challengeSub;
  StreamSubscription? _leaderboardSub;

  Challenge? get challenge => _challenge;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ParticipantLeaderboardProvider({
    required this.challengeId,
    required ChallengeRepository challengeRepository,
    required LeaderboardRepository leaderboardRepository,
  })  : _challengeRepository = challengeRepository,
        _leaderboardRepository = leaderboardRepository {
    _init();
  }

  void _init() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _challengeSub =
        _challengeRepository.streamChallengeById(challengeId).listen((data) {
      _challenge = data;
      notifyListeners();
    });

    _leaderboardSub =
        _leaderboardRepository.streamStandings(challengeId).listen((standings) {
      final entries =
          standings.map(LeaderboardEntry.fromStanding).toList()
            ..sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));
      _leaderboard = entries;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _challengeSub?.cancel();
    _leaderboardSub?.cancel();
    super.dispose();
  }
}
