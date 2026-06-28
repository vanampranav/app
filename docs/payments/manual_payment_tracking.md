# Manual Payment Tracking

This document describes the business workflow and technical implementation for tracking manual challenge payments in the EleFit platform.

## Business Workflow

1. **Enrollment**: A user joins a challenge and selects a package.
2. **Initial State**:
   - `paymentStatus` = `pending`
   - `eligibleForPrizes` = `false`
   - `amountDue` = price of the selected package.
3. **Offline Payment**: The user sends payment via an out-of-band method (Zelle, Venmo, Cash, UPI, etc.).
4. **Admin Verification**: An admin receives the funds and locates the participant in the **Admin Payment Tracking** screen.
5. **Update**: Admin marks the participant as `paid`, enters the amount collected, payment method, and optional reference number/notes.
6. **Activation**:
   - `paymentStatus` = `paid`
   - `eligibleForPrizes` = `true` (enabling them to win official prizes).
   - `paidAt` timestamp is recorded.
   - An automated in-app notification is sent to the participant.

## Submission & Review Lifecycle

1. **Initial Submission**: Participant uses `ParticipantPaymentSubmissionScreen` to provide first-time proof.
   - Creates a new `PaymentRecord` document.
   - Sets `paymentStatus` = `pending_review` in the Participant record.
   - Links the record via `latestPaymentRecordId` in the Participant record.
2. **Admin Review**: Admin verifies data.
   - Updates both the Participant record AND the linked `PaymentRecord`.
3. **Failure Recovery**: If verification fails, participant must use `ParticipantPaymentRecoveryScreen`.
   - Creates a **new** `PaymentRecord` for the attempt.
   - Updates the Participant record snapshot and `latestPaymentRecordId`.
   - The initial submission screen is locked once any proof is submitted to prevent data overwrites.

## Payment Status States & Dashboard Behavior

The Participant Dashboard and Payment Tracking system adhere to the following status logic:

| Status | User Dashboard Label | Proof Submission | Prize Eligibility |
| :--- | :--- | :--- | :--- |
| `paid` | **Verified** (Checkmark) | Hidden | Yes |
| `waived` | **Verified** (Checkmark) | Hidden | Yes |
| `pending` | **Pending Verification** | Hidden | No |
| `failed` | **Verification Failed** (Error) | Enabled | No |
| `pending_review` | **Pending Review** (Hourglass) | Hidden | No |

## Payment Status Downgrade (e.g., Paid → Pending)

If an admin manually changes a status from `paid` or `waived` back to a non-eligible status (e.g., `pending`, `failed`):
- `eligibleForPrizes` is immediately recalculated to `false`.
- `paidAt` timestamp is cleared (`null`) to ensure accuracy of realized revenue metrics.
- `verifiedByAdminId` is updated to reflect the admin who performed the downgrade.
- The Participant Dashboard reflects the change in real-time via Firestore snapshots.

## Failed Payment Recovery Flow

If an admin cannot verify a payment (e.g., wrong reference, amount mismatch):

1. **Admin Action**: Admin marks `paymentStatus` as `failed` and provides a mandatory `paymentFailureReason`.
2. **Notification**: The participant receives a "High Priority" notification about the failure.
3. **Dashboard Update**: The participant's challenge dashboard shows a "Verification Failed" card with the admin's reason.
4. **Resubmission**: The participant taps "Submit Payment Proof" to provide:
   - Updated Reference Number.
   - Additional Notes.
   - Optional Screenshot (uploaded to Firebase Storage).
5. **Pending Review**: Upon submission:
   - `paymentStatus` becomes `pending_review`.
   - Participant dashboard reflects that proof has been submitted.
6. **Admin Verification**: The admin sees the `pending_review` status and the provided proof in the Payment Tracking screen and can then approve or fail it again.

## Firestore Schema

### Collection: `challenges/{challengeId}/participants/{userId}`

Additional payment tracking fields:

| Field | Type | Description |
| :--- | :--- | :--- |
| `paymentStatus` | `String` | Single source of truth: `pending`, `pending_review`, `partiallyPaid`, `paid`, `waived`, `refunded`, `failed`. |
| `latestPaymentRecordId`| `String` | ID of the most recent `PaymentRecord` submitted for review. |
| `paymentMethod` | `String` | `manual`, `cash`, `zelle`, `venmo`, `paypal`, `upi`, `stripe`. |
| `amountDue` | `Double` | Total amount the user is expected to pay. |
| `amountCollected` | `Double` | Actual amount received so far. |
| `currency` | `String` | Currency code (e.g., "USD"). |
| `paymentReference` | `String` | External transaction ID or receipt number. |
| `paymentFailureReason` | `String` | Reason provided by admin when marking as failed. |
| `paymentProofUrl` | `String` | URL to a screenshot uploaded by the user during recovery. |
| `paymentProofSubmittedAt`| `Timestamp`| When the user resubmitted their proof. |
| `paidAt` | `Timestamp` | When the payment was fully cleared. |
| `paymentNotes` | `String` | Internal admin notes regarding payment. |
| `verifiedByAdminId` | `String` | UID of the admin who verified the last update. |
| `eligibleForPrizes` | `Boolean` | Logic: `true` if status is `paid` or `waived`. |

## Security Rules

- **Admins**: Full read/write access to all participant payment fields.
- **Participants**: 
  - Read-only access to their own record.
  - Restricted write access: Can only update payment proof fields and change status from `failed` to `pending_review`.
  - Prohibited from updating `amountDue`, `amountCollected`, or `eligibleForPrizes`.

## Analytics

- `payment_status_changed`: Tracked on every admin update.
- `payment_verified`: Tracked specifically when a payment is marked as `paid`.

## Future Considerations

- **Stripe Integration**: When automated payments are added, the checkout session will use the `amountDue` and `currency` from the participant snapshot. Upon webhook success, the `paymentStatus` will be updated to `paid` automatically.
- **Multi-currency**: Currently assumes a single currency per challenge enrollment.
