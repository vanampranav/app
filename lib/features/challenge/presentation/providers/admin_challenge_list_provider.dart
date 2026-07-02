import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';

class AdminChallengeListProvider with ChangeNotifier {
  final ChallengeRepository _challengeRepository;
  
  List<Challenge> _challenges = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _subscription;

  List<Challenge> get challenges => _challenges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AdminChallengeListProvider({required ChallengeRepository challengeRepository})
      : _challengeRepository = challengeRepository {
    _listenToChallenges();
  }

  void _listenToChallenges() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _challengeRepository.streamAllChallenges().listen(
      (data) {
        _challenges = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
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
