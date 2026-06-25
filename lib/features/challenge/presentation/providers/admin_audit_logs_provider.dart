import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/admin_audit_log.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';

class AdminAuditLogsProvider with ChangeNotifier {
  final String challengeId;
  final AdminAuditService _auditService;

  List<AdminAuditLog> _allLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<AdminAuditLog> get logs {
    if (_currentFilter == 'All') return _allLogs;
    
    return _allLogs.where((log) {
      switch (_currentFilter) {
        case 'Participant':
          return log.action.contains('participant');
        case 'Payment':
          return log.action.contains('payment');
        case 'Submission':
          return log.action.contains('submission');
        case 'Challenge':
          return log.action.contains('challenge');
        default:
          return true;
      }
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;

  AdminAuditLogsProvider({
    required this.challengeId,
    required AdminAuditService auditService,
  }) : _auditService = auditService {
    _listenToLogs();
  }

  void _listenToLogs() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _auditService.streamChallengeAuditLogs(challengeId).listen(
      (data) {
        _allLogs = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Error loading audit logs: $error';
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
