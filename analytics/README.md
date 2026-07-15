# EleFit Marketing Analytics (web dashboard)

A single-file, login-gated dashboard that shows your app's users (name, email,
AI-Coach status, goal, gender, age, credits, join date) so the marketing team can
plan engagement. Reads live from Firebase Firestore (`users` collection).

**Nothing is visible until someone signs in with an authorized Firebase account.**
The data is protected by your Firestore security rules — the public Netlify link
only shows a login screen.

## Files
- `index.html` — the whole app (HTML + CSS + JS in one file). That's all Netlify needs.

## 1. One-time setup — Firebase Web config
`index.html` has a `firebaseConfig` near the bottom. It's pre-filled with your
project (`getfit-with-elefit`). If sign-in fails with "api-key-not-valid" or
"requests blocked", register a Web app:

1. Firebase Console → ⚙ Project settings → **General** → **Your apps** → **Add app → Web** (`</>`).
2. Copy the generated `firebaseConfig` object.
3. Paste it over the `firebaseConfig` in `index.html` (especially `apiKey` and `appId`).

## 2. Deploy to Netlify
Easiest (no CLI):
1. Go to https://app.netlify.com/drop
2. **Drag the `analytics` folder** onto the page.
3. Netlify gives you a live URL — share that link.

To update later, drag the folder again (or connect the repo).

## 3. Who can log in — email allowlist
The dashboard is locked to a specific list of emails (`ALLOWED_EMAILS` near the top
of the `<script>` in `index.html`). Anyone else who signs in is immediately signed
out with "not authorized." Current allowlist:
- akshayakuhikar1998@gmail.com
- vanam.pranav03@gmail.com
- prakash.elefitstore@gmail.com
- vanam413@gmail.com
- sudheeravanam@gmail.com

To add/remove people: edit that list and re-deploy.

**Each of these emails must have a Firebase Auth account (with a password) to sign in:**
- Firebase Console → **Authentication → Users**. If an email is already listed (e.g.
  they signed up in the app), it works.
- For any missing email: **Add user** → enter the email + a password → share those
  credentials with that person.

## Data sources — reads BOTH `profiles` and `users`
App users live in **`profiles/{uid}`** (onboarding data: name, age, gender, height,
weight, activity). Email + AI-Coach plan + credits live in **`users/{uid}`**. The
dashboard reads both and merges by uid, so every app user shows up.

**Firestore rule needed for `profiles`:** your current rule only lets a user read
their OWN profile, so the dashboard can't list everyone. Add read access. Pick one:

- **Secure (recommended)** — admin-only, and make the dashboard accounts admins
  (`users/{uid}.isAdmin = true`). Note: `isAdmin` also grants challenge-admin powers.
  ```
  match /profiles/{userId} {
    allow read:  if isOwner(userId) || isAdmin();   // was: if isOwner(userId)
    allow write: if isOwner(userId);
  }
  ```
- **Simple** — any signed-in account can read all profiles (matches your current
  `users` rule, but exposes everyone's body metrics to any logged-in user):
  ```
  match /profiles/{userId} {
    allow read:  if isSignedIn();
    allow write: if isOwner(userId);
  }
  ```
If `profiles` stays unreadable, the dashboard still shows whatever is in `users`, and
the count line warns "profiles not readable — add admin rule".

## 🔒 SECURITY — read this before sharing the link
- User **emails and names are personal data (PII)**. Treat the link as internal-only; don't post it publicly.
- The dashboard needs to **list all users**. Your current Firestore rule is
  `match /users/{userId} { allow read: if isSignedIn(); }` — meaning **any**
  signed-in user (including any app user) can read every user's data. For a
  marketing dashboard you should tighten this to **admins only**:
  ```
  match /users/{userId} {
    allow read: if request.auth.uid == userId || isAdmin();   // was: if isSignedIn()
    allow write: if isOwner(userId) || isAdmin();
  }
  ```
  ⚠️ Check the app still works after this change (the app reads users via REST; if
  any in-app feature lists other users it may need adjusting). Test before publishing.
- The page sends `noindex, nofollow` so search engines won't index it, but that is
  **not** access control — the login is.
- If you'd rather not host live data at all, use the **Export CSV** button once and
  hand marketing the file instead of a link.

## What it shows
- Stat cards: Total users, AI Coach users, No AI plan, Have credits.
- Tabs: **All Users** / **AI Coach Users** (users who have generated a fitness plan).
- Search by name/email, **Copy emails** (for bulk outreach), **Export CSV**.
