/**
 * Export participant emails for the LIVE (status = "active") challenge.
 *
 * It reads challenges/{id}/participants, skips anyone who has LEFT the
 * challenge (withdrawn / disqualified), looks up each user's email from
 * users/{userId} (falling back to Firebase Auth), and prints a CSV + a
 * ready-to-paste "emails only" list.
 *
 * USAGE:
 *   1. cd scripts && npm install
 *   2. Put your service-account key here as serviceAccountKey.json
 *      (Firebase Console → Project Settings → Service accounts →
 *       Generate new private key). NEVER commit this file.
 *   3. node export-participants.js                 # auto-finds the active challenge
 *      node export-participants.js <challengeId>   # or target one explicitly
 *
 * Nothing is written to Firestore — this is READ-ONLY.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function init() {
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  // Preferred: the service-account key file next to this script.
  if (fs.existsSync(keyPath)) {
    const sa = require(keyPath);
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: sa.project_id,
    });
    return;
  }
  // Otherwise: Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS / gcloud).
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    return;
  }
  throw new Error(
    'No credentials found.\n' +
      '  Download a key: Firebase Console → Project Settings → Service accounts →\n' +
      '  "Generate new private key", then save it as:\n' +
      `      ${keyPath}\n` +
      '  and run this command again.',
  );
}

function csv(v) {
  const s = (v === undefined || v === null ? '' : v).toString();
  return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

async function participantsFor(db, cid) {
  // Primary schema: subcollection challenges/{cid}/participants
  const sub = await db.collection('challenges').doc(cid).collection('participants').get();
  if (!sub.empty) return sub.docs;
  // Fallback schema: top-level challengeParticipants filtered by challengeId
  const top = await db.collection('challengeParticipants').where('challengeId', '==', cid).get();
  return top.docs;
}

async function main() {
  init();
  const db = admin.firestore();

  const argCid = process.argv[2];
  let challenges;
  if (argCid) {
    const d = await db.collection('challenges').doc(argCid).get();
    if (!d.exists) throw new Error(`Challenge ${argCid} not found`);
    challenges = [d];
  } else {
    const snap = await db.collection('challenges').where('status', '==', 'active').get();
    challenges = snap.docs;
  }

  if (!challenges.length) {
    console.log('No active (live) challenge found. Pass a challenge id explicitly if needed.');
    return;
  }
  if (challenges.length > 1) {
    console.log(`NOTE: ${challenges.length} active challenges found — exporting all of them.\n`);
  }

  for (const ch of challenges) {
    const cid = ch.id;
    console.log(`\n=================================================================`);
    console.log(`Challenge: ${ch.get('title') || '(untitled)'}   [${cid}]   status=${ch.get('status')}`);
    console.log(`=================================================================`);

    const parts = await participantsFor(db, cid);
    const rows = [];

    for (const p of parts.docs ? parts.docs : parts) {
      const data = p.data();
      const status = data.status || '';
      const disqualified = data.disqualified === true;
      // "Still in the live challenge" = not withdrawn, not disqualified.
      if (status === 'withdrawn' || status === 'disqualified' || disqualified) continue;

      const uid = data.userId || p.id;
      let email = '';
      let name = '';
      try {
        const u = await db.collection('users').doc(uid).get();
        if (u.exists) {
          email = (u.get('email') || '').toString().trim();
          name = u.get('name') || u.get('displayName') || u.get('fullName') || '';
        }
      } catch (_) {}
      if (!email) {
        try {
          const au = await admin.auth().getUser(uid);
          email = au.email || '';
          name = name || au.displayName || '';
        } catch (_) {}
      }

      rows.push({
        email,
        name,
        nickname: data.leaderboardDisplayName || '',
        status,
        paymentStatus: data.paymentStatus || '',
        baselineSubmitted: data.baselineSubmitted === true ? 'yes' : 'no',
        uid,
      });
    }

    rows.sort((a, b) => (a.email || 'zzz').localeCompare(b.email || 'zzz'));

    console.log('\nemail,name,nickname,status,paymentStatus,baselineSubmitted,userId');
    for (const r of rows) {
      console.log(
        [r.email, r.name, r.nickname, r.status, r.paymentStatus, r.baselineSubmitted, r.uid]
          .map(csv)
          .join(','),
      );
    }

    const emails = rows.map((r) => r.email).filter(Boolean);
    const missing = rows.filter((r) => !r.email);
    console.log(`\n---- ${rows.length} active participant(s); ${emails.length} with an email ----`);
    console.log('\nEmails (comma-separated, ready to paste):\n' + emails.join(', '));
    if (missing.length) {
      console.log(`\n⚠️  ${missing.length} participant(s) had NO email (check userId in Auth):`);
      console.log(missing.map((r) => `   - ${r.nickname || r.uid} (${r.uid}) status=${r.status}`).join('\n'));
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('ERROR:', e.message || e);
    process.exit(1);
  });
