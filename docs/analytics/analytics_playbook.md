# EleFit Analytics Playbook

This document outlines the strategy and implementation rules for analytics within the EleFit Flutter application.

## Core Principles

1. **Centralization**: All analytics events MUST go through the `AnalyticsService` class. Never call `FirebaseAnalytics.instance` directly in widgets or feature logic.
2. **Privacy**: Never log Personally Identifiable Information (PII) like names, phone numbers, or exact addresses in event parameters.
3. **Consistency**: Use the naming conventions defined below.

## Service Location

The `AnalyticsService` is located at: `lib/services/analytics_service.dart`.

## Naming Conventions

### Events
- **Format**: `snake_case` (e.g., `challenge_viewed`).
- **Standard Prefixes**:
  - `registration_`: For onboarding/sign-up flows.
  - `login_`: For authentication events.
  - `challenge_`: For Challenge MVP features.
  - `meal_`: For nutrition logging.
  - `workout_`: For activity logging.

### Parameters
- **Format**: `snake_case` (e.g., `package_type`).
- Always use descriptive names.

## How to Add a New Event

1. **Open** `lib/services/analytics_service.dart`.
2. **Add a strongly typed method** for your event.
3. **Internal Logic**: Use the private `logEvent` helper to handle errors and debug logging.

### Example

```dart
static Future<void> logNewFeatureUsed(String detail) async {
  await logEvent('new_feature_used', {'detail': detail});
}
```

## Common Event Examples

### Challenge Events
- `logChallengeViewed(challengeId, challengeName)`
- `logChallengeJoinStarted(challengeId)`
- `logChallengeJoinCompleted(challengeId, packageType)`

### AI Coach Events
- `logAiCoachUsed(featureName)`

### Nutrition Events
- `logMealLogged(source)`

## User Properties

User properties are used to segment users in the Firebase Console. Set these after login or profile updates using:

```dart
AnalyticsService.setUserProperties(
  subscriptionType: 'premium',
  challengeParticipant: 'true',
);
```

## Debugging

When running in debug mode (`kDebugMode`), all events are printed to the console:
`Analytics: Logging event "event_name" with params: {param: value}`

You can also use the **Firebase DebugView** in the Firebase Console to verify events in real-time.

## What NOT to do
- ❌ Do not log raw IDs if a friendly name is available (unless for technical tracking).
- ❌ Do not log passwords or sensitive tokens.
- ❌ Do not create duplicate event names for the same action on different screens.
