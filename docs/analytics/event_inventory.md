# EleFit Analytics Event Inventory

This document lists all business-critical analytics events instrumented in the EleFit Flutter app.

| Event Name | Trigger | Parameters | Screen/Feature | Business Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `app_open` | App launch | N/A | Global | Track daily active users (DAU). |
| `registration_started` | User enters onboarding Step 1 | `source`, `method` | Onboarding | Measure conversion funnel start. |
| `registration_completed` | Account created successfully | `method`, `source` | AuthService | Measure sign-up success rate. |
| `login_success` | Successful login | `method` | AuthService | Track returning user engagement. |
| `profile_completed` | Onboarding steps finished | `fitness_goal`, `user_type` | Onboarding | Measure onboarding completion rate. |
| `challenge_viewed` | Challenge details opened | `challenge_id`, `challenge_name` | Challenge Detail | Measure interest in specific challenges. |
| `challenge_join_started` | Join Challenge button tapped | `challenge_id` | Challenge Detail | Measure intent to join. |
| `package_selected` | Challenge package chosen | `challenge_id`, `package_type`, `price`, `currency` | Challenge Detail | Track revenue intent and pricing tier interest. |
| `challenge_join_completed` | Enrollment successful | `challenge_id`, `package_type` | Challenge Detail | Measure challenge conversion. |
| `baseline_submitted` | Initial measurements saved | `challenge_id`, `measurement_source` | Baseline Submission | Track participant activation. |
| `weekly_checkin_submitted` | Weekly check-in saved | `challenge_id`, `challenge_week` | Weekly Check-in | Track long-term engagement. |
| `meal_logged` | Food entry added | `source` | Nutrition Log | Measure core utility usage. |
| `workout_plan_viewed` | AI Coach workout plan viewed | `workout_type` | AI Coach Schedule | Measure engagement with generated workouts. |
| `workout_logged` | User logs or completes a workout | `workout_type` | future feature | Measure activity tracking usage. |
| `ai_coach_used` | Interaction with AI features | `feature_name` | AI Coach Service | Measure AI value-add engagement. |
| `payment_status_changed` | Admin updates manual payment | `challenge_id`, `participant_id`, `previous_status`, `new_status` | Admin Payment Tracking | Track payment funnel lifecycle. |
| `payment_verified` | Payment marked as 'paid' | `challenge_id`, `participant_id`, `amount`, `payment_method` | Admin Payment Tracking | Measure realized revenue. |

## User Properties

| Property Name | Business Purpose |
| :--- | :--- |
| `subscription_type` | Segment free vs. premium users. |
| `challenge_participant` | Identify active challenge members. |
| `challenge_package` | Segment by purchased tier. |
| `acquisition_source` | Track marketing effectiveness. |
| `trainer_id` | Attribute users to specific trainers (future). |
