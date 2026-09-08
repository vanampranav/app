// Klaviyo server-side helper.
//
// Sends events to Klaviyo so the marketing team's Flows can fire automated
// emails. Uses the PRIVATE API key (a Firebase secret — never shipped in the
// app). Klaviyo dedupes profiles by email, so events attach to the SAME profile
// your Shopify store already created (no duplicates).
//
// Set the key once with:
//   firebase functions:secrets:set KLAVIYO_API_KEY
// (paste a Private API key from Klaviyo → Settings → API keys)

const logger = require("firebase-functions/logger");

const KLAVIYO_API_BASE = "https://a.klaviyo.com/api";
// Klaviyo pins its API to a dated revision; bump this when you adopt a newer one.
const KLAVIYO_REVISION = "2026-07-15";

/**
 * Track a Klaviyo event (server-side), upserting the profile by email.
 * Never throws — a Klaviyo hiccup must never break the app write or push.
 *
 * @param {string} apiKey       Klaviyo private API key.
 * @param {object} opts
 * @param {string} opts.metric  Event/metric name, e.g. "Joined Challenge".
 * @param {string} opts.email   Profile email (required — Klaviyo keys on this).
 * @param {object} [opts.properties]   Event properties (shown on the event).
 * @param {object} [opts.profileProps] Standard profile attrs (first_name, last_name, phone_number…).
 * @param {string} [opts.uniqueId]     Idempotency key (safe retries / no dupes).
 * @param {string} [opts.time]         ISO8601 event time (defaults to now).
 */
async function trackEvent(apiKey, opts) {
  const { metric, email, properties = {}, profileProps = {}, uniqueId, time } = opts || {};
  if (!apiKey) {
    logger.warn("Klaviyo: KLAVIYO_API_KEY not set — skipping event", { metric });
    return;
  }
  if (!email) {
    logger.warn("Klaviyo: no email for event — skipping", { metric });
    return;
  }

  // Drop undefined profile attrs so we don't send empty keys.
  const profileAttrs = { email };
  for (const [k, v] of Object.entries(profileProps)) {
    if (v !== undefined && v !== null && v !== "") profileAttrs[k] = v;
  }

  const body = {
    data: {
      type: "event",
      attributes: {
        properties,
        metric: { data: { type: "metric", attributes: { name: metric } } },
        profile: { data: { type: "profile", attributes: profileAttrs } },
        ...(time ? { time } : {}),
        ...(uniqueId ? { unique_id: uniqueId } : {}),
      },
    },
  };

  try {
    const res = await fetch(`${KLAVIYO_API_BASE}/events/`, {
      method: "POST",
      headers: {
        Authorization: `Klaviyo-API-Key ${apiKey}`,
        revision: KLAVIYO_REVISION,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      logger.error("Klaviyo event failed", {
        metric,
        status: res.status,
        body: String(text).slice(0, 600),
      });
    } else {
      logger.info("Klaviyo event sent", { metric, email });
    }
  } catch (e) {
    logger.error("Klaviyo event error", { metric, error: String(e) });
  }
}

module.exports = { trackEvent };
