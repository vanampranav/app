# Challenge Feature — Firebase Infrastructure Setup

Everything below is Firebase-side config. The app code is ready; these steps make
the queries and uploads work in production. Do them once per Firebase project.

## 1. Composite indexes (required — queries fail without them)

File: `firestore.indexes.json` (repo root). Deploy either way:

- **CLI:** `firebase deploy --only firestore:indexes`
- **Console (no CLI):** just use the app — when a query needs an index, Firestore
  throws an error in the logs with a direct "create index" link. Click each one.

Covers: submissions (userId/createdAt, challengeId/createdAt, challengeId/reviewStatus),
paymentRecords (challengeId/status), notifications (recipientUserId/createdAt,
recipientUserId/isRead/createdAt), adminAuditLogs (challengeId/createdAt,
adminId/createdAt), packages subcollection (isActive/displayOrder), and the
**collection-group** index on `participants.userId` (home "My Challenge" tile).

## 2. Storage rules (required — protects body photos & payment proofs)

File: `storage.rules` (repo root). Storage is used ONLY by the challenge feature,
so these rules cover all uploads and deny everything else.

- **CLI:** `firebase deploy --only storage`
- **Console:** Storage → Rules → paste `storage.rules` → Publish.

Enforces: a user reads/writes only their own progress photos; admins can read all;
payment proofs are admin-read only. Satisfies Rule Book §11 (photo privacy).

## 3. Firestore security rule — ADD this to your existing (deployed) rules

Your Firestore rules are managed in the console. The subcollection design needs
ONE extra rule so a signed-in user can query their own participations across all
challenges (the collection-group query behind the home "My Challenge" tile). This
is why that query currently logs `PERMISSION_DENIED`.

Add this block inside `match /databases/{database}/documents { ... }`, next to the
other top-level `match` statements (it uses your existing `isSignedIn()` and
`isAdmin()` helpers):

```
// Collection-group read: a user can query their own participant records across
// all challenges (home screen "My Challenge / Join Challenge" tile).
match /{path=**}/participants/{participantId} {
  allow read: if isSignedIn()
    && (isAdmin() || resource.data.userId == request.auth.uid);
}
```

This only GRANTS a new, tightly-scoped read (a user sees only rows where
`userId == their uid`); it does not change any of your existing write rules.

## Notes
- `firebase.json` references indexes + storage rules only — it deliberately does
  NOT reference `firestore.rules`, so a `firebase deploy` will never overwrite the
  Firestore security rules you manage in the console.
- To use the CLI you need `firebase login` and the project selected
  (`firebase use getfit-with-elefit`).
