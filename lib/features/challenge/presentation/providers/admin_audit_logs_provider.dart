import 'dart:async';
import 'dispose_guard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/admin_audit_log.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';

class AuditLogViewModel {
  final AdminAuditLog log;
  final String adminName;

  AuditLogViewModel({
    required this.log,
    required this.adminName,
  });
}

class AdminAuditLogsProvider with ChangeNotifier, DisposeGuardNotifier {
  final String challengeId;
  final AdminAuditService _auditService;
  final UserRepository _userRepository;

  List<AuditLogViewModel> _allLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _subscription;
  String _currentFilter = 'All';

  List<AuditLogViewModel> get logs {
    if (_currentFilter == 'All') return _allLogs;
    
    return _allLogs.where((item) {
      final log = item.log;
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
    required UserRepository userRepository,
  }) : _auditService = auditService,
       _userRepository = userRepository {
    _listenToLogs();
  }

  void _listenToLogs() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _auditService.streamChallengeAuditLogs(challengeId).listen(
      (data) async {
        final adminIds = data.map((l) => l.adminId).toSet().toList();
        final users = await _userRepository.getUsersByIds(adminIds);
        final userMap = {for (var u in users) u.id: u};

        _allLogs = data.map((l) {
          return AuditLogViewModel(
            log: l,
            adminName: UserRepository.formatName(userMap[l.adminId], adminView: true, fallbackId: l.adminId),
          );
        }).toList();

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
