import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ParticipantChallengeDashboardProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final PaymentRecordRepository _paymentRepository;

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  List<ChallengeSubmission> _submissions = [];
  PaymentRecord? _paymentRecord;

  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _challengeSub;
  StreamSubscription? _participantSub;
  StreamSubscription? _submissionSub;
  StreamSubscription? _paymentSub;

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  List<ChallengeSubmission> get submissions => _submissions;
  PaymentRecord? get paymentRecord => _paymentRecord;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ParticipantChallengeDashboardProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeSubmissionRepository submissionRepository,
    required PaymentRecordRepository paymentRepository,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository,
        _paymentRepository = paymentRepository {
    _init();
  }

  void _init() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _listen();
  }

  void _listen() {
    _challengeSub?.cancel();
    _participantSub?.cancel();
    _submissionSub?.cancel();
    _paymentSub?.cancel();

    _challengeSub = _challengeRepository.streamChallengeById(challengeId).listen(
      (data) {
        _challenge = data;
        _checkLoadingDone();
      },
      onError: (err) => _handleError('Error loading challenge: $err'),
    );

    _participantSub = _participantRepository.streamParticipant(challengeId, userId).listen(
      (data) {
        if (data != null) {
          _participant = data;
          _checkLoadingDone();
        } else {
          _participant = null;
          _handleError('Participation record not found.');
        }
      },
      onError: (err) => _handleError('Error loading participant record: $err'),
    );

    _submissionSub = _submissionRepository.streamSubmissionsByParticipant(userId).listen(
      (list) {
        _submissions = list.where((s) => s.challengeId == challengeId).toList();
        notifyListeners();
      },
      // Non-fatal: if submissions can't be read, still show the dashboard with
      // whatever else loaded rather than crashing on an unhandled stream error.
      onError: (err) {
        _submissions = [];
        notifyListeners();
      },
    );

    _paymentSub = _paymentRepository.streamPaymentsByUser(userId).listen(
      (list) {
        try {
          _paymentRecord = list.firstWhere((p) => p.challengeId == challengeId);
        } catch (_) {
          _paymentRecord = null;
        }
        notifyListeners();
      },
      // Non-fatal: a denied/failed payment read must not blow up the dashboard.
      onError: (err) {
        _paymentRecord = null;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    _listen();
  }

  void _checkLoadingDone() {
    if (_challenge != null && _participant != null) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleError(String msg) {
    _errorMessage = msg;
    _isLoading = false;
    notifyListeners();
  }

  // Helper getters for UI status
  ChallengeSubmission? get baselineSubmission {
    try {
      return _submissions.firstWhere((s) => s.type == SubmissionType.baseline);
    } catch (_) {
      return null;
    }
  }

  ChallengeSubmission? get latestWeeklyCheckIn {
    final weekly = _submissions.where((s) => s.type == SubmissionType.weeklyCheckIn).toList();
    if (weekly.isEmpty) return null;
    weekly.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return weekly.first;
  }

  ChallengeSubmission? get finalSubmission {
    try {
      return _submissions.firstWhere((s) => s.type == SubmissionType.finalSubmission);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _challengeSub?.cancel();
    _participantSub?.cancel();
    _submissionSub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }
}
