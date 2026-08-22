import 'package:flutter/material.dart';
import 'dispose_guard_notifier.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_winner.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/winner_selection_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/challenge_error_text.dart';

/// The admin's editable choice for one candidate: a podium place (1/2/3),
/// an optional special-award label, and an optional prize note.
class WinnerDraft {
  int place; // 0 = not a podium winner
  String specialAward; // non-empty => a special award regardless of place
  String prizeNote;
  WinnerDraft({this.place = 0, this.specialAward = '', this.prizeNote = ''});

  bool get isSelected => place > 0 || specialAward.trim().isNotEmpty;
}

class AdminWinnerSelectionProvider with ChangeNotifier, DisposeGuardNotifier {
  final String challengeId;
  final String adminId;
  final WinnerSelectionService _service;
  final ChallengeRepository _challengeRepository;

  AdminWinnerSelectionProvider({
    required this.challengeId,
    required this.adminId,
    required WinnerSelectionService service,
    required ChallengeRepository challengeRepository,
  })  : _service = service,
        _challengeRepository = challengeRepository {
    load();
  }

  bool _isLoading = true;
  bool _isPublishing = false;
  String? _error;
  Challenge? _challenge;
  List<LeaderboardStanding> _ranked = [];
  List<LeaderboardStanding> _ineligible = [];
  final Map<String, WinnerDraft> _drafts = {}; // userId -> draft

  bool get isLoading => _isLoading;
  bool get isPublishing => _isPublishing;
  String? get error => _error;
  Challenge? get challenge => _challenge;
  List<LeaderboardStanding> get ranked => _ranked;
  List<LeaderboardStanding> get ineligible => _ineligible;
  bool get isCompleted => _challenge?.status == 'completed';
  bool get resultsPublished => _challenge?.resultsPublished ?? false;

  WinnerDraft draftFor(String userId) =>
      _drafts.putIfAbsent(userId, () => WinnerDraft());

  int get selectedCount => _drafts.values.where((d) => d.isSelected).length;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _challenge = await _challengeRepository.getChallengeById(challengeId);
      final ranking = await _service.computeRanking(challengeId);
      _ranked = ranking.ranked;
      _ineligible = ranking.ineligible;

      // Pre-fill the podium with the auto-ranked top 3 (admin can override).
      _drafts.clear();
      for (var i = 0; i < _ranked.length && i < 3; i++) {
        _drafts[_ranked[i].userId] = WinnerDraft(place: i + 1);
      }
    } catch (e) {
      _error = friendlyChallengeError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPlace(String userId, int place) {
    // A place can only belong to one candidate — clear it from any other.
    if (place > 0) {
      for (final entry in _drafts.entries) {
        if (entry.key != userId && entry.value.place == place) {
          entry.value.place = 0;
        }
      }
    }
    draftFor(userId).place = place;
    notifyListeners();
  }

  void setSpecialAward(String userId, String label) {
    draftFor(userId).specialAward = label;
    notifyListeners();
  }

  void setPrizeNote(String userId, String note) {
    draftFor(userId).prizeNote = note;
  }

  /// Builds the winners list from the drafts and publishes it.
  Future<bool> publish() async {
    _isPublishing = true;
    _error = null;
    notifyListeners();
    try {
      final byId = {for (final s in _ranked) s.userId: s};
      final winners = <ChallengeWinner>[];
      _drafts.forEach((userId, d) {
        if (!d.isSelected) return;
        final s = byId[userId];
        final special = d.specialAward.trim();
        winners.add(ChallengeWinner(
          userId: userId,
          displayName: s?.displayName ?? 'Participant',
          place: special.isNotEmpty ? 0 : d.place,
          awardLabel: special.isNotEmpty ? special : _placeLabel(d.place),
          metric: s?.officialMetric ?? 'special',
          score: s?.officialScore,
          prizeNote: d.prizeNote.trim().isEmpty ? null : d.prizeNote.trim(),
        ));
      });

      await _service.declareWinners(challengeId, adminId, winners);
      _challenge = await _challengeRepository.getChallengeById(challengeId);
      return true;
    } catch (e) {
      _error = friendlyChallengeError(e);
      return false;
    } finally {
      _isPublishing = false;
      notifyListeners();
    }
  }

  static String _placeLabel(int place) {
    switch (place) {
      case 1:
        return '1st Place';
      case 2:
        return '2nd Place';
      case 3:
        return '3rd Place';
      default:
        return 'Winner';
    }
  }
}
