import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class LeaderboardEntry {
  final String userId;
  final double startingWeight;
  final double latestWeight;
  final double weightLost;
  final double weightLossPercentage;
  final String latestSubmissionType;
  final DateTime lastUpdated;

  LeaderboardEntry({
    required this.userId,
    required this.startingWeight,
    required this.latestWeight,
    required this.weightLost,
    required this.weightLossPercentage,
    required this.latestSubmissionType,
    required this.lastUpdated,
  });
}

class ParticipantLeaderboardProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;

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
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository {
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
    _participantSub = participantsStream.listen((participants) {
      submissionsStream.first.then((submissions) {
        _buildLeaderboard(participants, submissions);
      });
    }, onError: (err) => _handleError(err.toString()));

    _submissionSub = submissionsStream.listen((submissions) {
      _participantRepository.streamParticipantsByChallenge(challengeId).first.then((participants) {
        _buildLeaderboard(participants, submissions);
      });
    }, onError: (err) => _handleError(err.toString()));
  }

  void _buildLeaderboard(List<ChallengeParticipant> participants, List<ChallengeSubmission> submissions) {
    try {
      final activeUserIds = participants
          .where((p) => p.status == ParticipantStatus.active)
          .map((p) => p.userId)
          .toSet();

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

      userSubs.forEach((userId, subs) {
        try {
          final baseline = subs.firstWhere((s) => s.type == SubmissionType.baseline);
          
          // Sort subs by date to find latest
          subs.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          final latest = subs.first;

          final double startW = (baseline.data['weight'] as num).toDouble();
          final double latestW = (latest.data['weight'] as num).toDouble();
          final double lost = startW - latestW;
          final double pct = startW > 0 ? (lost / startW) * 100 : 0.0;

          String latestLabel = latest.type;
          if (latest.type == SubmissionType.weeklyCheckIn) {
            latestLabel = 'Week ${latest.data['weekNumber']}';
          } else if (latest.type == SubmissionType.finalSubmission) {
            latestLabel = 'Final';
          } else {
            latestLabel = 'Baseline';
          }

          entries.add(LeaderboardEntry(
            userId: userId,
            startingWeight: startW,
            latestWeight: latestW,
            weightLost: lost,
            weightLossPercentage: pct,
            latestSubmissionType: latestLabel,
            lastUpdated: latest.createdAt ?? DateTime.now(),
          ));
        } catch (_) {
          // Skip users without baseline
        }
      });

      // Sort by weight loss percentage descending
      entries.sort((a, b) => b.weightLossPercentage.compareTo(a.weightLossPercentage));
      
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
