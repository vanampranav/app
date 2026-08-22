import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_winner.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_notification_service.dart';
import 'package:elefit_app/features/challenge/domain/services/leaderboard_service.dart';

/// The result of ranking a challenge for winner selection.
class WinnerRanking {
  /// Prize-eligible finalists, ordered by the weighted composite Participant
  /// Score descending (50% body-fat % change, 30% weight loss %, 20% muscle gain %).
  final List<LeaderboardStanding> ranked;

  /// Everyone else on the leaderboard, with a reason they are not rankable.
  final List<LeaderboardStanding> ineligible;

  WinnerRanking({required this.ranked, required this.ineligible});
}

/// Ranks eligible finalists and publishes the admin-declared winners.
///
/// Ranking is automatic (by the weighted composite Participant Score) but the
/// admin makes the final call — [computeRanking] proposes an order;
/// [declareWinners] persists whatever the admin confirms.
class WinnerSelectionService {
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final LeaderboardRepository _leaderboardRepository;
  final LeaderboardService _leaderboardService;
  final AdminAuditService _auditService;
  final ChallengeNotificationService _notificationService;

  WinnerSelectionService({
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required LeaderboardRepository leaderboardRepository,
    required LeaderboardService leaderboardService,
    required AdminAuditService auditService,
    required ChallengeNotificationService notificationService,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _leaderboardRepository = leaderboardRepository,
        _leaderboardService = leaderboardService,
        _auditService = auditService,
        _notificationService = notificationService;

  /// The score that ranks a finalist: the composite official score PLUS the
  /// admin's manual bonus/penalty, so "Adjust Standings" actually influences who
  /// wins (matching the public leaderboard order).
  static double _rankScore(LeaderboardStanding s) =>
      (s.officialScore ?? 0) + s.bonusPoints;

  /// Refreshes the leaderboard from source data, then proposes a ranking.
  Future<WinnerRanking> computeRanking(String challengeId) async {
    // Make sure the standings reflect the latest approved submissions.
    await _leaderboardService.recomputeAndPublish(challengeId);
    final standings = await _leaderboardRepository.getStandings(challengeId);

    final eligible = standings.where((s) => s.officialEligible).toList()
      ..sort((a, b) => _rankScore(b).compareTo(_rankScore(a)));

    final ineligible =
        standings.where((s) => !s.officialEligible).toList();

    return WinnerRanking(ranked: eligible, ineligible: ineligible);
  }

  /// Persists the admin's chosen winners on the challenge, stamps each winner's
  /// participant record, audits, and notifies. Idempotent — re-declaring
  /// overwrites the previous result and clears stale placements.
  Future<void> declareWinners(
    String challengeId,
    String adminId,
    List<ChallengeWinner> winners,
  ) async {
    final challenge = await _challengeRepository.getChallengeById(challengeId);
    if (challenge == null) {
      throw Exception('Challenge not found.');
    }
    if (challenge.status != ChallengeStatus.completed) {
      throw Exception(
          'Winners can only be declared for a completed challenge. Close the challenge first.');
    }

    final updated = challenge.copyWith(
      winners: winners,
      resultsPublished: true,
      resultsPublishedAt: DateTime.now(),
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );
    await _challengeRepository.updateChallenge(updated);

    // Stamp / clear participant placements so "You placed Nth" stays correct.
    final winnerById = {for (final w in winners) w.userId: w};
    final participants = await _participantRepository
        .streamParticipantsByChallenge(challengeId)
        .first;

    for (final p in participants) {
      final w = winnerById[p.userId];
      if (w != null) {
        await _participantRepository.updateParticipant(p.copyWith(
          // Podium winners get a placement number; special-award winners get
          // only a label (null placement, so "You placed 0th" never shows).
          finalPlacement: w.isSpecialAward ? null : w.place,
          clearPlacement: w.isSpecialAward,
          awardLabel: w.awardLabel,
          updatedAt: DateTime.now(),
        ));
      } else if (p.finalPlacement != null || p.awardLabel != null) {
        await _participantRepository.updateParticipant(p.copyWith(
          clearPlacement: true,
          clearAward: true,
          updatedAt: DateTime.now(),
        ));
      }
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: challengeId,
      action: 'declare_winners',
      targetCollection: FirestoreCollections.challenges,
      targetId: challengeId,
      previousData: challenge.toMap(),
      newData: updated.toMap(),
    );

    // Notifications (best-effort; a failure must not roll back the result).
    try {
      for (final w in winners) {
        await _notificationService.createChallengeNotification(
          recipientUserId: w.userId,
          challengeId: challengeId,
          title: '🏆 Congratulations!',
          body: 'You won ${w.awardLabel} in "${challenge.title}".',
          type: 'resultsPublished',
          priority: 'high',
          deepLink: 'leaderboard',
          adminId: adminId,
        );
      }
      final winnerIds = winnerById.keys.toSet();
      for (final p in participants) {
        if (winnerIds.contains(p.userId)) continue;
        if (p.status == ParticipantStatus.withdrawn) continue;
        await _notificationService.createChallengeNotification(
          recipientUserId: p.userId,
          challengeId: challengeId,
          title: 'Results are in',
          body:
              'Winners have been announced for "${challenge.title}". See the leaderboard.',
          type: 'resultsPublished',
          deepLink: 'leaderboard',
          adminId: adminId,
        );
      }
    } catch (_) {
      // swallow — results are already persisted.
    }
  }
}
