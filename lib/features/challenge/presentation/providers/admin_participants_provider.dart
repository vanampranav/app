import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';

class AdminParticipantsProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeParticipantRepository _participantRepository;
  final ParticipantEnrollmentService _enrollmentService;

  List<ChallengeParticipant> _allParticipants = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<ChallengeParticipant> get participants {
    if (_currentFilter == 'All') return _allParticipants;
    if (_currentFilter == 'Pending') {
      return _allParticipants.where((p) => p.status == 'joined' || p.status == 'invited').toList();
    }
    if (_currentFilter == 'Approved') {
      return _allParticipants.where((p) => p.status == 'active').toList();
    }
    if (_currentFilter == 'Rejected') {
      return _allParticipants.where((p) => p.status == 'disqualified' || p.status == 'withdrawn').toList();
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
    required ParticipantEnrollmentService enrollmentService,
  })  : _participantRepository = participantRepository,
        _enrollmentService = enrollmentService {
    _listenToParticipants();
  }

  void _listenToParticipants() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _participantRepository.streamParticipantsByChallenge(challengeId).listen(
      (data) {
        _allParticipants = data;
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

  Future<void> approveParticipant(String participantId, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _enrollmentService.approveParticipant(participantId, adminId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> rejectParticipant(String participantId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _enrollmentService.rejectParticipant(participantId, adminId, reason);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
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
