import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'challenge_error_text.dart';
import 'dispose_guard_notifier.dart';

class PaymentViewModel {
  final PaymentRecord payment;
  final String displayName;

  PaymentViewModel({
    required this.payment,
    required this.displayName,
  });
}

class AdminPaymentsProvider with ChangeNotifier, DisposeGuardNotifier {
  final String challengeId;
  final PaymentRecordRepository _paymentRepository;
  final ChallengeParticipantRepository _participantRepository;
  final UserRepository _userRepository;
  final PaymentApprovalService _paymentService;

  List<PaymentViewModel> _allPayments = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<PaymentViewModel> get payments {
    if (_currentFilter == 'All') return _allPayments;
    if (_currentFilter == 'Pending') {
      return _allPayments.where((p) => p.payment.status == PaymentStatus.pending).toList();
    }
    if (_currentFilter == 'Approved/Paid') {
      return _allPayments.where((p) => p.payment.status == PaymentStatus.paid).toList();
    }
    if (_currentFilter == 'Failed') {
      return _allPayments.where((p) => p.payment.status == PaymentStatus.failed).toList();
    }
    return _allPayments;
  }

  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  AdminPaymentsProvider({
    required this.challengeId,
    required PaymentRecordRepository paymentRepository,
    required ChallengeParticipantRepository participantRepository,
    required UserRepository userRepository,
    required PaymentApprovalService paymentService,
  })  : _paymentRepository = paymentRepository,
        _participantRepository = participantRepository,
        _userRepository = userRepository,
        _paymentService = paymentService {
    _listenToPayments();
  }

  void _listenToPayments() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _paymentRepository.streamPaymentsByChallenge(challengeId).listen(
      (data) async {
        final userIds = data.map((p) => p.userId).toList();
        final users = await _userRepository.getUsersByIds(userIds);
        final userMap = {for (var u in users) u.id: u};

        final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;
        final participantMap = {for (var p in participants) p.userId: p};

        _allPayments = data.map((p) {
          final participant = participantMap[p.userId];
          return PaymentViewModel(
            payment: p,
            displayName: UserRepository.formatName(
              userMap[p.userId],
              adminView: true,
              fallbackId: p.userId,
              leaderboardDisplayName: participant?.leaderboardDisplayName,
            ),
          );
        }).toList();

        // Newest submissions first (most recently submitted payment at the top).
        _allPayments.sort((a, b) => (b.payment.createdAt ?? DateTime(0))
            .compareTo(a.payment.createdAt ?? DateTime(0)));

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading payments: $error';
        notifyListeners();
      },
    );
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> approvePayment(String paymentId, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _paymentService.approvePayment(paymentId, adminId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> rejectPayment(String paymentId, String adminId, String reason) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      await _paymentService.rejectPayment(paymentId, adminId, reason);
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
