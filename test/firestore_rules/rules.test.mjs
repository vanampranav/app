// Firestore security-rules test suite for the Elefit challenge feature.
//
// These run against the Firestore EMULATOR (not production) and validate the
// exact rules in ../../firestore.rules — the ones you publish in the console.
// Unlike the Dart fake_cloud_firestore tests (which ignore rules entirely),
// this suite is the ONLY thing that actually verifies allow/deny behaviour.
//
// Run:  cd test/firestore_rules && npm install && npm test
// (npm test wraps `firebase emulators:exec --only firestore ... node --test`)

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { before, after, beforeEach, describe, it } from 'node:test';

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, collectionGroup, query, where, getDocs,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES_PATH = resolve(__dirname, '../../firestore.rules');

const PROJECT_ID = 'demo-getfit';
const ADMIN = 'admin-uid';
const U1 = 'user-1';
const U2 = 'user-2';
const CH = 'ch-1';

let testEnv;

// ── Auth context helpers ────────────────────────────────────────────────────
const asAdmin = () => testEnv.authenticatedContext(ADMIN).firestore();
const asU1 = () => testEnv.authenticatedContext(U1).firestore();
const asU2 = () => testEnv.authenticatedContext(U2).firestore();
const asAnon = () => testEnv.unauthenticatedContext().firestore();

// Path helpers
const participantRef = (db, uid) => doc(db, `challenges/${CH}/participants/${uid}`);
const notifRef = (db, id) => doc(db, `notifications/${id}`);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(RULES_PATH, 'utf8') },
  });
});

after(async () => {
  await testEnv.cleanup();
});

// Fresh data before every test; seed the always-needed docs with rules OFF.
beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Admin user doc (isAdmin drives isAdmin() helper).
    await setDoc(doc(db, `users/${ADMIN}`), { isAdmin: true, role: 'admin' });
    await setDoc(doc(db, `users/${U1}`), { isAdmin: false });
    await setDoc(doc(db, `users/${U2}`), { isAdmin: false });
    // A registration-open challenge.
    await setDoc(doc(db, `challenges/${CH}`), { title: 'Get Fit', status: 'registrationOpen' });
  });
});

// Seed a participant doc (rules OFF) in a given starting state.
async function seedParticipant(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(participantRef(ctx.firestore(), uid), {
      challengeId: CH, userId: uid, status: 'joined',
      paymentStatus: 'pending', eligibleForPrizes: false,
      disqualified: false, baselineSubmitted: false, amountDue: 25,
      ...data,
    });
  });
}

