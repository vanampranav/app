import 'package:flutter/foundation.dart';

import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

/// Computes the sanitized public leaderboard from raw participant + submission
/// data and publishes it to `challenges/{id}/leaderboard`.
///
/// This runs in an ADMIN context (reads of all participants/submissions require
/// admin per security rules, and writing the leaderboard is admin-only). It is
/// triggered whenever scores can change — i.e. an admin approves/rejects a
/// submission or removes a participant. Participants then read the published
/// snapshot and never touch the raw private data.
class LeaderboardService {
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final UserRepository _userRepository;
  final LeaderboardRepository _leaderboardRepository;
  final ChallengeScoringService _scoring = ChallengeScoringService();

  LeaderboardService({
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeSubmissionRepository submissionRepository,
    required UserRepository userRepository,
    required LeaderboardRepository leaderboardRepository,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository,
        _userRepository = userRepository,
        _leaderboardRepository = leaderboardRepository;

  /// Best-effort: recompute + publish. Never throws to its caller — a failed
  /// leaderboard refresh must not fail the admin action that triggered it.
  Future<void> recomputeAndPublish(String challengeId) async {
    try {
      final challenge =
          await _challengeRepository.getChallengeById(challengeId);
      final participants = await _participantRepository
          .streamParticipantsByChallenge(challengeId)
          .first;
      final submissions = await _submissionRepository
          .streamSubmissionsByChallenge(challengeId)
          .first;

      final activeUserIds = participants
          .where((p) => p.status != ParticipantStatus.withdrawn)
          .map((p) => p.userId)
          .toList();
      // Display names are best-effort: if the user lookup fails, still publish
      // standings using each participant's nickname / fallback id.
      List<dynamic> users = [];
      try {
        if (activeUserIds.isNotEmpty) {
          users = await _userRepository.getUsersByIds(activeUserIds);
        }
      } catch (_) {
        users = [];
      }

      final standings =
          computeStandings(challenge, participants, submissions, users);
      await _leaderboardRepository.publishStandings(challengeId, standings);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LeaderboardService: recompute failed (non-fatal): $e');
      }
    }
  }

  /// Pure computation, shared with the admin live view / tests. `users` is a
  /// list of AppUser (typed dynamic here only to avoid importing the model in
  /// callers); [UserRepository.formatName] handles the lookup.
  List<LeaderboardStanding> computeStandings(
    Challenge? challenge,
    List<ChallengeParticipant> participants,
    List<ChallengeSubmission> submissions,
    List<dynamic> users,
  ) {
    final activeParticipants = participants
        .where((p) => p.status != ParticipantStatus.withdrawn)
        .toList();
    final activeUserIds = activeParticipants.map((p) => p.userId).toSet();
    if (activeUserIds.isEmpty) return [];

    final userMap = {for (var u in users) u.id: u};

    final approved = submissions
        .where((s) => s.reviewStatus == ReviewStatus.approved)
        .toList();

    final Map<String, List<ChallengeSubmission>> userSubs = {};
    for (final s in approved) {
      if (activeUserIds.contains(s.userId)) {
        userSubs.putIfAbsent(s.userId, () => []).add(s);
      }
    }

    final bool isCompleted = challenge?.status == ChallengeStatus.completed;
    final List<LeaderboardStanding> standings = [];

    userSubs.forEach((userId, subs) {
      try {
        final participant =
            activeParticipants.firstWhere((p) => p.userId == userId);
        final baseline =
            subs.firstWhere((s) => s.type == SubmissionType.baseline);

        subs.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        final latest = subs.first;

        final double startW = (baseline.data['weight'] as num).toDouble();
        final double latestW = (latest.data['weight'] as num).toDouble();
        final double pctW = _scoring.calculateWeightLossPercent(startW, latestW);

        final double? startBF = baseline.data['bodyFat'] != null
            ? (baseline.data['bodyFat'] as num).toDouble()
            : null;
        final double? latestBF = latest.data['bodyFat'] != null
            ? (latest.data['bodyFat'] as num).toDouble()
            : null;
        final double lostBF =
            _scoring.calculateBodyFatLossPoints(startBF, latestBF);

        final double consistency =
            _scoring.calculateConsistencyScore(subs.length);
        final double motivational =
            _scoring.calculateMotivationalLeaderboardScore(
          weightLossPercent: pctW,
          bodyFatLossPoints: lostBF,
          consistencyScore: consistency,
        );

        final official = _scoring.calculateOfficialWinnerScore(
          participant: participant,
          baseline: baseline,
          latestProgress: latest,
          isChallengeCompleted: isCompleted,
        );

        String label = 'Baseline';
        int? weekNo;
        if (latest.type == SubmissionType.weeklyCheckIn) {
          weekNo = latest.data['weekNumber'] is num
              ? (latest.data['weekNumber'] as num).toInt()
              : null;
          label = 'Week ${weekNo ?? ''}'.trim();
        } else if (latest.type == SubmissionType.finalSubmission) {
          label = 'Final';
        }

        final displayName = UserRepository.formatName(
          userMap[userId],
          fallbackId: userId,
          leaderboardDisplayName: participant.leaderboardDisplayName,
        );

        standings.add(LeaderboardStanding(
          userId: userId,
          displayName: displayName,
          motivationalScore: motivational,
          weightLossPercent: pctW,
          bodyFatLossPoints: lostBF,
          consistencyScore: consistency,
          latestSubmissionType: latest.type,
          latestSubmissionLabel: label,
          latestWeekNumber: weekNo,
          lastUpdated: latest.createdAt,
          officialScore: official.score,
          officialMetric: official.metric,
          officialEligible: official.isEligible,
          officialIneligibilityReason: official.ineligibilityReason,
        ));
      } catch (_) {
        // Skip participants without an approved baseline / malformed data.
      }
    });

    standings.sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));
    return standings;
  }
}
