import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';

class AdminChallengePackagesProvider with ChangeNotifier {
  final String challengeId;
  final ChallengePackageService _packageService;
  final AdminAuditService _auditService;

  List<ChallengePackage> _packages = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

  List<ChallengePackage> get packages => _packages;
  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;

  AdminChallengePackagesProvider({
    required this.challengeId,
    required ChallengePackageService packageService,
    required AdminAuditService auditService,
  })  : _packageService = packageService,
        _auditService = auditService {
    fetchPackages();
  }

  Future<void> fetchPackages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _packages = await _packageService.getAllPackages(challengeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> savePackage(ChallengePackage package, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      final isNew = package.id.isEmpty;
      await _packageService.savePackage(package);
      
      await _auditService.logAction(
        adminId: adminId,
        challengeId: challengeId,
        action: isNew ? 'create_package' : 'update_package',
        targetCollection: 'challengePackages',
        targetId: package.id,
        newData: package.toMap(),
      );

      await fetchPackages();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> togglePackageStatus(ChallengePackage package, String adminId) async {
    _isActionInProgress = true;
    notifyListeners();

    try {
      final updated = package.copyWith(isActive: !package.isActive);
      await _packageService.updatePackage(updated);

      await _auditService.logAction(
        adminId: adminId,
        challengeId: challengeId,
        action: 'toggle_package_status',
        targetCollection: 'challengePackages',
        targetId: package.id,
        previousData: package.toMap(),
        newData: updated.toMap(),
      );

      await fetchPackages();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }
}
