import 'dart:async';
import 'dispose_guard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';

class ParticipantChallengeDiscoveryProvider with ChangeNotifier, DisposeGuardNotifier {
  final ChallengeService _challengeService;
  
  List<Challenge> _challenges = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _subscription;

  List<Challenge> get challenges => _challenges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ParticipantChallengeDiscoveryProvider({required ChallengeService challengeService})
      : _challengeService = challengeService {
    _listenToChallenges();
  }

  void _listenToChallenges() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _challengeService.streamActiveChallenges().listen(
      (data) {
        _challenges = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading challenges: $error';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
