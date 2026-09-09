import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'secrets.dart';

enum Environment { dev, prod }

/// Authoritative environment configuration for EleFit.
/// Guarantees that ALL Firebase access paths (SDK, REST, Custom Tokens, Functions)
/// use the exact same target environment.
class AppEnvironment {
  static const String _envRaw = String.fromEnvironment('ENV', defaultValue: 'prod');

  /// Active environment. Validated on startup.
  static Environment get current {
    final norm = _envRaw.trim().toLowerCase();
    if (norm == 'dev') {
      return Environment.dev;
    }
    if (norm == 'prod') {
      return Environment.prod;
    }
    throw StateError(
      'FATAL: Invalid ENV="$_envRaw". Allowed values are "dev" or "prod".',
    );
  }

  static bool get isDev => current == Environment.dev;
  static bool get isProd => current == Environment.prod;

  // --------------------------------------------------------------------------
  // RAW ENVIRONMENT INPUTS (Compile-time defines)
  // --------------------------------------------------------------------------
  static const String _devProjectIdOverride = String.fromEnvironment(
    'DEV_PROJECT_ID',
    defaultValue: 'elefit-dev',
  );

  static const String _devApiKeyOverride = String.fromEnvironment(
    'DEV_FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const String _devAndroidAppIdOverride = String.fromEnvironment(
    'DEV_ANDROID_APP_ID',
    defaultValue: '1:854625609432:android:8152c4b2b7e799c20f99ad',
  );

  static const String _devIosAppIdOverride = String.fromEnvironment(
    'DEV_IOS_APP_ID',
    defaultValue: '1:854625609432:ios:b91ef3b946e0fc990f99ad',
  );

  static const String _devMessagingSenderIdOverride = String.fromEnvironment(
    'DEV_MESSAGING_SENDER_ID',
    defaultValue: '854625609432',
  );

  // --------------------------------------------------------------------------
  // PROD CONFIGURATION CONSTANTS (getfit-with-elefit production values)
  // --------------------------------------------------------------------------
  static const String prodProjectId = 'getfit-with-elefit';
  static const String prodStorageBucket = 'getfit-with-elefit.firebasestorage.app';
  static const String prodMessagingSenderId = '302421573042';
  static const String prodAndroidApiKey = 'AIzaSyA2zu144EAVw0j7lC9uTyjPfBmSW7jHEbU';
  static const String prodAndroidAppId = '1:302421573042:android:c4296edd42737b2a5338ab';
  static const String prodIosApiKey = 'AIzaSyBIf2KRmElpsjV3xNp7KUWoIF9KrngB1ZA';
  static const String prodIosAppId = '1:302421573042:ios:a6580eb762d039c15338ab';

  // --------------------------------------------------------------------------
  // AUTHORITATIVE RESOLVED CONFIGURATION
  // --------------------------------------------------------------------------
  static String get projectId => isDev ? _devProjectIdOverride : prodProjectId;

  static String get storageBucket =>
      isDev ? '$projectId.firebasestorage.app' : prodStorageBucket;

  static String get firebaseApiKey {
    if (isDev) {
      return _devApiKeyOverride.isNotEmpty ? _devApiKeyOverride : Secrets.devFirebaseApiKey;
    }
    return Secrets.firebaseApiKey;
  }

  static String get messagingSenderId {
    if (isDev) {
      return _devMessagingSenderIdOverride;
    }
    return prodMessagingSenderId;
  }

