# EleFit Cloud Functions

## `sendChallengePush`
Fires on every new document in the `notifications` collection and sends a
OneSignal push to that notification's `recipientUserId`.

**Only challenge participants ever get a challenge push** — the `notifications`
collection is challenge-only and every doc is addressed to one participant, so a
user who isn't in any challenge has no notification doc and receives nothing.

Targeting relies on the app calling `OneSignal.login(firebaseUid)` at sign-in
(wired in `AuthService`), which sets the OneSignal `external_id` alias to the same
Firebase uid stored in `recipientUserId`.

## One-time setup / deploy

1. Install deps:
   ```bash
   cd functions && npm install
   ```

2. Set the OneSignal **REST API Key** as a secret (get it from OneSignal
   dashboard → Settings → **Keys & IDs** → *REST API Key*):
   ```bash
   firebase functions:secrets:set ONESIGNAL_REST_API_KEY
   ```
   (Paste the key when prompted. The App ID is already inline in `index.js`.)

3. Deploy:
   ```bash
   firebase deploy --only functions
   ```

## After deploy
- **Existing users must sign in once more** so `OneSignal.login(uid)` runs and
  their device gets the `external_id` alias. New logins set it automatically.
- Verify in OneSignal dashboard → **Audience** that users show an `external_id`.
- Watch logs: `firebase functions:log --only sendChallengePush`.

## Gotchas
- **Endpoint + auth:** uses the new API base `https://api.onesignal.com/notifications`
  with `Authorization: Key <REST_API_KEY>` — the correct combo for new-format
  `os_v2_app_...` keys. (The legacy `onesignal.com/api/v1/notifications` + `Basic`
  is only for old short keys and 401s with the new keys.)
- A log line `OneSignal push not delivered … has no subscribed device` is normal
  for a user who hasn't granted push permission yet — not a failure.
- iOS delivery requires APNs (p8 key) configured in the OneSignal dashboard;
  Android requires the FCM sender. These are OneSignal-console settings, not code.
