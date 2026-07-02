import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/services/analytics_service.dart';

class ParticipantEligibilityViewModel {
  final ChallengeParticipant participant;
  final String displayName;
  final String email;

  ParticipantEligibilityViewModel({
    required this.participant,
    required this.displayName,
    required this.email,
  });

  bool get isEligible => 
    (participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived) &&
    participant.baselineSubmitted &&
    participant.status == ParticipantStatus.active &&
    !participant.disqualified;
}

class AdminEligibilityDashboardProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeParticipantRepository _participantRepository;
  final UserRepository _userRepository;
  final AdminAuditService _auditService;

  List<ParticipantEligibilityViewModel> _allViewModels = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  
  String _currentFilter = 'All';
  String _searchQuery = '';

  List<ParticipantEligibilityViewModel> get viewModels {
    var filtered = _allViewModels;

    // Filter Logic
    if (_currentFilter != 'All') {
      switch (_currentFilter) {
        case 'Eligible':
          filtered = filtered.where((vm) => vm.isEligible).toList();
          break;
        case 'Not Eligible':
          filtered = filtered.where((vm) => !vm.isEligible).toList();
          break;
        case 'Payment Pending':
          filtered = filtered.where((vm) => vm.participant.paymentStatus == PaymentStatus.pending).toList();
          break;
        case 'Missing Baseline':
          filtered = filtered.where((vm) => !vm.participant.baselineSubmitted).toList();
          break;
        case 'Disqualified':
          filtered = filtered.where((vm) => vm.participant.disqualified).toList();
          break;
      }
    }

    // Search Logic
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((vm) {
        return vm.displayName.toLowerCase().contains(query) ||
               (vm.participant.leaderboardDisplayName ?? '').toLowerCase().contains(query) ||
               vm.email.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  // Summary Metrics
  int get totalCount => _allViewModels.length;
  int get paymentPendingCount => _allViewModels.where((vm) => vm.participant.paymentStatus == PaymentStatus.pending).length;
  int get paymentVerifiedCount => _allViewModels.where((vm) => vm.participant.paymentStatus == PaymentStatus.paid || vm.participant.paymentStatus == PaymentStatus.waived).length;
  int get baselineSubmittedCount => _allViewModels.where((vm) => vm.participant.baselineSubmitted).length;
  int get baselineMissingCount => _allViewModels.where((vm) => !vm.participant.baselineSubmitted).length;
  int get eligibleCount => _allViewModels.where((vm) => vm.isEligible).length;
  int get notEligibleCount => totalCount - eligibleCount;
  int get disqualifiedCount => _allViewModels.where((vm) => vm.participant.disqualified).length;

  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  AdminEligibilityDashboardProvider({
    required this.challengeId,
    required ChallengeParticipantRepository participantRepository,
    required UserRepository userRepository,
    required AdminAuditService auditService,
  })  : _participantRepository = participantRepository,
        _userRepository = userRepository,
        _auditService = auditService {
    _listenToParticipants();
  }

  void _listenToParticipants() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _participantRepository.streamParticipantsByChallenge(challengeId).listen(
      (data) async {
        try {
          final userIds = data.map((p) => p.userId).toList();
          final users = await _userRepository.getUsersByIds(userIds);
          final userMap = {for (var u in users) u.id: u};

          _allViewModels = data.map((p) {
            final user = userMap[p.userId];
            return ParticipantEligibilityViewModel(
              participant: p,
              displayName: UserRepository.formatName(
                user, 
                adminView: true, 
                fallbackId: p.userId,
                leaderboardDisplayName: p.leaderboardDisplayName,
              ),
              email: user?.email ?? 'N/A',
            );
          }).toList();

          _isLoading = false;
          _errorMessage = null;
          
          AnalyticsService.logEvent('admin_eligibility_dashboard_viewed', {
            'challenge_id': challengeId,
            'total_participants': totalCount,
            'eligible_count': eligibleCount,
            'not_eligible_count': notEligibleCount,
          });

          notifyListeners();
        } catch (e) {
          _errorMessage = e.toString();
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading participants: $error';
        notifyListeners();
      },
    );
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> disqualifyParticipant(String userId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      final participant = await _participantRepository.getParticipant(challengeId, userId);
      if (participant == null) throw Exception('Participant not found');

      final previousData = participant.toMap();
      final updated = participant.copyWith(
        disqualified: true,
        disqualificationReason: reason,
        disqualifiedAt: DateTime.now(),
        disqualifiedByAdminId: adminId,
        eligibleForPrizes: false,
        updatedAt: DateTime.now(),
      );

      await _participantRepository.updateParticipant(updated);

      await _auditService.logAction(
        adminId: adminId,
        challengeId: challengeId,
        action: 'disqualify_participant',
        targetCollection: FirestoreCollections.challengeParticipants,
        targetId: userId,
        previousData: previousData,
        newData: updated.toMap(),
        reason: reason,
      );

      AnalyticsService.logEvent('participant_eligibility_status_changed', {
        'challenge_id': challengeId,
        'participant_id': userId,
        'previous_status': 'active',
        'new_status': 'disqualified',
        'reason': reason,
      });

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> reinstateParticipant(String userId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      final participant = await _participantRepository.getParticipant(challengeId, userId);
      if (participant == null) throw Exception('Participant not found');

      final previousData = participant.toMap();
      
      // Recalculate eligibility
      final bool willBeEligible = 
        (participant.paymentStatus == PaymentStatus.paid || participant.paymentStatus == PaymentStatus.waived) &&
        participant.baselineSubmitted &&
        participant.status == ParticipantStatus.active;

      final updated = participant.copyWith(
        disqualified: false,
        reinstatedAt: DateTime.now(),
        reinstatedByAdminId: adminId,
        eligibleForPrizes: willBeEligible,
        updatedAt: DateTime.now(),
      );

      await _participantRepository.updateParticipant(updated);

      await _auditService.logAction(
        adminId: adminId,
        challengeId: challengeId,
        action: 'reinstate_participant',
        targetCollection: FirestoreCollections.challengeParticipants,
        targetId: userId,
        previousData: previousData,
        newData: updated.toMap(),
        reason: reason,
      );

      AnalyticsService.logEvent('participant_eligibility_status_changed', {
        'challenge_id': challengeId,
        'participant_id': userId,
        'previous_status': 'disqualified',
        'new_status': 'active',
        'reason': reason,
      });

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> updateNotes(String userId, String notes) async {
    try {
      final participant = await _participantRepository.getParticipant(challengeId, userId);
      if (participant != null) {
        await _participantRepository.updateParticipant(participant.copyWith(
          adminNotes: notes,
          updatedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
