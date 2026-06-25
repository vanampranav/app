import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class AdminSubmissionsProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeSubmissionRepository _submissionRepository;
  final SubmissionReviewService _submissionService;

  List<ChallengeSubmission> _allSubmissions = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  
  String _currentStatusFilter = 'All';
  String _currentTypeFilter = 'All Types';

  List<ChallengeSubmission> get submissions {
    var filtered = _allSubmissions;
    
    // Status Filter
    if (_currentStatusFilter == 'Pending Review') {
      filtered = filtered.where((s) => s.reviewStatus == ReviewStatus.submitted).toList();
    } else if (_currentStatusFilter == 'Approved') {
      filtered = filtered.where((s) => s.reviewStatus == ReviewStatus.approved).toList();
    } else if (_currentStatusFilter == 'Rejected') {
      filtered = filtered.where((s) => s.reviewStatus == ReviewStatus.rejected).toList();
    } else if (_currentStatusFilter == 'Resubmission Required') {
      filtered = filtered.where((s) => s.reviewStatus == ReviewStatus.needsClarification).toList();
    }

    // Type Filter
    if (_currentTypeFilter == 'Baseline') {
      filtered = filtered.where((s) => s.type == SubmissionType.baseline).toList();
    } else if (_currentTypeFilter == 'Weekly') {
      filtered = filtered.where((s) => s.type == SubmissionType.weeklyCheckIn).toList();
    } else if (_currentTypeFilter == 'Final') {
      filtered = filtered.where((s) => s.type == SubmissionType.finalSubmission).toList();
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
    required SubmissionReviewService submissionService,
  })  : _submissionRepository = submissionRepository,
        _submissionService = submissionService {
    _listenToSubmissions();
  }

  void _listenToSubmissions() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _submissionRepository.streamSubmissionsByChallenge(challengeId).listen(
      (data) {
        _allSubmissions = data;
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
