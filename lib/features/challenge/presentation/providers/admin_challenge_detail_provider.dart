import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';

class AdminChallengeDetailProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeRepository _challengeRepository;
  final ChallengeService _challengeService;

  Challenge? _challenge;
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;

  Challenge? get challenge => _challenge;
  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;

  AdminChallengeDetailProvider({
    required this.challengeId,
    required ChallengeRepository challengeRepository,
    required ChallengeService challengeService,
  })  : _challengeRepository = challengeRepository,
        _challengeService = challengeService {
    _listenToChallenge();
  }

  void _listenToChallenge() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _challengeRepository.streamChallengeById(challengeId).listen(
      (data) {
        _challenge = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading challenge: $error';
        notifyListeners();
      },
    );
  }

  Future<void> activateChallenge(String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _challengeService.activateChallenge(challengeId, adminId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> closeChallenge(String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _challengeService.closeChallenge(challengeId, adminId);
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
