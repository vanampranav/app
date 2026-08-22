import 'package:flutter/material.dart';
import 'dispose_guard_notifier.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'challenge_error_text.dart';

class ChallengePackageProvider with ChangeNotifier, DisposeGuardNotifier {
  final String challengeId;
  final ChallengePackageService _packageService;

  List<ChallengePackage> _packages = [];
  ChallengePackage? _selectedPackage;
  bool _isLoading = true;
  String? _errorMessage;

  List<ChallengePackage> get packages => _packages;
  ChallengePackage? get selectedPackage => _selectedPackage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChallengePackageProvider({
    required this.challengeId,
    required ChallengePackageService packageService,
  }) : _packageService = packageService {
    _fetchPackages();
  }

  Future<void> retry() async {
    await _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _packages = await _packageService.getActivePackages(challengeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectPackage(ChallengePackage package) {
    _selectedPackage = package;
    notifyListeners();
  }
}
