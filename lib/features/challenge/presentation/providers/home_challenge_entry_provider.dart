import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class HomeChallengeEntryProvider with ChangeNotifier {
  final String userId;
  final ChallengeParticipantRepository _participantRepository;

  ChallengeParticipant? _activeParticipation;
  bool _isLoading = true;
  StreamSubscription? _subscription;

  ChallengeParticipant? get activeParticipation => _activeParticipation;
  bool get isLoading => _isLoading;
  bool get hasActiveChallenge => _activeParticipation != null;

  HomeChallengeEntryProvider({
    required this.userId,
    required ChallengeParticipantRepository participantRepository,
  }) : _participantRepository = participantRepository {
    _init();
  }

  void _init() {
    if (userId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription = _participantRepository.streamParticipantsByUser(userId).listen((participations) {
      // Find the first participation that is joined or active
      try {
        _activeParticipation = participations.firstWhere(
          (p) => p.status == ParticipantStatus.joined || p.status == ParticipantStatus.active,
        );
      } catch (_) {
        _activeParticipation = null;
      }
      
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
