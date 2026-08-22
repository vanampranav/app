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

  /// Sets an admin bonus/penalty (manual points) on a participant and republishes
  /// the leaderboard so their rank updates. Adjusts an EXISTING participant only —
  /// it can never create a winner from a non-participant.
  Future<void> setBonusPoints(
    String challengeId,
    String userId,
    double bonusPoints, {
    String? adminId,
  }) async {
    final participant = await _participantRepository
        .getParticipantByUserAndChallenge(userId, challengeId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }
    final meta = Map<String, dynamic>.from(participant.adminMetaData ?? {});
    meta['bonusPoints'] = bonusPoints;
    await _participantRepository.updateParticipant(participant.copyWith(
      adminMetaData: meta,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    ));
    await recomputeAndPublish(challengeId);
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

        // "Last updated" label + timestamp come from the most recent activity.
        subs.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        final latest = subs.first;

        // ACCUMULATED POINTS: points are earned at every approved check-in for
        // improvement beyond the participant's best, added to a running total
        // (never negative). The leaderboard ranks by this SAME score that
        // decides winners.
        final approvedProgress =
            subs.where((s) => s.type != SubmissionType.baseline).toList();
        final acc = _scoring.calculateAccumulatedPoints(
            baseline: baseline, approvedProgress: approvedProgress);

        // Absolute body-fat points lost to best (display only).
        final double? startBF = baseline.data['bodyFat'] is num
            ? (baseline.data['bodyFat'] as num).toDouble()
            : null;
        final double lostBF = (startBF ?? 0) * acc.bodyFatChangePercent / 100;

        // Consistency counts DISTINCT weeks with an approved check-in (kept as an
        // informational stat — it no longer affects the score).
        final int distinctWeeklyWeeks = subs
            .where((s) => s.type == SubmissionType.weeklyCheckIn)
            .map((s) => s.data['weekNumber'])
            .where((w) => w != null)
            .toSet()
            .length;
        final double consistency =
            _scoring.calculateConsistencyScore(distinctWeeklyWeeks);

        final official = _scoring.calculateOfficialWinnerScore(
          participant: participant,
          baseline: baseline,
          approvedProgress: approvedProgress,
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
          // Accumulated points + the admin's manual bonus/penalty (so a bonus
          // lifts the participant on the same scale that decides winners).
          motivationalScore: acc.points + participant.bonusPoints,
          bonusPoints: participant.bonusPoints,
          weightLossPercent: acc.weightLossPercent,
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
          bodyFatChangePercent: acc.bodyFatChangePercent,
          muscleGainPercent: acc.muscleGainPercent,
        ));
      } catch (_) {
        // Skip participants without an approved baseline / malformed data.
      }
    });

    // Include participants who have joined but don't yet have a scored entry
    // (no approved submission, or no approved baseline) so the leaderboard shows
    // EVERY challenger — not just those already scored. They appear at the
    // bottom as "Not started".
    final scoredUserIds = standings.map((s) => s.userId).toSet();
    for (final p in activeParticipants) {
      if (scoredUserIds.contains(p.userId)) continue;
      standings.add(LeaderboardStanding(
        userId: p.userId,
        displayName: UserRepository.formatName(
          userMap[p.userId],
          fallbackId: p.userId,
          leaderboardDisplayName: p.leaderboardDisplayName,
        ),
        motivationalScore: p.bonusPoints,
        bonusPoints: p.bonusPoints,
        weightLossPercent: 0,
        bodyFatLossPoints: 0,
        consistencyScore: 0,
        latestSubmissionType: 'baseline',
        latestSubmissionLabel: 'Not started',
        officialMetric: 'insufficientData',
        officialEligible: false,
      ));
    }

    // Rank by score (which now includes the admin bonus, so a bonus can lift
    // anyone). On ties, scored participants sit above "Not started", then by name.
    standings.sort((a, b) {
      final byScore = b.motivationalScore.compareTo(a.motivationalScore);
      if (byScore != 0) return byScore;
      final aScored = scoredUserIds.contains(a.userId);
      final bScored = scoredUserIds.contains(b.userId);
      if (aScored != bScored) return aScored ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return standings;
  }
}
