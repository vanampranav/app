# Participant Enrollment Model

This document describes the data structure and document identity logic for challenge enrollments in EleFit.

## Core Identity
Each enrollment is uniquely identified by the combination of `challengeId` and `userId`.
This ensures that a user can join multiple challenges concurrently without data collisions.

## Firestore Path
Enrollment records are stored as a subcollection under each challenge:

`challenges/{challengeId}/participants/{userId}`

- **Challenge ID**: Identifies the specific challenge.
- **User ID**: The unique UID of the participant.

## Data Structure (`ChallengeParticipant`)
The document contains all state relevant to that specific challenge enrollment:
- `status`: Enrollment status (joined, active, completed, etc.).
- `paymentStatus`: Current payment state for this challenge.
- `eligibleForPrizes`: Computed boolean based on payment, baseline, and status.
- `baselineSubmitted`: Tracks if the starting measurements were approved.
- `selectedPackageId`: Snapshot of the package tier selected at join time.
- `amountDue`: Financial requirement for this challenge.
- `amountCollected`: Total funds received for this challenge.

## Data Collisions & Refactoring
Previously, enrollments were stored in a top-level collection. This led to issues where joining a new challenge would overwrite the user's status in a previous challenge. 

The move to `challenges/{challengeId}/participants/{userId}` provides:
1. **Isolation**: Each challenge has its own list of participants.
2. **Efficiency**: Direct document lookups using `userId` instead of collection-wide queries.
3. **Security**: Granular rules tied to the parent challenge document.

## Querying Across Challenges
To find all challenges a specific user has joined (e.g., for the Home screen or "My Challenges" view), the app uses a **Firestore Collection Group Query** on the `participants` collection ID, filtered by `userId`.

> **Note**: This query requires a composite index: `participants` (Collection Group) with `userId` ASC.

## Security Rules
Rules are enforced at the challenge subcollection level:
- **List Participants**: Restricted to Admins only (`isAdmin()`).
- **Read Record**: Allowed for the owner (`isOwner(userId)`) or Admins (`isAdmin()`).
- **Create Enrollment**: Restricted to the authenticated user for their own record (`isOwner(userId)`).
- **Update Status/Payments**: Restricted to Admins only. Participants have a limited `update` rule for their own record that blocks modifications to sensitive fields.

```rules
match /participants/{userId} {
  allow list: if isAdmin();
  allow get: if isSignedIn() && (isOwner(userId) || isAdmin());
  allow create: if isSignedIn() && isOwner(userId);
  allow update: if isAdmin() || (isOwner(userId) && !restrictedFieldsChanged());
}
```
