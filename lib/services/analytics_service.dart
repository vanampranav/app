import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);

  AnalyticsService._();

  static Future<void> initialize() async {
    // In production, collection is enabled by default. 
    // We can explicitly enable it here if needed.
    await _analytics.setAnalyticsCollectionEnabled(true);
    if (kDebugMode) {
      debugPrint('Analytics: Initialized and collection enabled.');
    }
  }

  static Future<void> logAppOpened() async {
    await logEvent('app_open');
  }

  static Future<void> logScreenViewed(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
    if (kDebugMode) {
      debugPrint('Analytics: Screen viewed: $screenName');
    }
  }

  // ─── Authentication Funnel ──────────────────────────────────────────────────

  static Future<void> logRegistrationStarted({required String source, required String method}) async {
    await logEvent('registration_started', {
      'source': source,
      'method': method,
    });
  }

  static Future<void> logRegistrationCompleted({required String method, required String source}) async {
    await logEvent('registration_completed', {
      'method': method,
      'source': source,
    });
  }

  static Future<void> logLoginSuccess(String method) async {
    await logEvent('login_success', {'method': method});
  }

  static Future<void> logProfileCompleted({String? fitnessGoal, String? userType}) async {
    await logEvent('profile_completed', {
      if (fitnessGoal != null) 'fitness_goal': fitnessGoal,
      if (userType != null) 'user_type': userType,
    });
  }

  // ─── Challenge Funnel ───────────────────────────────────────────────────────

  static Future<void> logChallengeViewed(String challengeId, String challengeName) async {
    await logEvent('challenge_viewed', {
      'challenge_id': challengeId,
      'challenge_name': challengeName,
    });
  }

  static Future<void> logChallengeJoinStarted(String challengeId) async {
    await logEvent('challenge_join_started', {'challenge_id': challengeId});
  }

  static Future<void> logPackageSelected({
    required String challengeId,
    required String packageType, 
    required double price, 
    required String currency,
  }) async {
    await logEvent('package_selected', {
      'challenge_id': challengeId,
      'package_type': packageType,
      'price': price,
      'currency': currency,
    });
  }

  static Future<void> logChallengeJoinCompleted(String challengeId, String packageType) async {
    await logEvent('challenge_join_completed', {
      'challenge_id': challengeId,
      'package_type': packageType,
    });
    
    // Update user properties as well
    await setUserProperties(
      challengeParticipant: 'true',
      challengePackage: packageType,
    );
  }

  static Future<void> logBaselineSubmitted(String challengeId, String measurementSource) async {
    await logEvent('baseline_submitted', {
      'challenge_id': challengeId,
      'measurement_source': measurementSource,
    });
  }

  static Future<void> logWeeklyCheckinSubmitted(String challengeId, int weekNumber) async {
    await logEvent('weekly_checkin_submitted', {
      'challenge_id': challengeId,
      'challenge_week': weekNumber,
    });
  }

  // ─── Payment Funnel ─────────────────────────────────────────────────────────

  static Future<void> logPaymentStatusChanged({
    required String challengeId,
    required String participantId,
    String? packageId,
    required String previousStatus,
    required String newStatus,
    String? paymentMethod,
    double? amount,
  }) async {
    await logEvent('payment_status_changed', {
      'challenge_id': challengeId,
      'participant_id': participantId,
      if (packageId != null) 'package_id': packageId,
      'previous_status': previousStatus,
      'new_status': newStatus,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (amount != null) 'amount': amount,
    });
  }

  static Future<void> logPaymentVerified({
    required String challengeId,
    required String participantId,
    required double amount,
    required String paymentMethod,
  }) async {
    await logEvent('payment_verified', {
      'challenge_id': challengeId,
      'participant_id': participantId,
      'amount': amount,
      'payment_method': paymentMethod,
    });
  }

  // ─── Engagement Funnel ──────────────────────────────────────────────────────

  static Future<void> logMealLogged(String source) async {
    await logEvent('meal_logged', {'source': source});
  }

  static Future<void> logWorkoutPlanViewed(String workoutType) async {
    await logEvent('workout_plan_viewed', {'workout_type': workoutType});
  }

  static Future<void> logWorkoutLogged(String workoutType) async {
    await logEvent('workout_logged', {'workout_type': workoutType});
  }

  static Future<void> logAiCoachUsed(String featureName) async {
    await logEvent('ai_coach_used', {'feature_name': featureName});
  }

  // ─── Generic Helpers ────────────────────────────────────────────────────────

  static Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      if (kDebugMode) {
        debugPrint('Analytics: Logging event "$name" with params: $parameters');
      }
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics Error: Failed to log event "$name": $e');
    }
  }

  static Future<void> setUserProperties({
    String? userId,
    String? subscriptionType,
    String? challengeParticipant,
    String? challengePackage,
    String? acquisitionSource,
    String? trainerId,
  }) async {
    try {
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      if (subscriptionType != null) {
        await _analytics.setUserProperty(name: 'subscription_type', value: subscriptionType);
      }
      if (challengeParticipant != null) {
        await _analytics.setUserProperty(name: 'challenge_participant', value: challengeParticipant);
      }
      if (challengePackage != null) {
        await _analytics.setUserProperty(name: 'challenge_package', value: challengePackage);
      }
      if (acquisitionSource != null) {
        await _analytics.setUserProperty(name: 'acquisition_source', value: acquisitionSource);
      }
      if (trainerId != null) {
        await _analytics.setUserProperty(name: 'trainer_id', value: trainerId);
      }

      if (kDebugMode) {
        debugPrint('Analytics: User properties set.');
      }
    } catch (e) {
      debugPrint('Analytics Error: Failed to set user properties: $e');
    }
  }
}
