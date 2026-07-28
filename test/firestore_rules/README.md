# Firestore security-rules tests (challenge feature)

These validate **`../../firestore.rules`** — the exact rules you publish in the
Firebase Console — by running them against the local Firestore **emulator**.

> The Dart tests in `test/challenge/` use `fake_cloud_firestore`, which ignores
> security rules entirely. **This suite is the only thing that actually tests
> your rules.** Run it whenever you change `firestore.rules`.

## Prerequisites (already present on this machine)
- Node.js (v18+)
- Java (17+) — needed by the emulator
- Firebase CLI — `firebase --version`

## Run
```bash
cd test/firestore_rules
npm install          # first time only
npm test
```
`npm test` runs `firebase emulators:exec --only firestore --project demo-getfit "node --test"`,
which boots the emulator, loads `../../firestore.rules`, runs every test, and
shuts the emulator down. Nothing touches your real Firebase project (the
`demo-` project id keeps it fully offline).

## What it covers
- **Notifications** — participant self-create (the join-error fix), admin create,
  cross-user denial, read scoping, mark-read field restriction, delete rules.
- **Payment first submission** (`pending → pending_review`) — allowed field set +
  sensitive-field denial.
- **Payment recovery** (`failed → pending_review`) — the `latestPaymentRecordId`
  fix; this test **fails on the old rules** and passes on the corrected ones.
- **Participant** self-create, sensitive-field protection, admin override.
- **Collection-group** read scoping (home "My Challenges" tile).
- **Challenges / submissions / payment records** owner + admin rules.
- **Packages** active-only read, **audit logs** admin-only, **profiles** widened
  read, **earlyAccessLeads** create-only.

## If a test fails
The failure message names the rule path. Compare the assertion against the
matching `match` block in `firestore.rules`. A `permission-denied` on an
`assertSucceeds` means the rule is too strict; a success on an `assertFails`
means it's too loose.