async function seedNotification(id, recipientUserId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(notifRef(ctx.firestore(), id), {
      recipientUserId, title: 'Hi', body: 'x', type: 'challengeJoined',
      isRead: false, createdAt: new Date(),
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
describe('Notifications', () => {
  it('participant CAN create a self-addressed notification (the join bug fix)', async () => {
    await assertSucceeds(setDoc(notifRef(asU1(), 'n1'), {
      recipientUserId: U1, title: 'Joined', body: 'welcome',
      type: 'challengeJoined', isRead: false, createdAt: new Date(),
    }));
  });

  it('participant CANNOT create a notification addressed to someone else', async () => {
    await assertFails(setDoc(notifRef(asU1(), 'n2'), {
      recipientUserId: U2, title: 'nope', body: 'x',
      type: 'system', isRead: false, createdAt: new Date(),
    }));
  });

  it('admin CAN create a notification for a participant', async () => {
    await assertSucceeds(setDoc(notifRef(asAdmin(), 'n3'), {
      recipientUserId: U1, title: 'Payment approved', body: 'x',
      type: 'paymentApproved', isRead: false, createdAt: new Date(),
    }));
  });

  it('unauthenticated user CANNOT create a notification', async () => {
    await assertFails(setDoc(notifRef(asAnon(), 'n4'), { recipientUserId: U1 }));
  });

  it('participant can read own notification but NOT another user\'s', async () => {
    await seedNotification('mine', U1);
    await seedNotification('theirs', U2);
    await assertSucceeds(getDoc(notifRef(asU1(), 'mine')));
    await assertFails(getDoc(notifRef(asU1(), 'theirs')));
  });

  it('admin CAN read a participant\'s notifications (reminder dedupe)', async () => {
    await seedNotification('theirs', U2);
    await assertSucceeds(getDoc(notifRef(asAdmin(), 'theirs')));
    await assertSucceeds(getDocs(query(
        collection(asAdmin(), 'notifications'),
        where('recipientUserId', '==', U2))));
  });

  it('participant can mark own notification read (isRead/readAt only)', async () => {
    await seedNotification('mine', U1);
    await assertSucceeds(updateDoc(notifRef(asU1(), 'mine'), { isRead: true, readAt: new Date() }));
  });

  it('participant CANNOT change other fields when updating a notification', async () => {
    await seedNotification('mine', U1);
    await assertFails(updateDoc(notifRef(asU1(), 'mine'), { isRead: true, title: 'hacked' }));
  });

  it('participant CANNOT delete a notification; admin CAN', async () => {
    await seedNotification('mine', U1);
    await assertFails(deleteDoc(notifRef(asU1(), 'mine')));
    await assertSucceeds(deleteDoc(notifRef(asAdmin(), 'mine')));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Participant enrollment', () => {
  it('user CAN create their own participant doc', async () => {
    await assertSucceeds(setDoc(participantRef(asU1(), U1), {
      challengeId: CH, userId: U1, status: 'joined', paymentStatus: 'pending',
    }));
  });

  it('user CANNOT create a participant doc for someone else', async () => {
    await assertFails(setDoc(participantRef(asU1(), U2), {
      challengeId: CH, userId: U2, status: 'joined', paymentStatus: 'pending',
    }));
  });

  it('non-admin CANNOT set eligibleForPrizes directly', async () => {
    await seedParticipant(U1, { paymentStatus: 'paid' });
    await assertFails(updateDoc(participantRef(asU1(), U1), { eligibleForPrizes: true }));
  });

  it('admin CAN update any participant field', async () => {
    await seedParticipant(U1, {});
    await assertSucceeds(updateDoc(participantRef(asAdmin(), U1), {
      status: 'active', eligibleForPrizes: true, paymentStatus: 'paid',
    }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Payment: first submission (pending → pending_review)', () => {
  it('ALLOWS the exact fields submitManualPayment writes', async () => {
    await seedParticipant(U1, { paymentStatus: 'pending' });
    await assertSucceeds(updateDoc(participantRef(asU1(), U1), {
      paymentStatus: 'pending_review',
      paymentMethod: 'zelle',
      paymentReference: 'ref-1',
      paymentProofUrl: 'https://x/y.jpg',
      paymentProofSubmittedAt: new Date(),
      latestPaymentRecordId: 'pay-1',
      updatedAt: new Date(),
    }));
  });

  it('DENIES if the update also flips a sensitive field (eligibleForPrizes)', async () => {
    await seedParticipant(U1, { paymentStatus: 'pending' });
    await assertFails(updateDoc(participantRef(asU1(), U1), {
      paymentStatus: 'pending_review',
      paymentReference: 'ref-1',
      eligibleForPrizes: true,
      updatedAt: new Date(),
    }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Payment: recovery re-submission (failed → pending_review) — THE FIX', () => {
  it('ALLOWS resubmit incl. latestPaymentRecordId (fails on the OLD rules)', async () => {
    await seedParticipant(U1, { paymentStatus: 'failed', eligibleForPrizes: false });
    await assertSucceeds(updateDoc(participantRef(asU1(), U1), {
      paymentStatus: 'pending_review',
      paymentMethod: 'zelle',
      paymentReference: 'ref-2',
      paymentProofUrl: 'https://x/z.jpg',
      paymentProofSubmittedAt: new Date(),
      paymentProofNotes: 'retrying',
      latestPaymentRecordId: 'pay-2',
      updatedAt: new Date(),
    }));
  });

  it('DENIES resubmit that also flips eligibleForPrizes true', async () => {
    await seedParticipant(U1, { paymentStatus: 'failed', eligibleForPrizes: false });
    await assertFails(updateDoc(participantRef(asU1(), U1), {
      paymentStatus: 'pending_review',
      paymentReference: 'ref-2',
      eligibleForPrizes: true,
      updatedAt: new Date(),
    }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Collection-group participant read (home "My Challenges" tile)', () => {
  it('participant CAN query their OWN participant records across challenges', async () => {
    await seedParticipant(U1, {});
    const q = query(collectionGroup(asU1(), 'participants'), where('userId', '==', U1));
    await assertSucceeds(getDocs(q));
  });

  it('participant CANNOT query ANOTHER user\'s participant records', async () => {
    await seedParticipant(U2, {});
    const q = query(collectionGroup(asU1(), 'participants'), where('userId', '==', U2));
    await assertFails(getDocs(q));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Challenges, submissions, payment records', () => {
  it('anyone can read a challenge (public discovery)', async () => {
    await assertSucceeds(getDoc(doc(asAnon(), `challenges/${CH}`)));
  });

  it('non-admin CANNOT create a challenge; admin CAN', async () => {
    await assertFails(setDoc(doc(asU1(), 'challenges/hack'), { title: 'x', status: 'draft' }));
    await assertSucceeds(setDoc(doc(asAdmin(), 'challenges/legit'), { title: 'x', status: 'draft' }));
  });

  it('participant can create a submission with their OWN userId, not another\'s', async () => {
    await assertSucceeds(setDoc(doc(asU1(), 'challengeSubmissions/s1'), {
      userId: U1, challengeId: CH, type: 'baseline',
    }));
    await assertFails(setDoc(doc(asU1(), 'challengeSubmissions/s2'), {
      userId: U2, challengeId: CH, type: 'baseline',
    }));
  });

  it('participant can create a paymentRecord with their OWN userId only', async () => {
    await assertSucceeds(setDoc(doc(asU1(), 'paymentRecords/p1'), {
      userId: U1, challengeId: CH, amount: 25, status: 'pending',
    }));
    await assertFails(setDoc(doc(asU1(), 'paymentRecords/p2'), {
      userId: U2, challengeId: CH, amount: 25, status: 'pending',
    }));
  });

  it('participant CANNOT update a submission (admin-only review); admin CAN', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'challengeSubmissions/s3'), { userId: U1, challengeId: CH, reviewStatus: 'submitted' });
    });
    await assertFails(updateDoc(doc(asU1(), 'challengeSubmissions/s3'), { reviewStatus: 'approved' }));
    await assertSucceeds(updateDoc(doc(asAdmin(), 'challengeSubmissions/s3'), { reviewStatus: 'approved' }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Sanitized public leaderboard', () => {
  const lbRef = (db, uid) => doc(db, `challenges/${CH}/leaderboard/${uid}`);

  it('any signed-in participant CAN read the leaderboard', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(lbRef(ctx.firestore(), U2),
          { userId: U2, displayName: 'Bob', motivationalScore: 42 });
    });
    await assertSucceeds(getDocs(collection(asU1(), `challenges/${CH}/leaderboard`)));
    await assertSucceeds(getDoc(lbRef(asU1(), U2)));
  });

  it('unauthenticated user CANNOT read the leaderboard', async () => {
    await assertFails(getDocs(collection(asAnon(), `challenges/${CH}/leaderboard`)));
  });

  it('a participant CANNOT write the leaderboard; an admin CAN', async () => {
    await assertFails(setDoc(lbRef(asU1(), U1),
        { userId: U1, displayName: 'Me', motivationalScore: 99 }));
    await assertSucceeds(setDoc(lbRef(asAdmin(), U1),
        { userId: U1, displayName: 'Me', motivationalScore: 10 }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('isAdmin() robustness (user docs missing role/isAdmin fields)', () => {
  it('admin flagged with isAdmin:true but NO role field still counts as admin', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      // Overwrite the admin doc to have ONLY isAdmin:true (no role field).
      await setDoc(doc(ctx.firestore(), `users/${ADMIN}`), { isAdmin: true });
    });
    await assertSucceeds(setDoc(doc(asAdmin(), 'challenges/byflag'), { title: 'x', status: 'draft' }));
  });

  it('admin by role only (role:"admin", no isAdmin field) counts as admin', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${ADMIN}`), { role: 'admin' });
    });
    await assertSucceeds(setDoc(doc(asAdmin(), 'challenges/byrole'), { title: 'x', status: 'draft' }));
  });

  it('plain user with NEITHER field is denied admin-only writes (no eval error)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${U1}`), { name: 'Plain' }); // no isAdmin, no role
    });
    await assertFails(setDoc(doc(asU1(), 'challenges/nope'), { title: 'x', status: 'draft' }));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Packages, audit logs, profiles, leads', () => {
  it('signed-in user reads an ACTIVE package but not an INACTIVE one', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `challenges/${CH}/packages/active`), { isActive: true, name: 'Std' });
      await setDoc(doc(db, `challenges/${CH}/packages/inactive`), { isActive: false, name: 'Old' });
    });
    await assertSucceeds(getDoc(doc(asU1(), `challenges/${CH}/packages/active`)));
    await assertFails(getDoc(doc(asU1(), `challenges/${CH}/packages/inactive`)));
  });

  it('adminAuditLogs: non-admin denied, admin allowed', async () => {
    await assertFails(getDocs(collection(asU1(), 'adminAuditLogs')));
    await assertSucceeds(setDoc(doc(asAdmin(), 'adminAuditLogs/a1'), { action: 'test' }));
  });

  it('profiles: any signed-in user can read (marketing dashboard), anon cannot', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `profiles/${U2}`), { name: 'Bob' });
    });
    await assertSucceeds(getDoc(doc(asU1(), `profiles/${U2}`)));
    await assertFails(getDoc(doc(asAnon(), `profiles/${U2}`)));
  });

  it('profiles: a user can only WRITE their own', async () => {
    await assertSucceeds(setDoc(doc(asU1(), `profiles/${U1}`), { name: 'Me' }));
    await assertFails(setDoc(doc(asU1(), `profiles/${U2}`), { name: 'Hacker' }));
  });

  it('earlyAccessLeads: anyone can create, nobody can read', async () => {
    await assertSucceeds(setDoc(doc(asAnon(), 'earlyAccessLeads/lead1'), { email: 'a@b.com' }));
    await assertFails(getDoc(doc(asU1(), 'earlyAccessLeads/lead1')));
  });
});
