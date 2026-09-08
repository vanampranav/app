# Klaviyo integration — guide

The EleFit app now sends **events** to Klaviyo. Each event lands on the person's
Klaviyo **profile** (matched by email — the same profile your Shopify store
created, no duplicates). You (marketing) turn those events into automated emails
by building **Flows**.

- **App/challenges → events → Klaviyo → your Flows → emails.**
- Push notifications still go through OneSignal. Klaviyo is **email/SMS only**.

---

## Part A — one-time setup (developer)

1. In Klaviyo: **Settings → API keys → Create Private API Key**. Give it access
   to **Events** and **Profiles** (full access is fine). Copy the `pk_…` key.
2. Store it as a secret and deploy the functions (run in the repo root):
   ```bash
   firebase functions:secrets:set KLAVIYO_API_KEY      # paste the pk_… key
   firebase deploy --only functions:default
   ```
3. That's it — no app update is needed. Events start flowing on the next signup /
   challenge action.

> The private key lives **only** on the server (Firebase secret). It is never in
> the app, so it can't leak to users.

---

## Part B — the events the app sends

Each event carries **properties** you can use inside emails and for conditional
splits. All are attached to the user's profile by email.

| Event (metric name) | Fires when… | Key properties |
|---|---|---|
| **Signed Up (App)** | a new user account is created in the app | `source`, `userId` |
| **Joined Challenge** | a user joins a challenge | `challengeName`, `packageName`, `amountDue`, `currency` |
| **Challenge Payment Submitted** | user uploads payment proof | `challengeName`, `amount`, `method` |
| **Challenge Payment Approved** | admin approves the payment | `challengeName` |
| **Challenge Payment Rejected** | admin rejects the payment | `challengeName`, `reason` |
| **Challenge Activated** | participant becomes active (in the challenge) | `challengeName` |
| **Challenge Baseline Submitted** | user submits their baseline measurements | `challengeName`, `type` |
| **Challenge Weekly Check-in** | user submits a weekly check-in | `challengeName`, `type` |
| **Challenge Final Submitted** | user submits their final measurements | `challengeName`, `type` |
| **Challenge Disqualified** | participant is disqualified | `challengeName`, `reason` |
| **Challenge Result** | a final placement/award is set | `challengeName`, `placement`, `awardLabel` |

---

## Part C — how you (marketing) use it

### 1. Confirm events are arriving
- After setup, sign up a test account (or join a test challenge). In Klaviyo, open
  that person's **profile → Activity Feed** — you'll see the event (e.g. *Joined
  Challenge*) with its properties.
- Events also appear under **Analytics → Metrics** once they've fired at least once.

### 2. Build a Flow for an event
- **Flows → Create Flow → Build your own → Metric trigger** → pick the event
  (e.g. *Signed Up (App)*).
- Add an **Email** action → design the message → set it Live.
- Example welcome flow: trigger *Signed Up (App)* → wait 5 min → send "Welcome to
  EleFit 🎉".

### 3. Use the event properties
Inside a Flow you can:
- **Personalize** an email with a property, e.g. `{{ event.challengeName }}` or
  `{{ event.packageName }}`.
- **Conditional split** on a property, e.g. only send a "big challenge" email when
  `amountDue` is over a threshold, or branch by `challengeName`.

### 4. Suggested Flows to start with
- **Welcome** — trigger *Signed Up (App)*.
- **Join confirmation / next steps** — trigger *Joined Challenge* (remind them to
  submit payment + baseline).
- **Payment received** — trigger *Challenge Payment Approved* ("You're in!").
- **Nudge to submit baseline** — trigger *Challenge Activated*, wait 1 day, send if
  they haven't submitted (you can suppress once *Challenge Baseline Submitted* fires).
- **Weekly encouragement** — trigger *Challenge Weekly Check-in*.
- **Results / congrats** — trigger *Challenge Result* (personalize with `placement`
  / `awardLabel`).

---

## Part D — important: consent (so emails actually send)

Klaviyo will **not send marketing emails to someone who hasn't consented** to
email marketing.

- **Shopify customers** who opted in at checkout are already subscribed — those
  Flows will send.
- **App-only signups** (people who never bought on Shopify) may not be subscribed
  yet. To email them you need either:
  - a **marketing-consent checkbox at app signup** (ask the dev to add it — then we
    can subscribe them automatically), or
  - set the welcome message as a **transactional** flow (allowed without marketing
    consent, but keep it non-promotional).

When in doubt, check the profile in Klaviyo — it shows the email **subscription
status**. If it's "Never Subscribed", a marketing Flow won't send to them.

---

## Part E — testing checklist
1. Dev sets `KLAVIYO_API_KEY` + deploys (Part A).
2. Create a test user in the app → check the profile's Activity Feed for *Signed
   Up (App)*.
3. Join a test challenge → check for *Joined Challenge*.
4. Build a simple Flow on *Signed Up (App)* → send yourself the welcome email.
5. Once happy, build the rest of the Flows (Part C).

Questions or a new event you want the app to send? Ask the dev — adding a new
event is a small server change (no app update).
