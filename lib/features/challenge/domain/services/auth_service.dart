import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/models/app_user.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/services/analytics_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isLoading = true;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      debugPrint('AuthService: Firebase SDK user is null');
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    debugPrint('AuthService: Firebase SDK user is logged in: ${firebaseUser.uid}');
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        _currentUser = AppUser.fromFirestore(doc);
        debugPrint('AuthService: User profile loaded. isAdmin: ${_currentUser?.isAdmin}, role: ${_currentUser?.role}');
        
        // Set user ID and basic properties in analytics
        await AnalyticsService.setUserProperties(
          userId: firebaseUser.uid,
          subscriptionType: 'free', // Default for now
        );
      } else {
        debugPrint('AuthService: User document not found in Firestore at users/${firebaseUser.uid}');
        // Fallback or create minimal profile if missing
        _currentUser = AppUser(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
        );
        
        await AnalyticsService.setUserProperties(userId: firebaseUser.uid);
      }
    } catch (e) {
      debugPrint('AuthService: Error fetching user profile: $e');
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  bool get isUserAdmin {
    if (_currentUser == null) {
      if (kDebugMode) debugPrint('AuthService: isUserAdmin evaluated to false (user is null)');
      return false;
    }
    final result = _currentUser!.isAdmin ||
        _currentUser!.role == 'admin' ||
        _currentUser!.role == 'superAdmin';
    if (kDebugMode) {
      debugPrint('AuthService: isUserAdmin evaluated to $result for UID: ${_currentUser!.id}');
    }
    return result;
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await AnalyticsService.logLoginSuccess('email');
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await AnalyticsService.logRegistrationCompleted(method: 'email', source: 'app');
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _onAuthStateChanged(user);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
