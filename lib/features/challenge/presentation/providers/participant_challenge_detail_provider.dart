import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'challenge_error_text.dart';

class ParticipantChallengeDetailProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ParticipantEnrollmentService _enrollmentService;

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _errorMessage;
  StreamSubscription? _challengeSub;
  StreamSubscription? _participantSub;

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  bool get isLoading => _isLoading;
  bool get isJoining => _isJoining;
  String? get errorMessage => _errorMessage;
  bool get hasJoined => _participant != null;

  ParticipantChallengeDetailProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required ParticipantEnrollmentService enrollmentService,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _enrollmentService = enrollmentService {
    _init();
  }

  void _init() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _challengeSub = _challengeRepository.streamChallengeById(challengeId).listen(
      (data) {
        _challenge = data;
        _checkLoadingDone();
      },
      onError: (err) => _handleError('Error loading challenge: $err'),
    );

    _participantSub = _participantRepository.streamParticipant(challengeId, userId).listen(
      (data) {
        _participant = data;
        _checkLoadingDone();
      },
      onError: (err) => _handleError('Error checking participation: $err'),
    );
  }

  void _checkLoadingDone() {
    // We expect challenge stream to emit at least once. 
    // Participant stream will emit null (or error) if not joined.
    _isLoading = false;
    notifyListeners();
  }

  void _handleError(String msg) {
    _errorMessage = msg;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> joinChallenge({String? nickname, ChallengePackage? package}) async {
    if (_isJoining) return;
    _isJoining = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _enrollmentService.joinChallenge(
        userId: userId, 
        challengeId: challengeId,
        leaderboardDisplayName: nickname,
        package: package,
      );
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _challengeSub?.cancel();
    _participantSub?.cancel();
    super.dispose();
  }
}
