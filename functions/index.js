// Cloud Function: turn every challenge notification into a OneSignal push.
//
// WHY THIS IS SAFE FOR NON-PARTICIPANTS:
// The `notifications` collection is used ONLY by the challenge feature, and
// every notification is created addressed to a SPECIFIC participant
// (`recipientUserId`). This function pushes to that one recipient's OneSignal
// alias only. A user who is not part of any challenge never has a notification
// document, so they never receive a challenge push.
//
// Targeting works because the app calls `OneSignal.login(firebaseUid)` on
// sign-in (see AuthService), which sets the OneSignal `external_id` alias to the
// same Firebase uid stored in `recipientUserId`.

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

// The OneSignal App ID is public (it already ships in the app), so it is fine
// inline. The REST API Key is a SECRET and must be set with:
//   firebase functions:secrets:set ONESIGNAL_REST_API_KEY
const ONESIGNAL_APP_ID = "729c9710-46cf-4b96-8b51-427f3bf8dbda";
const ONESIGNAL_REST_API_KEY = defineSecret("ONESIGNAL_REST_API_KEY");

exports.sendChallengePush = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    secrets: [ONESIGNAL_REST_API_KEY],
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const n = snap.data() || {};

    const recipient = n.recipientUserId;
    if (!recipient) {
      logger.warn("Notification missing recipientUserId — skipping push", {
        id: event.params.notificationId,
      });
      return;
    }

    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      // Target ONLY this participant by their external_id alias.
      include_aliases: { external_id: [String(recipient)] },
      headings: { en: n.title || "EleFit" },
      contents: { en: n.body || "" },
      data: {
        challengeId: n.challengeId || null,
        type: n.type || null,
        deepLink: n.deepLink || null,
        notificationId: event.params.notificationId,
      },
    };

    try {
      const res = await fetch("https://api.onesignal.com/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          // New-format OneSignal keys (os_v2_app_...) require "Key", not "Basic".
          Authorization: `Key ${ONESIGNAL_REST_API_KEY.value()}`,
        },
        body: JSON.stringify(payload),
      });

      const result = await res.json().catch(() => ({}));
      if (!res.ok || (result.errors && result.errors.length)) {
        // A common, non-fatal "error" is that the recipient has no subscribed
        // device yet (never granted push permission) — log and move on.
        logger.warn("OneSignal push not delivered", {
          status: res.status,
          recipient,
          errors: result.errors || null,
        });
      } else {
        logger.info("OneSignal push sent", {
          recipient,
          onesignalId: result.id || null,
          recipients: result.recipients ?? null,
        });
      }
    } catch (e) {
      logger.error("OneSignal push exception", { error: String(e) });
    }
  }
);