  static String get appId {
    if (isDev) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return _devAndroidAppIdOverride;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return _devIosAppIdOverride;
      }
      return '';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? prodAndroidAppId
        : prodIosAppId;
  }

  static String get mintTokenUrl =>
      'https://us-central1-$projectId.cloudfunctions.net/mintFirebaseToken';

  static String get firestoreRestUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  static String authRestUrl(String action) =>
      'https://identitytoolkit.googleapis.com/v1/accounts:$action?key=$firebaseApiKey';

  static String get customTokenRestUrl => authRestUrl('signInWithCustomToken');

  // --------------------------------------------------------------------------
  // VALIDATION & INVARIANT ENFORCEMENT
  // --------------------------------------------------------------------------

  /// Validates resolved environment configuration on app initialization.
  /// Crashes immediately if ENV=dev is requested but DEV configuration is missing or invalid.
  static void validate() {
    if (!isDev) {
      return; // PROD uses hardcoded valid production constants
    }

    final resolvedProject = projectId.trim();
    if (resolvedProject.isEmpty) {
      throw StateError(
        'FATAL: ENV=dev requested, but DEV Firebase project ID is empty. '
        'Refusing to start or fall back to production!',
      );
    }
    if (resolvedProject == 'getfit-with-elefit') {
      throw StateError(
        'FATAL: ENV=dev requested, but resolved project ID points to production '
        '("getfit-with-elefit"). Refusing to fall back to production!',
      );
    }

    final resolvedKey = firebaseApiKey.trim();
    if (resolvedKey.isEmpty) {
      throw StateError(
        'FATAL: ENV=dev requested, but DEV Firebase API Key is unconfigured. '
        'Please set DEV_FIREBASE_API_KEY or Secrets.devFirebaseApiKey.',
      );
    }

    final resolvedSender = messagingSenderId.trim();
    if (resolvedSender.isEmpty) {
      throw StateError(
        'FATAL: ENV=dev requested, but DEV messagingSenderId is unconfigured. '
        'Please set DEV_MESSAGING_SENDER_ID.',
      );
    }

    final resolvedBucket = storageBucket.trim();
    if (resolvedBucket.isEmpty || resolvedBucket == 'getfit-with-elefit.firebasestorage.app') {
      throw StateError(
        'FATAL: ENV=dev requested, but DEV storageBucket is invalid or pointing to production. '
        'Refusing to start or fall back to production!',
      );
    }

    if (kIsWeb) {
      throw UnsupportedError('FirebaseOptions not configured for web.');
    }

    final currentAppId = appId.trim();
    if (currentAppId.isEmpty) {
      final platformName = defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'iOS';
      throw StateError(
        'FATAL: ENV=dev requested, but DEV $platformName appId is unconfigured. '
        'Please set DEV_${platformName.toUpperCase()}_APP_ID.',
      );
    }
  }

  /// Verifies post-initialization invariant against active FirebaseApp.
  static void verifyPostInitialization() {
    final actualOptions = Firebase.app().options;

    if (actualOptions.projectId != projectId) {
      throw StateError(
        'FATAL INVARIANT MISMATCH: Firebase.app().options.projectId ("${actualOptions.projectId}") '
        'does not match AppEnvironment.projectId ("$projectId").',
      );
    }

    if (isDev && actualOptions.projectId == 'getfit-with-elefit') {
      throw StateError(
        'FATAL INVARIANT FAILURE: ENV=dev requested, but initialized FirebaseApp options '
        'are bound to production ("getfit-with-elefit")! Immediate shutdown enforced.',
      );
    }
  }

  /// Environment-specific [FirebaseOptions] for SDK initialization.
  static FirebaseOptions get firebaseOptions {
    validate();

    if (kIsWeb) {
      throw UnsupportedError('FirebaseOptions not configured for web.');
    }

    if (isDev) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return FirebaseOptions(
            apiKey: firebaseApiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            storageBucket: storageBucket,
          );
        case TargetPlatform.iOS:
          return FirebaseOptions(
            apiKey: firebaseApiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            storageBucket: storageBucket,
            iosBundleId: 'com.theelefit.app',
          );
        default:
          throw UnsupportedError('Platform not supported in DEV mode.');
      }
    }

    // PROD Options (Unchanged)
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: prodAndroidApiKey,
          appId: prodAndroidAppId,
          messagingSenderId: prodMessagingSenderId,
          projectId: prodProjectId,
          storageBucket: prodStorageBucket,
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: prodIosApiKey,
          appId: prodIosAppId,
          messagingSenderId: prodMessagingSenderId,
          projectId: prodProjectId,
          storageBucket: prodStorageBucket,
          iosBundleId: 'com.theelefit.app',
        );
      default:
        throw UnsupportedError('Platform not supported in PROD mode.');
    }
  }
}
