import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ParticipantPaymentViewModel {
  final ChallengeParticipant participant;
  final String displayName;

  ParticipantPaymentViewModel({
    required this.participant,
    required this.displayName,
  });
}

class AdminChallengePaymentsProvider with ChangeNotifier {
  final String challengeId;
  final ChallengeParticipantRepository _participantRepository;
  final UserRepository _userRepository;
  final PaymentApprovalService _paymentService;

  List<ParticipantPaymentViewModel> _allViewModels = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  
  String _currentFilter = 'All';
  String _searchQuery = '';

  List<ParticipantPaymentViewModel> get viewModels {
    var filtered = _allViewModels;

    // Status Filter
    if (_currentFilter != 'All') {
      final statusMap = {
        'Pending': PaymentStatus.pending,
        'Pending Review': PaymentStatus.pendingReview,
        'Paid': PaymentStatus.paid,
        'Partially Paid': PaymentStatus.partiallyPaid,
        'Refunded': PaymentStatus.refunded,
        'Waived': PaymentStatus.waived,
      };
      final targetStatus = statusMap[_currentFilter];
      if (targetStatus != null) {
        filtered = filtered.where((vm) => vm.participant.paymentStatus == targetStatus).toList();
      }
    }

    // Search Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((vm) {
        final nameMatch = vm.displayName.toLowerCase().contains(query);
        final nicknameMatch = (vm.participant.leaderboardDisplayName ?? '').toLowerCase().contains(query);
        // Email is usually part of displayName in Admin view
        return nameMatch || nicknameMatch;
      }).toList();
    }

    return filtered;
  }

  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  AdminChallengePaymentsProvider({
    required this.challengeId,
    required ChallengeParticipantRepository participantRepository,
    required UserRepository userRepository,
    required PaymentApprovalService paymentService,
  })  : _participantRepository = participantRepository,
        _userRepository = userRepository,
        _paymentService = paymentService {
    fetchData();
  }

  void fetchData() {
    _subscription?.cancel();
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
            return ParticipantPaymentViewModel(
              participant: p,
              displayName: UserRepository.formatName(
                userMap[p.userId], 
                adminView: true, 
                fallbackId: p.userId,
                leaderboardDisplayName: p.leaderboardDisplayName,
              ),
            );
          }).toList();

          _isLoading = false;
          _errorMessage = null;
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

  Future<void> updatePayment({
    required String participantId, // This is userId
    required String adminId,
    required String newStatus,
    double? amountCollected,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) async {
    _isActionInProgress = true;
    notifyListeners();

    if (kDebugMode) {
      debugPrint('Admin: Updating payment for Challenge: $challengeId, User: $participantId to Status: $newStatus');
    }

    try {
      await _paymentService.updateManualPaymentStatus(
        challengeId: challengeId,
        userId: participantId,
        adminId: adminId,
        newStatus: newStatus,
        amountCollected: amountCollected,
        paymentMethod: paymentMethod,
        reference: reference,
        notes: notes,
      );
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
