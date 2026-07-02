import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ParticipantMySubmissionsProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeSubmissionRepository _submissionRepository;

  List<ChallengeSubmission> _allSubmissions = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _subscription;
  
  String _currentFilter = 'All';

  List<ChallengeSubmission> get submissions {
    if (_currentFilter == 'All') return _allSubmissions;
    
    return _allSubmissions.where((s) {
      switch (_currentFilter) {
        case 'Baseline':
          return s.type == SubmissionType.baseline;
        case 'Weekly':
          return s.type == SubmissionType.weeklyCheckIn;
        case 'Final':
          return s.type == SubmissionType.finalSubmission;
        case 'Pending Review':
          return s.reviewStatus == ReviewStatus.submitted;
        case 'Approved':
          return s.reviewStatus == ReviewStatus.approved;
        case 'Rejected':
          return s.reviewStatus == ReviewStatus.rejected;
        case 'Resubmission Required':
          return s.reviewStatus == ReviewStatus.needsClarification;
        default:
          return true;
      }
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  ParticipantMySubmissionsProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeSubmissionRepository submissionRepository,
  }) : _submissionRepository = submissionRepository {
    _listenToSubmissions();
  }

  void _listenToSubmissions() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _submissionRepository.streamSubmissionsByParticipant(userId).listen(
      (data) {
        // Filter by challengeId as the repository streams all user submissions
        _allSubmissions = data.where((s) => s.challengeId == challengeId).toList();
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

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
