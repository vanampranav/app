import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppError {
  final String title;
  final String message;
  final String? technicalCode;

  AppError({
    required this.title,
    required this.message,
    this.technicalCode,
  });
}

class AppErrorMapper {
  AppErrorMapper._();

  static AppError map(dynamic error, {String? screenName, String? featureName, String? userId}) {
    String title = 'Something went wrong';
    String message = 'An unexpected error occurred. Please try again.';
    String? technicalCode;

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('permission-denied') || errorStr.contains('permission_denied')) {
      title = 'Access Denied';
      message = "You don't have access to this section. Please contact your administrator if you believe this is an error.";
      technicalCode = 'PERMISSION_DENIED';
    } else if (errorStr.contains('unavailable') || 
               errorStr.contains('network') || 
               errorStr.contains('socketexception')) {
      title = 'Connection Issue';
      message = "We're having trouble connecting. Please check your internet and try again.";
      technicalCode = 'NETWORK_ERROR';
    } else if (errorStr.contains('not-found') || errorStr.contains('not_found')) {
      title = 'Not Found';
      message = "We couldn't find what you're looking for.";
      technicalCode = 'NOT_FOUND';
    } else if (errorStr.contains('deadline-exceeded') || errorStr.contains('timeout')) {
      title = 'Timed Out';
      message = "This is taking longer than expected. Please try again.";
      technicalCode = 'TIMEOUT';
    } else if (errorStr.contains('unauthenticated')) {
      title = 'Session Expired';
      message = "Please sign in again to continue.";
      technicalCode = 'UNAUTHENTICATED';
    } else if (errorStr.contains('failed-precondition') && errorStr.contains('requires an index')) {
      title = 'Setup Required';
      message = "This section is not fully configured yet. Please contact EleFit support.";
      technicalCode = 'INDEX_MISSING';
    }

    // Log to Crashlytics
    _logToCrashlytics(error, technicalCode, screenName, featureName, userId);

    return AppError(
      title: title,
      message: message,
      technicalCode: technicalCode,
    );
  }

  static void _logToCrashlytics(
    dynamic error, 
    String? code, 
    String? screen, 
    String? feature, 
    String? userId
  ) {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      if (userId != null) crashlytics.setUserIdentifier(userId);
      
      crashlytics.setCustomKey('error_code', code ?? 'UNKNOWN');
      if (screen != null) crashlytics.setCustomKey('screen_name', screen);
      if (feature != null) crashlytics.setCustomKey('feature_name', feature);
      
      crashlytics.recordError(error, StackTrace.current, fatal: false);
      
      if (kDebugMode) {
        debugPrint('AppErrorMapper: Logged to Crashlytics: $error (Code: $code)');
      }
    } catch (e) {
      debugPrint('AppErrorMapper: Failed to log to Crashlytics: $e');
    }
  }
}
