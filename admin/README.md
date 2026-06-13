# EleFit Admin Dashboard

A single-file admin dashboard to view all app users.

## How to open

Just double-click `index.html` — it opens in any browser, no server needed.

## One-time Firestore rule setup

Before the dashboard can list all users, add this rule in Firebase Console:

1. Go to **console.firebase.google.com** → select **getfit-with-elefit**
2. Click **Firestore Database** → **Rules**
3. Replace the `users` rule with:

```
match /users/{uid} {
  allow read: if request.auth != null &&
    (request.auth.uid == uid || request.auth.token.email == 'vanam.pranav03@gmail.com');
  allow write: if request.auth.uid == uid;
}
```

4. Click **Publish**

If you skip this step, the dashboard will show a banner explaining what to do.

## What it shows

- Total users / new today / this week / with goal set
- Name, email, age, gender, weight, goal, activity level, credits, join date
- "NEW TODAY" badge on users who joined in the last 24 hours
- Search by name or email
- Filter by goal
- Sorted latest first (newest user at top)

## Notes

- Only `vanam.pranav03@gmail.com` can log in (hardcoded admin check)
- Email and `createdAt` are now saved to Firestore when a new user registers
- Existing users (before this update) will get their email saved the next time they complete onboarding
