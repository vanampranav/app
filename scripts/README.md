# Export challenge participant emails

Prints the emails (CSV + a paste-ready list) of everyone still in the **live**
(status = `active`) challenge. Read-only — it never writes to Firestore.

## Setup (once)

```bash
cd scripts
npm install
```

Get a service-account key:
1. Firebase Console → ⚙️ **Project Settings** → **Service accounts**
2. **Generate new private key** → save the file as `scripts/serviceAccountKey.json`
3. ⚠️ **Do not commit it** (already in `.gitignore`). Delete it when you're done if you like.

## Run

```bash
# auto-find the active/live challenge:
node export-participants.js

# or target a specific challenge id (e.g. the current one):
node export-participants.js ELBIyxIT0X3bGJC8Pzu9
```

## Output

- A **CSV**: `email,name,nickname,status,paymentStatus,baselineSubmitted,userId`
- A **comma-separated email list** you can paste into your email tool's BCC.
- Anyone who **left** the challenge (withdrawn / disqualified) is excluded.
- A warning lists any participant with no email found.

### Save the CSV to a file
```bash
node export-participants.js > participants.csv
```

## Privacy note
This exports real users' personal data. Use it only to contact your own
challenge participants, keep the file local, and prefer **BCC** when emailing so
addresses aren't shared between recipients.
