import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'challenge_error_text.dart';

class ParticipantViewModel {
  final ChallengeParticipant participant;
  final String displayName;

  ParticipantViewModel({
    required this.participant,
    required this.displayName,
  });
}

class AdminParticipantsProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeParticipantRepository _participantRepository;
  final UserRepository _userRepository;
  final ParticipantEnrollmentService _enrollmentService;

  List<ParticipantViewModel> _allParticipants = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<ParticipantViewModel> get participants {
    if (_currentFilter == 'All') return _allParticipants;
    if (_currentFilter == 'Pending') {
      return _allParticipants.where((p) => p.participant.status == 'joined' || p.participant.status == 'invited').toList();
    }
    if (_currentFilter == 'Approved') {
      return _allParticipants.where((p) => p.participant.status == 'active').toList();
    }
    if (_currentFilter == 'Rejected') {
      return _allParticipants.where((p) => p.participant.status == 'disqualified' || p.participant.status == 'withdrawn').toList();
    }
    return _allParticipants;
  }

  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  AdminParticipantsProvider({
    required this.challengeId,
    required ChallengeParticipantRepository participantRepository,
    required UserRepository userRepository,
    required ParticipantEnrollmentService enrollmentService,
  })  : _participantRepository = participantRepository,
        _userRepository = userRepository,
        _enrollmentService = enrollmentService {
    fetchData();
  }

  void fetchData() {
    _subscription?.cancel();
    _listenToParticipants();
  }

  void _listenToParticipants() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (kDebugMode) {
      debugPrint('AdminParticipantsProvider: Starting query for challenge: $challengeId');
      debugPrint('AdminParticipantsProvider: Querying path: challenges/$challengeId/participants');
    }

    _subscription = _participantRepository.streamParticipantsByChallenge(challengeId).listen(
      (data) async {
        if (kDebugMode) {
          debugPrint('AdminParticipantsProvider: Successfully retrieved ${data.length} participants');
        }
        final userIds = data.map((p) => p.userId).toList();
        final users = await _userRepository.getUsersByIds(userIds);
        final userMap = {for (var u in users) u.id: u};

        _allParticipants = data.map((p) {
          return ParticipantViewModel(
            participant: p,
            displayName: UserRepository.formatName(
              userMap[p.userId],
              adminView: true,
              fallbackId: p.userId,
              leaderboardDisplayName: p.leaderboardDisplayName,
            ),
          );
        }).toList();

        // Newest participants first (most recent join at the top).
        _allParticipants.sort((a, b) =>
            (b.participant.joinedAt ?? b.participant.createdAt ?? DateTime(0))
                .compareTo(a.participant.joinedAt ?? a.participant.createdAt ?? DateTime(0)));

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading participants: $error';
        notifyListeners();
      },
    );
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> approveParticipant(String userId, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _enrollmentService.approveParticipant(challengeId, userId, adminId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> rejectParticipant(String userId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _enrollmentService.rejectParticipant(challengeId, userId, adminId, reason);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
