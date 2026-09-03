# Bug Backlog

_Last updated: 2026-08-31. Surfaced during QA / debugging sessions. Severity order._

Areas: **App** = Flutter app · **BE** = Python AI backend (yantraprise.com) · **Web** = the-elefit-nextjs · **Ops** = Firestore/console/billing.

---

## 🔴 Critical (production-impacting)

### 1. AI Coach meal/workout plans were failing → users got static fallback plans  ·  BE
- **Cause:** Groq decommissioned `llama-3.3-70b-versatile` (Aug 2026); backend returned 404 on every generation and silently served hard-coded fallback plans.
- **Status:** ✅ FIXED in the deployed yantraprise.com backend — now `GROQ_MODEL = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")`. Verified `/mealplan` + `/workoutplan` generate correctly.
- **Remaining:** sync the same fix into the app-repo `backend/app.py` copy so all copies match; make model a single env-var constant everywhere.

### 2. Meal-photo analyzer (`/analyze-meal`) not working  ·  BE / Ops
- **Cause:** OpenAI account out of credits → `429 insufficient_quota / credit_balance_exhausted`; backend converts it to a 500. Only `/analyze-meal` uses OpenAI (gpt-4o-mini); everything else is Groq.
- **Status:** ✅ FIXED — OpenAI account credited; analyzer working again. (Still nice-to-have: graceful 429 handling — see #9.)

---

## 🟠 High

### 0. Rejected submissions can't be resubmitted — "You don't have permission…"  ·  Ops (Firestore rules)
- **Symptom:** A participant whose baseline (or weekly/final) submission was rejected taps "Resubmit Baseline / Update Submission" and gets *"You don't have permission to do this right now. Please sign in again and retry."*
- **Cause:** Resubmit does a Firestore **`update`** on the existing `challengeSubmissions` doc, but the rule was `allow update: if isAdmin();` — participants could only `create`, not `update`. First-time submissions (create) worked; resubmissions (update) hit `permission-denied` → mapped to that message (`challenge_error_text.dart:15`). Reproduced for the "Spider Man" participant (active, paid, `baselineSubmitted:false`).
- **Status:** ✅ FIXED & DEPLOYED (2026-09-02) — `firestore.rules` now lets an **owner** update their **own** submission only when its current `reviewStatus ∈ {rejected, needsClarification}` and only to move it back to `'submitted'` (no self-approve, no ownership change). Admin behavior unchanged. Also fixes weekly/final resubmissions. Published live via Firebase Console (minimal one-block change; rest of live rules untouched). No app rebuild needed — fixes all installed apps.
- **Verify:** have the affected user retry "Update Submission / Resubmit Baseline" → should succeed with `reviewStatus: submitted`, `resubmitCount: 1`.
- **Note:** repo `firestore.rules` carries a small pre-existing drift vs live (participants list has extra `finalPlacement`/`awardLabel`); live intentionally kept minimal. Reconcile before any future `firebase deploy --only firestore:rules`.

### 3. Black screen on "View Details" (Challenge Detail) on Android 16  ·  App
- **Cause:** Flutter **Impeller** renderer bug on new Android 16 / Vulkan GPU driver. Device-specific; the screen code is fine.
- **Status:** ✅ FIXED — added `io.flutter.embedding.android.EnableImpeller=false` to `android/app/src/main/AndroidManifest.xml` (falls back to Skia). **Pending:** clean rebuild + release a new build to the affected user. Consider updating Flutter later and removing the flag once the Impeller bug is patched upstream.

### 4. Rejected/disqualified users still appear on the leaderboard  ·  App
- **Cause A:** `leaderboard_service.dart` filtered only `withdrawn` and re-added all non-withdrawn participants as "Not started". Disqualified users were never excluded.
- **Cause B (found 2026-08):** `recomputeAndPublish` read participants via `streamParticipantsByChallenge(...).first`, which serves Firestore's **offline cache first** — so a "Refresh Leaderboard" from an admin device with a stale cache re-published a deleted participant.
- **Status:** ✅ FIXED (2026-08-31) — `flutter analyze` clean. Changes:
  1. Added `LeaderboardService._countsForLeaderboard(p)` = not `withdrawn` **and** not `disqualified` **and** not the `disqualified` flag; used in `computeStandings` (covers both the scored list and the "Not started" list) and in `recomputeAndPublish`'s name lookup. `publishStandings` already deletes stale rows, so an excluded user's row auto-clears on the next recompute.
  2. Added `ChallengeParticipantRepository.getParticipantsByChallenge()` (plain `get()`, server-preferred) and switched `recomputeAndPublish` to it — no more stale-cache re-adds.
- **Pending:** rebuild + release (bundle with the #3 Android build). After disqualifying, the leaderboard updates on the next recompute — a submission review or the admin **"Refresh Leaderboard"** button (now reliable).
- **Optional follow-up (not done — needs provider reordering):** auto-call `recomputeAndPublish` inside `rejectParticipant` / `disqualifyParticipant` so the board updates instantly without tapping Refresh.

---

## 🟡 Medium

### 5. Demo/test challenge data visible in production app  ·  Ops
- **Fix:** clean up demo challenges + subcollections (participants/packages/leaderboard) + related `challengeSubmissions` / `paymentRecords` / `notifications` in Firestore. Hide-then-delete (set status draft/cancelled → verify empty state → delete).

### 6. Backend chat moderation is broken  ·  BE
- **Cause:** `prompt_guard()` calls `client.moderations.create(model="omni-moderation-latest", ...)` on the **Groq** client (that model only exists on OpenAI) and does not `await` it → the moderation gate effectively does nothing.
- **Fix:** call on `openai_client` and `await`, or remove the gate.

### 7. Next.js web app: workout generation URL is malformed  ·  Web
- **Cause:** `https://yantraprise/workoutplan` (missing `.com`) at `app/ai-coach/calories/page.tsx:226` → web workout generation fails.
- **Fix:** correct the URL to `https://yantraprise.com/workoutplan`.

### 8. Rate limiter is per-process / in-memory  ·  BE
- **Effect:** limits effectively double across the 2 gunicorn workers, reset on restart, and don't work across multiple instances.
- **Fix:** move rate-limit state to Redis / a shared store.

---

## 🟢 Low / polish

### 9. `/analyze-meal` surfaces a raw 500 on provider failure  ·  BE
- Add graceful "meal scanning temporarily unavailable" handling instead of a raw 500 (currently a dead OpenAI account = ugly error in the app).

### 10. Meal-plan output has excessive blank lines  ·  BE
- Cosmetic (gpt-oss reasoning whitespace); parsers already skip blank lines.

### 11. Meal-plan per-item macros occasionally inaccurate  ·  BE
- Content-quality; prompt tuning. Optional.
