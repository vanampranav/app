import 'dart:async';
import 'dispose_guard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'challenge_error_text.dart';

class SubmissionViewModel {
  final ChallengeSubmission submission;
  final String displayName;

  SubmissionViewModel({
    required this.submission,
    required this.displayName,
  });
}

class AdminSubmissionsProvider with ChangeNotifier, DisposeGuardNotifier {
  final String challengeId;
  final ChallengeSubmissionRepository _submissionRepository;
  final ChallengeParticipantRepository _participantRepository;
  final UserRepository _userRepository;
  final SubmissionReviewService _submissionService;

  List<SubmissionViewModel> _allSubmissions = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  
  String _currentStatusFilter = 'All';
  String _currentTypeFilter = 'All Types';

  List<SubmissionViewModel> get submissions {
    var filtered = _allSubmissions;
    
    // Status Filter
    if (_currentStatusFilter == 'Pending Review') {
      filtered = filtered.where((s) => s.submission.reviewStatus == ReviewStatus.submitted).toList();
    } else if (_currentStatusFilter == 'Approved') {
      filtered = filtered.where((s) => s.submission.reviewStatus == ReviewStatus.approved).toList();
    } else if (_currentStatusFilter == 'Rejected') {
      filtered = filtered.where((s) => s.submission.reviewStatus == ReviewStatus.rejected).toList();
    } else if (_currentStatusFilter == 'Resubmission Required') {
      filtered = filtered.where((s) => s.submission.reviewStatus == ReviewStatus.needsClarification).toList();
    }

    // Type Filter
    if (_currentTypeFilter == 'Baseline') {
      filtered = filtered.where((s) => s.submission.type == SubmissionType.baseline).toList();
    } else if (_currentTypeFilter == 'Weekly') {
      filtered = filtered.where((s) => s.submission.type == SubmissionType.weeklyCheckIn).toList();
    } else if (_currentTypeFilter == 'Final') {
      filtered = filtered.where((s) => s.submission.type == SubmissionType.finalSubmission).toList();
    }

    return filtered;
  }

  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String get currentStatusFilter => _currentStatusFilter;
  String get currentTypeFilter => _currentTypeFilter;

  AdminSubmissionsProvider({
    required this.challengeId,
    required ChallengeSubmissionRepository submissionRepository,
    required ChallengeParticipantRepository participantRepository,
    required UserRepository userRepository,
    required SubmissionReviewService submissionService,
  })  : _submissionRepository = submissionRepository,
        _participantRepository = participantRepository,
        _userRepository = userRepository,
        _submissionService = submissionService {
    _listenToSubmissions();
  }

  void _listenToSubmissions() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _submissionRepository.streamSubmissionsByChallenge(challengeId).listen(
      (data) async {
        final userIds = data.map((s) => s.userId).toList();
        final users = await _userRepository.getUsersByIds(userIds);
        final userMap = {for (var u in users) u.id: u};

        final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;
        final participantMap = {for (var p in participants) p.userId: p};

        _allSubmissions = data.map((s) {
          final participant = participantMap[s.userId];
          return SubmissionViewModel(
            submission: s,
            displayName: UserRepository.formatName(
              userMap[s.userId], 
              adminView: true, 
              fallbackId: s.userId,
              leaderboardDisplayName: participant?.leaderboardDisplayName,
            ),
          );
        }).toList();

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading submissions: $error';
        notifyListeners();
      },
    );
  }

  void setStatusFilter(String filter) {
    _currentStatusFilter = filter;
    notifyListeners();
  }

  void setTypeFilter(String filter) {
    _currentTypeFilter = filter;
    notifyListeners();
  }

  Future<void> approveSubmission(String submissionId, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _submissionService.approveSubmission(submissionId, adminId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> rejectSubmission(String submissionId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _submissionService.rejectSubmission(submissionId, adminId, reason);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> requestResubmission(String submissionId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _submissionService.requestResubmission(submissionId, adminId, reason);
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
