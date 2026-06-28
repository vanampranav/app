# Admin Eligibility Dashboard

The Eligibility Dashboard provides EleFit admins with a real-time overview of participant readiness and prize eligibility for a specific challenge.

## Business Purpose
Admins use this dashboard to monitor the enrollment funnel and identify participants who need follow-up. It answers:
- Who is fully eligible to win prizes?
- Who has not yet paid?
- Who is missing their baseline submission?
- Who has been disqualified?

## Eligibility Rules
A participant is marked as **Eligible** for prizes only when ALL of the following conditions are met:
1. **Payment**: `paymentStatus` is `paid` or `waived`.
2. **Baseline**: `baselineSubmitted` is `true` (updated automatically when baseline is approved).
3. **Status**: `participantStatus` is `active`.
4. **Disqualification**: `disqualified` is `false`.

If any condition is not met, the participant is **Not Eligible**.

## Dashboard Metrics
- **Total**: Total number of participants joined.
- **Eligible**: Count of participants meeting all eligibility rules.
- **Not Eligible**: Count of participants failing at least one rule.
- **Paid**: Participants with verified payment.
- **Unpaid**: Participants with pending payment.
- **Baseline**: Participants who have submitted an approved baseline.
- **Disqualified**: Participants manually disqualified by an admin.

## Admin Actions
- **Search & Filter**: Find participants by name, email, or nickname. Filter by specific eligibility blockers (e.g., "Missing Baseline").
- **Update Payment**: Quick link to verify or adjust payment status.
- **Disqualify**: Manually disqualify a participant (e.g., for rules violations). Requires a reason and is logged to audit logs.
- **Reinstate**: Reverse a disqualification. Eligibility is automatically recalculated.
- **Admin Notes**: Add internal notes to a participant record.

## Firestore Fields
The following fields in the `challengeParticipants` collection drive the dashboard:
- `paymentStatus`
- `baselineSubmitted` (Boolean)
- `status` (e.g., `active`, `joined`)
- `disqualified` (Boolean)
- `disqualificationReason` (String)
- `eligibleForPrizes` (Boolean - Cache of the computed logic)

## Security
- **View**: Restricted to users with the `admin` or `superAdmin` role via `AdminGuard`.
- **Modify**: Rules enforced in `firestore.rules` ensure only admins can update eligibility-impacting fields.

## Testing Steps
1. Navigate to **Manage Challenges** -> Select a Challenge.
2. Tap **Eligibility Dashboard**.
3. Verify summary counts match the participant list.
4. Perform a search for a known nickname.
5. Use **Actions** to disqualify a participant and verify their eligibility badge turns red/Not Eligible.
6. Reinstate the participant and verify eligibility status returns to the correct computed state.
7. Verify an entry exists in `adminAuditLogs` for each action.
