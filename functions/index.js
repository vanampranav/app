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

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

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

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN REVIEW NOTIFICATIONS
//
// A user can only create notifications addressed to THEMSELVES (Firestore rules),
// so telling admins "someone needs your approval" must happen server-side. These
// triggers fire when a user does something that needs admin action (joins,
// submits payment proof, or submits/resubmits a measurement) and write an
// admin-addressed notification for every admin. The existing sendChallengePush
// trigger then turns each of those into a OneSignal push automatically.

// Admins are users with isAdmin == true OR role in {admin, superAdmin} (mirrors
// the isAdmin() Firestore rule).
async function getAdminUserIds() {
  const db = admin.firestore();
  const ids = new Set();
  try {
    const q1 = await db.collection("users").where("isAdmin", "==", true).get();
    q1.forEach((d) => ids.add(d.id));
  } catch (e) {
    logger.warn("getAdminUserIds isAdmin query failed", { error: String(e) });
  }
  try {
    const q2 = await db
      .collection("users")
      .where("role", "in", ["admin", "superAdmin"])
      .get();
    q2.forEach((d) => ids.add(d.id));
  } catch (e) {
    logger.warn("getAdminUserIds role query failed", { error: String(e) });
  }
  return [...ids];
}

async function getChallengeTitle(challengeId) {
  if (!challengeId) return "a challenge";
  try {
    const doc = await admin
      .firestore()
      .collection("challenges")
      .doc(challengeId)
      .get();
    return doc.exists && doc.data().title ? doc.data().title : "a challenge";
  } catch (_) {
    return "a challenge";
  }
}

