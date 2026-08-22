import 'dart:async';
import 'dispose_guard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';

class ParticipantMySubmissionsProvider with ChangeNotifier, DisposeGuardNotifier {
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

  final ChallengeScoringService _scoring = ChallengeScoringService();

  /// Points each APPROVED check-in earned (keyed by submission id), for the
  /// "+X points" reveal. Empty until an approved baseline exists.
  Map<String, CheckinAward> get awardsBySubmission {
    ChallengeSubmission? baseline;
    try {
      baseline = _allSubmissions.firstWhere((s) =>
          s.type == SubmissionType.baseline &&
          s.reviewStatus == ReviewStatus.approved);
    } catch (_) {
      return const {};
    }
    final approvedProgress = _allSubmissions
        .where((s) =>
            s.type != SubmissionType.baseline &&
            s.reviewStatus == ReviewStatus.approved)
        .toList();
    final awards = _scoring.calculateCheckinAwards(
        baseline: baseline, approvedProgress: approvedProgress);
    return {for (final a in awards) a.submissionId: a};
  }

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
