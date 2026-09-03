# Feature Roadmap

_Future features to build. Living document — add new ideas here. Last updated: 2026-08-31._
_Bugs/fixes live in [BUG_BACKLOG.md](./BUG_BACKLOG.md). This file is for NEW features._

Areas: **App** = Flutter · **BE** = Python AI backend · **Web** = the-elefit-nextjs · **Fn** = Firebase Cloud Functions · **Ops** = console/3rd-party.

---

## 1. Guided join → onboarding flow (make the user's steps effortless)  ·  App

**Problem:** After a user joins, they land on the challenge dashboard and have to figure out the next step themselves (pay → wait for approval → baseline → weekly check-ins). It's not obvious what to do next.

**Goal:** Walk the user through each next step automatically, with clear "what's next" prompts and "waiting for approval" states, so they never wonder what to do.

**Current flow (as built):**
`Discover → Detail → nickname + rules → select package → join → Dashboard` (then the user must self-navigate to Submit Payment Proof → wait → Submit Baseline → …).

**Desired flow:**
- On successful join → route straight to the **payment step** (don't dump on the dashboard).
- After payment submitted → a clear **"Payment under review — we'll notify you"** state.
- Once admin approves payment + participant (status `active`) → a prompt/redirect to **Submit Baseline**.
- After baseline approved → surface **weekly check-ins** with a "next check-in" nudge.
- A persistent **progress/stepper** on the dashboard ("Step 2 of 5: Payment") so status is always visible.

**Dependencies / notes:** This flow is **coupled to the payment model** (see #3 Stripe). If Stripe lands, the payment step changes from "upload proof + wait for admin" to "pay in-app → instant activation" — which removes a wait and simplifies the flow.

**Status:** ✅ v1 DONE (2026-08-31, `flutter analyze` clean; pending build). Built on the current manual-payment model:
- **"Your next step" card** at the top of `participant_challenge_dashboard_screen.dart` — always shows the single next action (pay → wait → baseline → weekly → final) with a one-tap CTA, plus reassuring "under review / waiting for approval" states. Covers the whole journey, so a user returning after an admin approval + notification always knows what to do.
- **Redirect after join** — `challenge_detail_screen.dart` now routes straight to the payment screen after a successful join (dashboard underneath; free packages skip it).
- **Stripe swap point:** only the card's "Submit your payment" CTA changes when Stripe lands — the rest is model-agnostic.

---

## 2. Workout logging + exercise animations/demos  ·  App (+ Ops for media)

**Goal:** Turn the AI Coach's plain-text workout into an interactive, trackable routine:
- Each exercise shows a **demo animation/GIF** (tap for instructions, target muscles, equipment).
- User can **check off** completed exercises (tie completion into `StreakService`).
- User can **add / edit / remove** exercises in their routine (pick from a catalog or add custom).

**Media source (researched — see the comparison demo):**
- **Free / static:** free-exercise-db (~800 exercises, 2 static frames, public-domain data; image license unconfirmed).
- **Paid / animated:** WorkoutX (1,327 exercises, smooth GIFs, watermark on free tier — removed at $9.99/mo, commercial use w/ attribution) or FitGif (GIF + 60fps video).
- **Recommended architecture:** build the catalog **once** into our **own Firebase Storage** (keep the API key server-side; verify vendor TOS allows caching), enrich metadata (muscles/equipment) from free-exercise-db.
- **Decision pending:** which source (leaning WorkoutX paid for animation quality vs free-exercise-db for $0).

**Build phases:**
- **Phase 0:** one-time catalog builder → download chosen media into Firebase Storage + an `exercises` catalog (Firestore or bundled JSON).
- **Phase 1:** structured routine model (`RoutineExercise{ name, sets, reps, gifUrl?, muscles?, completed, isCustom }`) + a mapping layer (AI's exercise names → catalog entries for GIFs).
- **Phase 2:** exercise detail sheet with animation + completion checkboxes + a "Today's Workout" card (Home/Performance) wired to streaks.
- **Phase 3:** add / edit / delete exercises (catalog search or free-text custom).

**Status:** Researched; source not yet chosen. Comparison demo built (`scratchpad/workout-source-comparison.html`).

---

## 2b. Body-data history + two-reading comparison (FitDays-style)  ·  App

**Goal:** Let users see *when* each weight/body-composition reading was taken and compare any two readings across every metric with the change (delta) — like FitDays' "Body Data Comparison Report".

**Status:** ✅ BUILT (2026-09-02, `flutter analyze` clean on all new files). Built entirely on existing local data (`MemberService` history in SharedPreferences, `BodyMeasurement` 20-field model) — no new storage, no dependency added.
- `lib/models/body_metrics_catalog.dart` — `BodyMetricDef` reading from any `BodyMeasurement` (+ `Member` for gender/age bands); 17 metrics with health-range colors; derived kg-mass metrics (fat/lean/muscle/water/protein mass) recomputed per reading from that reading's weight × stored %.
- `lib/screens/body_history_screen.dart` — custom month calendar (per-day weight value, spillover dimmed, month nav), selected-day reading cards, single-reading detail sheet (all metrics + colored status), and a "Data comparison" selection mode (pick any two → report). Selection persists across months.
- `lib/screens/body_comparison_report_screen.dart` — header (days-apart, weight/fat headline deltas) + From→To→Δ table over the catalog, directional arrows (up=warm, down=cool), nulls shown as "--".
- Entry point: a calendar icon in `MeasurementScreen`'s app bar → `BodyHistoryScreen`. The existing weight screen is otherwise untouched.

**Follow-ups:**
- ✅ DONE (2026-09-03) **Per-metric trend line** — `lib/screens/body_trend_screen.dart`: metric chip selector + fl_chart line chart of any metric over all readings (latest/change/low/high summary, date-labelled, touch tooltips, handles nulls & <2-point cases). Entry: `show_chart` icon in `BodyHistoryScreen` top bar, and tap any metric in the reading-detail sheet to open that metric's trend.
- ✅ DONE (2026-09-03) **Share report as image** — `BodyComparisonReportScreen` now captures itself via built-in `RepaintBoundary` → PNG (via `path_provider`) → OS share sheet (`share_plus: ^10.1.4`, the only new dependency; capture needs no extra package). Share button in the app bar + a bottom "Share report" button. (Save-to-gallery is reachable via the share sheet; a dedicated gallery-save would need `gal`/permissions — not added.)
  - Note: iPad share-sheet popover origin (`sharePositionOrigin`) not set — fine on phones; add if iPad support is needed.
- TODO (optional housekeeping): adopt the shared catalog inside `MeasurementScreen` to de-duplicate its inline metric defs.

---

## 3. Stripe in-app payments  ·  App + Fn/BE + Ops

**Goal:** Let users pay the challenge entry fee **directly in the app via Stripe** and be enrolled automatically — replacing today's manual "upload payment proof → admin approves" flow.

**Why:** Removes the manual admin approval bottleneck, removes the "payment under review" wait, and makes the join flow instant → far better UX (and fewer support issues).

**How it changes the flow:**
`Join → select package → Stripe checkout (in-app) → payment succeeds → participant auto-set to paid/active → straight to baseline.`
No proof upload, no admin payment approval needed for the happy path.

**What it needs:**
- **Stripe account** + keys (publishable key in app, **secret key server-side only**).
- **`flutter_stripe`** SDK (Payment Sheet) in the app.
- **Server endpoint** (Cloud Function or the FastAPI backend) to create a **PaymentIntent** for the selected package price/currency — never create it client-side, and never expose the secret key.
- **Stripe webhook** (`payment_intent.succeeded`) → server verifies the event signature → marks the participant `paid` + `active` (+ writes a `PaymentRecord`). Verify server-side; don't trust the client's "success" callback alone.
- **Currency handling:** packages already carry price + currency (USD / INR); Stripe supports both. Consider India (Stripe India / UPI) vs US.
- **Refunds / failures:** handle failed/cancelled payments, and a refund path (ties to withdraw).
- **Keep manual/offline payment** as a fallback option for regions/users where card isn't viable.

**Security notes:** secret key server-side only; PaymentIntent amount computed server-side from the package (never trust a client-sent amount); webhook signature verification is mandatory.

**Status:** Not started. **Recommended to build before finalizing #1 (guided flow)**, since it reshapes the payment step.

---

## 4. Notification tap-through deep-linking (challenge pushes)  ·  App

**Goal:** Tapping a challenge push should open the specific screen (leaderboard / weekly check-in / final / dashboard), not just the app. In-app notification-center deep-linking exists; the OneSignal push click handler currently ignores the challenge `deepLink`. Add `NavigationService` methods that route by `challengeId` + `deepLink`.

**Status:** Not started (follow-up from the push-notification work).

---

## 5. Auto-refresh leaderboard on disqualify/reject  ·  App

**Goal:** Instantly remove a disqualified user from the leaderboard without the admin tapping "Refresh Leaderboard." Requires injecting `LeaderboardService` into the reject/disqualify paths (needs provider reordering in `main.dart`). The core exclusion + server-read fix is already done (BUG_BACKLOG #4); this is the convenience layer.

**Status:** Optional follow-up.

---

## Suggested build order
1. **Stripe payments (#3)** — reshapes the join/payment model.
2. **Guided join flow (#1)** — build once, on the final payment model.
3. **Workout logging + animations (#2)** — pick source, then Phases 0→3.
4. Polish: notification deep-linking (#4), auto-refresh leaderboard (#5).
