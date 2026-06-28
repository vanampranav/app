# Analytics Foundation Verification

This document tracks the validation of the analytics, Crashlytics, and performance foundation.

## Verification Steps

### 1. Enable DebugView
To see events in the Firebase Console "DebugView" during development:

**Android:**
```bash
adb shell setprop debug.firebase.analytics.app com.theelefit.app
```

**iOS:**
1. In Xcode, select **Product** > **Scheme** > **Edit Scheme...**
2. Select **Run** in the left sidebar.
3. Select the **Arguments** tab.
4. In the **Arguments Passed On Launch** section, add `-FIRDebugEnabled`.

---

### 2. Logged Events (Expected)

| Event Name | Parameters | Verified |
| :--- | :--- | :--- |
| `app_open` | N/A | [ ] |
| `registration_started` | `source: test_debug` | [ ] |
| `screen_view` | `screen_name: home_screen` (or others) | [ ] |

### 3. User Properties (Expected)

| Property Name | Value | Verified |
| :--- | :--- | :--- |
| `subscription_type` | `free` | [ ] |
| `challenge_participant` | `false` | [ ] |
| `acquisition_source` | `test_debug` | [ ] |

---

### 4. Crashlytics Verification
- **Target**: Non-fatal exception
- **Message**: `Exception: Analytics Verification Non-Fatal Error`
- **Location**: `_SplashRouterState._route` in `main.dart`
- **Verified**: [ ]

---

## Code Fixes Made
- Initialized `FirebaseCrashlytics` in `main.dart`.
- Added `AnalyticsService.observer` to `MaterialApp` for automatic screen tracking.
- Added temporary triggers in `_SplashRouter` to verify foundation on app launch.

## Evidence
*No screenshots available yet. Please attach screenshots from Firebase Console DebugView and Crashlytics Dashboard here.*
