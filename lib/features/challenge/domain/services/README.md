# EleFit Challenge Domain Services

This directory contains the Service layer for the EleFit Challenge MVP, which handles the business logic and orchestrates data access through repositories.

## Architectural Rules

1. **Repositories for Data Access**: Services must **only** interact with the data layer via Repositories. They should never call `FirebaseFirestore` or other raw data sources directly.
2. **Business Rules in Services**: All validation and business logic (e.g., "users cannot join a closed challenge", "admin actions must be logged") belong in this layer.
3. **UI Interaction**: UI screens and ViewModels should call Services for any state-changing operations or complex logic. UI can call Repositories directly only for simple, read-only data streaming that requires no business logic.
4. **Auditability**: All sensitive administrative actions (approvals, rejections, manual updates) must be logged via the `AdminAuditService`.
5. **Exception Handling**: Services are responsible for validating inputs and current state, throwing clear and descriptive exceptions when business rules are violated.

## Service Inventory

- **ChallengeService**: Manages the lifecycle of challenges (Draft -> Active -> Completed).
- **ParticipantEnrollmentService**: Handles the workflow of users joining and withdrawing from challenges, as well as admin approvals.
- **SubmissionReviewService**: Orchestrates the submission of baseline and weekly data, including the admin review and approval process.
- **PaymentApprovalService**: Manages manual payment records and their verification by admins.
- **ChallengeNotificationService**: Centralizes the creation and streaming of challenge-related user notifications.
- **AdminAuditService**: Provides a centralized way to log auditable admin actions across the system.
