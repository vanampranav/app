# EleFit Error Experience Framework

This document outlines the standardization of error handling and display within the EleFit application.

## Core Goals
- **User-Centric**: Never show raw technical exceptions or stack traces to the user.
- **Friendly Language**: Use encouraging and helpful language for all error states.
- **Actionable**: Always provide a clear next step (Retry, Go Back, or Contact Support).
- **Standardized**: Maintain visual and functional consistency across the entire app.
- **Auditable**: Log all technical errors to Firebase Crashlytics with context.

## Components

### 1. `EFErrorView`
The primary full-screen error view for high-level failures.
- **Location**: `lib/widgets/ef_error_components.dart`
- **Usage**: When a screen fails to load initial data or a critical process fails.

### 2. `EFEmptyStateView`
Displayed when a collection is empty or a search returns no results.
- **Usage**: "No active challenges", "No submissions yet".

### 3. `EFLoadingStateView`
A consistent loading indicator with an optional status message.

### 4. `EFRetryButton`
A standardized secondary button for retrying failed operations.

## AppErrorMapper
The `AppErrorMapper` utility converts technical errors into user-friendly `AppError` objects.

| Technical String | Friendly Title | Friendly Message |
| :--- | :--- | :--- |
| `permission-denied` | Access Denied | You don't have access to this section. Please contact your administrator if you believe this is an error. |
| `unavailable` / `network` | Connection Issue | We're having trouble connecting. Please check your internet. |
| `not-found` | Not Found | We couldn't find what you're looking for. |
| `deadline-exceeded` | Timed Out | This is taking longer than expected. Please try again. |
| `failed-precondition` (index) | Setup Required | This section is not fully configured yet. Please contact EleFit support. |
| `unknown` | Something went wrong | An unexpected error occurred. Please try again. |

## Implementation Flow

1. **Catch Error** in the Provider or Service.
2. **Set Error Message** in the state.
3. **In the UI**, use `AppErrorMapper.map(errorMessage)` to get a friendly object.
4. **Render `EFErrorView`** passing the mapped properties.

## Logging to Crashlytics
The `AppErrorMapper` automatically logs errors to Crashlytics with the following keys:
- `error_code`: The technical identifier (e.g., `PERMISSION_DENIED`).
- `screen_name`: The screen where the error occurred.
- `feature_name`: The logical feature group (e.g., `ChallengeEnrollment`).
- `user_id`: The UID of the user if authenticated.
