import 'package:flutter/foundation.dart';

/// Makes a [ChangeNotifier] safe to notify after it has been disposed.
///
/// Fixes "A <Provider> was used after being disposed" crashes: when an async
/// action (approve / reject / submit) or a Firestore stream callback finishes
/// AFTER its screen was popped, the trailing `notifyListeners()` would otherwise
/// throw a FlutterError and crash the app. With this mixin it's simply a no-op
/// once the notifier is disposed.
///
/// Apply by adding it to the `with` clause AFTER ChangeNotifier, e.g.
///   class FooProvider with ChangeNotifier, DisposeGuardNotifier { ... }
mixin DisposeGuardNotifier on ChangeNotifier {
  bool _disposed = false;

  /// Whether [dispose] has been called. Useful to short-circuit async work.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
