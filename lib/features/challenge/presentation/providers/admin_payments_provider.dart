import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class AdminPaymentsProvider with ChangeNotifier {
  final String challengeId;
  final PaymentRecordRepository _paymentRepository;
  final PaymentApprovalService _paymentService;

  List<PaymentRecord> _allPayments = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<PaymentRecord> get payments {
    if (_currentFilter == 'All') return _allPayments;
    if (_currentFilter == 'Pending') {
      return _allPayments.where((p) => p.status == PaymentStatus.pending).toList();
    }
    if (_currentFilter == 'Approved/Paid') {
      return _allPayments.where((p) => p.status == PaymentStatus.paid).toList();
    }
    if (_currentFilter == 'Rejected') {
      return _allPayments.where((p) => p.status == PaymentStatus.rejected).toList();
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
    required PaymentApprovalService paymentService,
  })  : _paymentRepository = paymentRepository,
        _paymentService = paymentService {
    _listenToPayments();
  }

  void _listenToPayments() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _paymentRepository.streamPaymentsByChallenge(challengeId).listen(
      (data) {
        _allPayments = data;
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
      _errorMessage = e.toString();
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
