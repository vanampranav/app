import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/app_user.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'challenge_error_text.dart';

class AdminParticipantDetailProvider with ChangeNotifier {
  final String userId;
  final String? challengeId;
  final UserRepository _userRepository;
  final ChallengeParticipantRepository _participantRepository;

  AppUser? _user;
  ChallengeParticipant? _participant;
  bool _isLoading = true;
  String? _errorMessage;

  AppUser? get user => _user;
  ChallengeParticipant? get participant => _participant;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get displayName => UserRepository.formatName(
    _user, 
    adminView: true, 
    fallbackId: userId,
    leaderboardDisplayName: _participant?.leaderboardDisplayName,
  );

  AdminParticipantDetailProvider({
    required this.userId,
    this.challengeId,
    required UserRepository userRepository,
    required ChallengeParticipantRepository participantRepository,
  }) : _userRepository = userRepository,
       _participantRepository = participantRepository {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _userRepository.getUserById(userId);
      
      if (challengeId != null) {
        _participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId!);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
      _isLoading = false;
      notifyListeners();
    }
  }
}