// Writes one notification per admin. Each write re-triggers sendChallengePush,
// which delivers the OneSignal push to that admin's device.
async function notifyAdmins({ title, body, challengeId, data }) {
  const adminIds = await getAdminUserIds();
  if (!adminIds.length) {
    logger.warn("notifyAdmins: no admin users found — nothing sent");
    return;
  }
  const db = admin.firestore();
  const col = db.collection("notifications");
  const batch = db.batch();
  for (const uid of adminIds) {
    batch.set(col.doc(), {
      recipientUserId: uid,
      challengeId: challengeId || null,
      title,
      body,
      type: "adminReviewNeeded",
      category: "admin",
      priority: "high",
      data: data || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  logger.info("notifyAdmins sent", { admins: adminIds.length, title });
}

function humanSubmissionType(t) {
  if (t === "weeklyCheckIn") return "weekly check-in";
  if (t === "finalSubmission") return "final";
  if (t === "baseline") return "baseline";
  return "measurement";
}

// A user joined a challenge → its entry needs admin approval.
exports.notifyAdminOnParticipantJoin = onDocumentCreated(
  {
    document: "challenges/{challengeId}/participants/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const p = event.data && event.data.data ? event.data.data() : {};
    if (p.status !== "joined") return; // ignore invites / other states
    const title = await getChallengeTitle(event.params.challengeId);
    await notifyAdmins({
      title: "New participant to review",
      body: `Someone joined "${title}" and needs approval.`,
      challengeId: event.params.challengeId,
      data: { kind: "participantJoined", userId: event.params.userId },
    });
  }
);

// A user submitted payment proof (a PaymentRecord is created) → needs review.
exports.notifyAdminOnPaymentSubmit = onDocumentCreated(
  { document: "paymentRecords/{paymentId}", region: "us-central1" },
  async (event) => {
    const pay = event.data && event.data.data ? event.data.data() : {};
    if (pay.status && pay.status !== "pending") return; // only awaiting-review
    const title = await getChallengeTitle(pay.challengeId);
    await notifyAdmins({
      title: "Payment proof to review",
      body: `A participant submitted payment proof for "${title}".`,
      challengeId: pay.challengeId,
      data: { kind: "paymentSubmitted", userId: pay.userId || null },
    });
  }
);

// A user submitted a baseline/weekly/final measurement → needs review.
exports.notifyAdminOnSubmission = onDocumentCreated(
  { document: "challengeSubmissions/{submissionId}", region: "us-central1" },
  async (event) => {
    const s = event.data && event.data.data ? event.data.data() : {};
    if (s.reviewStatus !== "submitted") return;
    const title = await getChallengeTitle(s.challengeId);
    await notifyAdmins({
      title: "New submission to review",
      body: `A ${humanSubmissionType(s.type)} submission for "${title}" needs review.`,
      challengeId: s.challengeId,
      data: { kind: "submission", submissionType: s.type, userId: s.userId || null },
    });
  }
);

// A user RESUBMITTED (edited an existing submission back to "submitted").
exports.notifyAdminOnResubmission = onDocumentUpdated(
  { document: "challengeSubmissions/{submissionId}", region: "us-central1" },
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : {};
    const after = event.data && event.data.after ? event.data.after.data() : {};
    if (after.reviewStatus !== "submitted" || before.reviewStatus === "submitted") {
      return; // only fire on a transition INTO "submitted"
    }
    const title = await getChallengeTitle(after.challengeId);
    await notifyAdmins({
      title: "Resubmission to review",
      body: `A ${humanSubmissionType(after.type)} submission for "${title}" was resubmitted.`,
      challengeId: after.challengeId,
      data: { kind: "resubmission", submissionType: after.type, userId: after.userId || null },
    });
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// KLAVIYO MARKETING EVENTS
//
// Fire events into Klaviyo so the marketing team's Flows send the emails.
// These are SEPARATE functions from the OneSignal push ones above — a Klaviyo
// failure only affects Klaviyo (logged), never push or the app's Firestore
// writes. The private key is a secret:  firebase functions:secrets:set KLAVIYO_API_KEY
// See docs/KLAVIYO_GUIDE.md for the full event list + how marketing uses it.
// ═════════════════════════════════════════════════════════════════════════════
const { trackEvent } = require("./klaviyo");
const functionsV1 = require("firebase-functions/v1");
const KLAVIYO_API_KEY = defineSecret("KLAVIYO_API_KEY");

// Klaviyo profiles are keyed by email; look it up from users/{uid}. (Emails
// dedupe against the Shopify-synced profiles automatically — no duplicates.)
async function getUserContact(userId) {
  if (!userId) return null;
  try {
    const snap = await admin.firestore().collection("users").doc(userId).get();
    if (!snap.exists) return null;
    const u = snap.data() || {};
    const email = String(u.email || "").toLowerCase().trim();
    if (!email) return null;
    const name = u.name || u.fullName || u.displayName || "";
    return {
      email,
      first_name: u.firstName || u.first_name || (name ? String(name).split(" ")[0] : undefined),
      last_name: u.lastName || u.last_name || undefined,
    };
  } catch (e) {
    logger.error("Klaviyo getUserContact failed", { userId, error: String(e) });
    return null;
  }
}

// New app user → "Signed Up (App)". A Firebase Auth onCreate trigger, so it
// fires for EVERY new user (email/password signups AND Shopify-bridge users).
// (The base app doesn't create a users/{uid} doc on signup, so we key off Auth.)
exports.klaviyoOnSignup = functionsV1
  .runWith({ secrets: ["KLAVIYO_API_KEY"] })
  .auth.user()
  .onCreate(async (user) => {
    const email = String(user.email || "").toLowerCase().trim();
    if (!email) return;
    const name = user.displayName || "";
    await trackEvent(process.env.KLAVIYO_API_KEY, {
      metric: "Signed Up (App)",
      email,
      profileProps: { first_name: name ? name.split(" ")[0] : undefined },
      properties: { source: "elefit_app", uid: user.uid },
      uniqueId: `signup_${user.uid}`,
    });
  });

// Joined a challenge → "Joined Challenge".
exports.klaviyoOnParticipantJoin = onDocumentCreated(
  {
    document: "challenges/{challengeId}/participants/{userId}",
    region: "us-central1",
    secrets: [KLAVIYO_API_KEY],
  },
  async (event) => {
    const p = event.data && event.data.data ? event.data.data() : {};
    const contact = await getUserContact(event.params.userId);
    if (!contact) return;
    const title = await getChallengeTitle(event.params.challengeId);
    await trackEvent(KLAVIYO_API_KEY.value(), {
      metric: "Joined Challenge",
      email: contact.email,
      profileProps: { first_name: contact.first_name, last_name: contact.last_name },
      properties: {
        challengeId: event.params.challengeId,
        challengeName: title,
        packageName: p.selectedPackageName || null,
        amountDue: p.amountDue != null ? p.amountDue : null,
        currency: p.currency || null,
      },
      uniqueId: `join_${event.params.challengeId}_${event.params.userId}`,
    });
  }
);

// Payment proof submitted → "Challenge Payment Submitted".
exports.klaviyoOnPaymentSubmit = onDocumentCreated(
  { document: "paymentRecords/{paymentId}", region: "us-central1", secrets: [KLAVIYO_API_KEY] },
  async (event) => {
    const pay = event.data && event.data.data ? event.data.data() : {};
    const contact = await getUserContact(pay.userId);
    if (!contact) return;
    const title = await getChallengeTitle(pay.challengeId);
    await trackEvent(KLAVIYO_API_KEY.value(), {
      metric: "Challenge Payment Submitted",
      email: contact.email,
      properties: {
        challengeId: pay.challengeId || null,
        challengeName: title,
        amount: pay.amount != null ? pay.amount : null,
        method: pay.paymentMethod || null,
      },
      uniqueId: `paysub_${event.params.paymentId}`,
    });
  }
);

// Baseline / weekly / final submission created → a typed event.
exports.klaviyoOnSubmission = onDocumentCreated(
  { document: "challengeSubmissions/{submissionId}", region: "us-central1", secrets: [KLAVIYO_API_KEY] },
  async (event) => {
    const s = event.data && event.data.data ? event.data.data() : {};
    if (s.reviewStatus !== "submitted") return;
    const contact = await getUserContact(s.userId);
    if (!contact) return;
    const title = await getChallengeTitle(s.challengeId);
    const metric =
      s.type === "baseline" ? "Challenge Baseline Submitted"
      : s.type === "weeklyCheckIn" ? "Challenge Weekly Check-in"
      : s.type === "finalSubmission" ? "Challenge Final Submitted"
      : "Challenge Submission";
    await trackEvent(KLAVIYO_API_KEY.value(), {
      metric,
      email: contact.email,
      properties: { challengeId: s.challengeId || null, challengeName: title, type: s.type || null },
      uniqueId: `sub_${event.params.submissionId}`,
    });
  }
);

// Participant transitions → approval / activation / disqualification / result.
exports.klaviyoOnParticipantUpdate = onDocumentUpdated(
  {
    document: "challenges/{challengeId}/participants/{userId}",
    region: "us-central1",
    secrets: [KLAVIYO_API_KEY],
  },
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : {};
    const after = event.data && event.data.after ? event.data.after.data() : {};

    const fire = async (metric, extra, idSuffix) => {
      const contact = await getUserContact(event.params.userId);
      if (!contact) return;
      const title = await getChallengeTitle(event.params.challengeId);
      await trackEvent(KLAVIYO_API_KEY.value(), {
        metric,
        email: contact.email,
        properties: {
          challengeId: event.params.challengeId,
          challengeName: title,
          ...(extra || {}),
        },
        uniqueId: `${metric.replace(/\s+/g, "_")}_${event.params.challengeId}_${event.params.userId}${idSuffix || ""}`,
      });
    };

    if (before.paymentStatus !== "paid" && after.paymentStatus === "paid") {
      await fire("Challenge Payment Approved");
    }
    if (before.paymentStatus !== "failed" && after.paymentStatus === "failed") {
      await fire("Challenge Payment Rejected", { reason: after.paymentFailureReason || null });
    }
    if (before.status !== "active" && after.status === "active") {
      await fire("Challenge Activated");
    }
    if (!before.disqualified && after.disqualified === true) {
      await fire("Challenge Disqualified", { reason: after.disqualificationReason || null });
    }
    if (!before.finalPlacement && after.finalPlacement) {
      await fire(
        "Challenge Result",
        { placement: after.finalPlacement, awardLabel: after.awardLabel || null },
        `_${after.finalPlacement}`
      );
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// syncShopifyPassword: sets a Shopify customer's Firebase password to their
// Shopify password (mirrors the coach app's intent, but reliably, server-side).
//
// Called by the app's login bridge after the app has authenticated the user
// against Shopify. This function RE-VALIDATES the Shopify access token itself
// (so the client can't lie about who they are) and only then updates the
// password. If the Firebase user doesn't exist yet, it is created.
//
// The Storefront token is public (it ships in the app), so it's inline.
const SHOPIFY_STORE_URL = "theelefit.com";
const SHOPIFY_STOREFRONT_TOKEN = "3476fc91bc4860c5b02aea3983766cb1";
const SHOPIFY_BRIDGE_SALT = "EleFit_Bridge_2026_Secure_";

function normalizeShopifyId(id) {
  const s = String(id || "");
  return s.includes("gid://shopify/Customer/") ? s.split("/").pop() : s;
}

// Validates a Shopify customer access token → returns { id, email } or null.
async function validateShopifyToken(accessToken) {
  const query =
    "query($t: String!){ customer(customerAccessToken:$t){ id email } }";
  const res = await fetch(`https://${SHOPIFY_STORE_URL}/api/2024-01/graphql`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Shopify-Storefront-Access-Token": SHOPIFY_STOREFRONT_TOKEN,
    },
    body: JSON.stringify({ query, variables: { t: accessToken } }),
  });
  const json = await res.json().catch(() => ({}));
  return json?.data?.customer || null;
}

// mintFirebaseToken: exchanges a validated Shopify identity for a Firebase
// CUSTOM TOKEN. The caller re-validates the Shopify access token (so the client
// can't lie), then we mint a token for that user's uid — WITHOUT touching their
// password. This is the reliable, non-destructive replacement for the old
// password-sync approach: it works for every account (bridge, real, or diverged)
// and never breaks the coach app's bridge auto-login.
exports.mintFirebaseToken = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "POST only" });
    }
    const { email, shopifyAccessToken } = req.body || {};
    if (!email || !shopifyAccessToken) {
      return res
        .status(400)
        .json({ error: "email and shopifyAccessToken are required" });
    }
    const normalizedEmail = String(email).toLowerCase().trim();
    try {
      const customer = await validateShopifyToken(shopifyAccessToken);
      if (!customer || (customer.email || "").toLowerCase() !== normalizedEmail) {
        return res.status(401).json({ error: "Shopify validation failed" });
      }

      let uid;
      let created = false;
      try {
        uid = (await admin.auth().getUserByEmail(normalizedEmail)).uid;
      } catch (e) {
        if (e.code === "auth/user-not-found") {
          // New Shopify customer: create with the bridge password so the coach
          // app's session-transfer auto-login also keeps working for them.
          const bridgePw =
            SHOPIFY_BRIDGE_SALT + normalizeShopifyId(customer.id);
          uid = (
            await admin
              .auth()
              .createUser({ email: normalizedEmail, password: bridgePw })
          ).uid;
          created = true;
        } else {
          throw e;
        }
      }

      const token = await admin.auth().createCustomToken(uid);
      logger.info("mintFirebaseToken ok", { email: normalizedEmail, uid, created });
      return res.json({ ok: true, token, uid, created });
    } catch (e) {
      logger.error("mintFirebaseToken error", { error: String(e) });
      return res.status(500).json({ error: "Internal error" });
    }
  }
);
