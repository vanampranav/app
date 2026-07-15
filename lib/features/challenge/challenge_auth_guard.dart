import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/services/firebase_rest_service.dart';

/// Ensures the Firebase Auth SDK has a live session before a challenge write
/// (Storage upload or Firestore write).
///
/// The app's primary login is the REST service; the Firebase Auth SDK is a
/// separate session the challenge feature needs. If a participant's SDK session
/// never established (e.g. sign-in was blocked by reCAPTCHA on an emulator) or
/// expired, Storage/Firestore writes fail with `unauthorized` / `permission-denied`.
///
/// This transparently restores the SDK session from the stored REST credentials.
/// Throws a clear, user-facing message if it still can't sign in.
Future<void> ensureFirebaseSdkSignedIn() async {
  if (FirebaseAuth.instance.currentUser != null) return;

  final rest = FirebaseRestService();
  await rest.init();
  final email = rest.email;
  final password = await rest.storedPassword;

  if (email != null && password != null) {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('ensureFirebaseSdkSignedIn: restore failed — $e');
    }
  }

  if (FirebaseAuth.instance.currentUser == null) {
    throw Exception('You appear to be signed out. Please log out and log back in, then try again.');
  }
}
