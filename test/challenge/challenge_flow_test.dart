// Functional test suite for the challenge feature.
//
// These run the REAL domain services against an in-memory Firestore (see
// challenge_harness.dart). They verify flows, guards, state machines,
// prize-eligibility recalculation, admin review, and scoring — the things
// that a Node/Firestore-only script cannot test, because the logic lives in
// Dart, not in the backend.
//
// Run:  flutter test test/challenge/challenge_flow_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';
import 'package:elefit_app/features/challenge/domain/services/leaderboard_service.dart';
import 'package:elefit_app/features/challenge/domain/services/winner_selection_service.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_winner.dart';

import 'challenge_harness.dart';

void main() {
  late ChallengeHarness h;

  setUp(() {
    h = ChallengeHarness();
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Join & enrollment', () {
    test('happy path: join creates participant joined/pending', () async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');

      final p = await h.participant('ch-1', 'u1');
      expect(p, isNotNull);
      expect(p!.status, ParticipantStatus.joined);
      expect(p.paymentStatus, PaymentStatus.pending);
      expect(p.eligibleForPrizes, isFalse);
    });

    test('join sends a "challenge joined" notification', () async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      expect(await h.notificationCount('u1'), 1);
    });

    test('double join throws', () async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      expect(
        () => h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('join a non-registrationOpen challenge throws', () async {
      await h.seedChallenge(id: 'draft-ch', status: ChallengeStatus.draft);
      expect(
        () =>
            h.enrollment.joinChallenge(userId: 'u1', challengeId: 'draft-ch'),
        throwsA(isA<Exception>()),
      );
    });

    test('join a missing challenge throws', () async {
      expect(
        () => h.enrollment.joinChallenge(userId: 'u1', challengeId: 'nope'),
        throwsA(isA<Exception>()),
      );
    });

    test('join with a package snapshots price/name/variants', () async {
      await h.seedChallenge();
      final pkg = await h.seedPackage(challengeId: 'ch-1', price: 49.0);
      await h.enrollment
          .joinChallenge(userId: 'u1', challengeId: 'ch-1', package: pkg);

      final p = await h.participant('ch-1', 'u1');
      expect(p!.selectedPackageId, pkg.id);
      expect(p.selectedPackagePrice, 49.0);
      expect(p.amountDue, 49.0);
      expect(p.selectedShopifyVariantsSnapshot, isNotEmpty);
    });

    test('cancelParticipation withdraws and revokes eligibility', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      expect((await h.participant('ch-1', 'u1'))!.eligibleForPrizes, isTrue);

      await h.enrollment.cancelParticipation('u1', 'ch-1');
      final p = await h.participant('ch-1', 'u1');
      expect(p!.status, ParticipantStatus.withdrawn);
      expect(p.eligibleForPrizes, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Payment state machine', () {
    setUp(() async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      await h.enrollment.approveParticipant('ch-1', 'u1', ChallengeHarness.adminId);
    });

    test('submit → pending_review; record is pending', () async {
      await h.payments.submitManualPayment(
        userId: 'u1',
        challengeId: 'ch-1',
        amount: 25.0,
        method: PaymentMethod.zelle,
      );
      final p = await h.participant('ch-1', 'u1');
      expect(p!.paymentStatus, PaymentStatus.pendingReview);

      final pay = await h.latestPayment('u1');
      expect(pay!.status, PaymentStatus.pending);
    });

    test('approve → paid, participant paid, notification sent', () async {
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      final pay = await h.latestPayment('u1');
      final before = await h.notificationCount('u1');

      await h.payments.approvePayment(pay!.id, ChallengeHarness.adminId);

      final p = await h.participant('ch-1', 'u1');
      expect(p!.paymentStatus, PaymentStatus.paid);
      expect(p.paidAt, isNotNull);
      expect((await h.latestPayment('u1'))!.status, PaymentStatus.paid);
      expect(await h.notificationCount('u1'), greaterThan(before));
    });

    test('reject → failed, ineligible, reason recorded', () async {
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      final pay = await h.latestPayment('u1');

      await h.payments.rejectPayment(pay!.id, ChallengeHarness.adminId, 'Blurry screenshot');

      final p = await h.participant('ch-1', 'u1');
      expect(p!.paymentStatus, PaymentStatus.failed);
      expect(p.eligibleForPrizes, isFalse);
      expect(p.paymentFailureReason, 'Blurry screenshot');
    });

    test('reject without a reason throws', () async {
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      final pay = await h.latestPayment('u1');
      expect(
        () => h.payments.rejectPayment(pay!.id, ChallengeHarness.adminId, ''),
        throwsA(isA<Exception>()),
      );
    });

    test('resubmit after failure → pending_review + new record', () async {
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      final pay = await h.latestPayment('u1');
      await h.payments.rejectPayment(pay!.id, ChallengeHarness.adminId, 'nope');

      await h.payments.resubmitPaymentProof(
        challengeId: 'ch-1', userId: 'u1', reference: 'newref', proofUrl: 'u://x');

      final p = await h.participant('ch-1', 'u1');
      expect(p!.paymentStatus, PaymentStatus.pendingReview);
      expect((await h.paymentsFor('u1')).length, 2);
    });

    test('resubmit when not failed throws', () async {
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      expect(
        () => h.payments.resubmitPaymentProof(
            challengeId: 'ch-1', userId: 'u1', reference: 'r'),
        throwsA(isA<Exception>()),
      );
    });

    test('admin manual waive marks waived', () async {
      await h.payments.updateManualPaymentStatus(
        challengeId: 'ch-1',
        userId: 'u1',
        adminId: ChallengeHarness.adminId,
        newStatus: PaymentStatus.waived,
      );
      final p = await h.participant('ch-1', 'u1');
      expect(p!.paymentStatus, PaymentStatus.waived);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Baseline submission & eligibility recalculation', () {
    setUp(() async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      await h.enrollment.approveParticipant('ch-1', 'u1', ChallengeHarness.adminId);
    });

    test('cannot submit baseline before participant is active', () async {
      // Fresh join without approval → still "joined" only if we skip approve.
      await h.enrollment.joinChallenge(userId: 'u2', challengeId: 'ch-1');
      expect(
        () => h.submissions.submitBaseline('u2', 'ch-1', {'weight': 200.0}),
        throwsA(isA<Exception>()),
      );
    });

    test('baseline approval flips baselineSubmitted + recomputes eligibility',
        () async {
      // Pay first so payment leg of eligibility is satisfied.
      await h.payments.submitManualPayment(
        userId: 'u1', challengeId: 'ch-1', amount: 25.0, method: PaymentMethod.zelle);
      await h.payments.approvePayment(
          (await h.latestPayment('u1'))!.id, ChallengeHarness.adminId);

      await h.submissions.submitBaseline('u1', 'ch-1',
          {'weight': 200.0, 'bodyFat': 30.0, 'source': 'manualEntry'});
      // Not yet approved → not eligible, flag false.
      expect((await h.participant('ch-1', 'u1'))!.baselineSubmitted, isFalse);

      final baseline = await h.latestSubmission('u1', SubmissionType.baseline);
      await h.submissions.approveSubmission(baseline!.id, ChallengeHarness.adminId);

      final p = await h.participant('ch-1', 'u1');
      expect(p!.baselineSubmitted, isTrue);
      expect(p.eligibleForPrizes, isTrue); // paid + active + baseline approved
    });

    test('rejecting baseline clears flag + eligibility', () async {
      await h.payments.updateManualPaymentStatus(
        challengeId: 'ch-1', userId: 'u1',
        adminId: ChallengeHarness.adminId, newStatus: PaymentStatus.paid);
      await h.submissions.submitBaseline('u1', 'ch-1', {'weight': 200.0});
      final baseline = await h.latestSubmission('u1', SubmissionType.baseline);
      await h.submissions.approveSubmission(baseline!.id, ChallengeHarness.adminId);
      expect((await h.participant('ch-1', 'u1'))!.eligibleForPrizes, isTrue);

      // A participant can no longer resubmit over an approved baseline (it's their
      // locked starting point), so the admin re-opens it by rejecting directly →
      // flag + eligibility off.
      await h.submissions.rejectSubmission(baseline!.id, ChallengeHarness.adminId, 'redo it');

      final p = await h.participant('ch-1', 'u1');
      expect(p!.baselineSubmitted, isFalse);
      expect(p.eligibleForPrizes, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Weekly & final submissions', () {
    test('weekly check-in blocked until baseline approved', () async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      await h.enrollment.approveParticipant('ch-1', 'u1', ChallengeHarness.adminId);
      expect(
        () => h.submissions.submitWeeklyCheckIn('u1', 'ch-1', {'weight': 195.0, 'weekNumber': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('weekly check-in allowed after approved baseline', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 195.0, 'bodyFat': 28.0, 'weekNumber': 1});
      final wk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      expect(wk, isNotNull);
      expect(wk!.data['weekNumber'], 1);
    });

    // Regression test for the cross-challenge baseline leak: an approved
    // baseline in one challenge must NOT satisfy the baseline guard in another.
    // Fixed by scoping submission lookups to (user, challenge) via
    // streamSubmissionsByParticipantAndChallenge in submission_review_service.
    test('baseline approved in challenge A does NOT unlock challenge B',
        () async {
      await h.seedChallenge(id: 'ch-A');
      await h.seedActivePaidParticipant(challengeId: 'ch-A', userId: 'u1');

      // Same user joins challenge B and is approved, but has NO baseline there.
      await h.seedChallenge(id: 'ch-B');
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-B');
      await h.enrollment
          .approveParticipant('ch-B', 'u1', ChallengeHarness.adminId);

      // Must throw — no approved baseline exists for challenge B.
      expect(
        () => h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-B', {'weight': 195.0, 'weekNumber': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('baseline approved in challenge B DOES unlock B (control)', () async {
      await h.seedChallenge(id: 'ch-A');
      await h.seedActivePaidParticipant(challengeId: 'ch-A', userId: 'u1');
      // A real baseline in B → weekly in B is allowed.
      await h.seedChallenge(id: 'ch-B');
      await h.seedActivePaidParticipant(challengeId: 'ch-B', userId: 'u1');
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-B', {'weight': 195.0, 'weekNumber': 1});
      final weeklies = (await h.submissionsFor('u1'))
          .where((s) =>
              s.type == SubmissionType.weeklyCheckIn && s.challengeId == 'ch-B')
          .toList();
      expect(weeklies.length, 1);
    });

    test('duplicate weekly check-in for the same week is rejected', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 195.0, 'weekNumber': 1});
      // Second submission for the SAME week must throw.
      expect(
        () => h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-1', {'weight': 194.0, 'weekNumber': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('a different week number is allowed after week 1 is submitted',
        () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 195.0, 'weekNumber': 1});
      // Week 2 is a fresh window → allowed.
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 190.0, 'weekNumber': 2});
      final all = await h.submissionsFor('u1');
      final weeklies =
          all.where((s) => s.type == SubmissionType.weeklyCheckIn).toList();
      expect(weeklies.length, 2);
    });

    test('resubmitting a rejected weekly check-in updates the same doc (no duplicate)',
        () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');

      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 195.0, 'weekNumber': 1});
      final first = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions
          .rejectSubmission(first!.id, ChallengeHarness.adminId, 'redo');

      // Resubmit week 1 → must UPDATE the same doc, not create a second one.
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 190.0, 'weekNumber': 1});

      final all = await h.submissionsFor('u1');
      final week1 = all
          .where((s) =>
              s.type == SubmissionType.weeklyCheckIn &&
              s.data['weekNumber'] == 1)
          .toList();
      expect(week1.length, 1,
          reason: 'resubmission must update in place, not create a duplicate');
      expect(week1.first.reviewStatus, ReviewStatus.submitted);
      expect(week1.first.data['weight'], 190.0);
      expect(week1.first.resubmitCount, 1);
    });

    test('weekly check-in resubmission is capped', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');

      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 195.0, 'weekNumber': 1});

      // Reject + resubmit up to the cap.
      for (var i = 0; i < SubmissionReviewService.maxResubmissions; i++) {
        final cur = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
        await h.submissions
            .rejectSubmission(cur!.id, ChallengeHarness.adminId, 'redo');
        await h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-1', {'weight': 190.0 - i, 'weekNumber': 1});
      }

      // One more reject + resubmit is now blocked by the cap.
      final last = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions
          .rejectSubmission(last!.id, ChallengeHarness.adminId, 'again');
      expect(
        () => h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-1', {'weight': 185.0, 'weekNumber': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('weekly check-in for week 0 (baseline week) is rejected', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      // Week 0 is the baseline week — no check-in opens until week 1 (day 7).
      expect(
        () => h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-1', {'weight': 195.0, 'weekNumber': 0}),
        throwsA(isA<Exception>()),
      );
    });

    test('weekly check-in is closed once the final window opens', () async {
      await h.seedChallenge(
          startDate: DateTime.now().subtract(const Duration(days: 20)),
          endDate: DateTime.now().add(const Duration(days: 2)));
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      // Final window is open (ends in 2 days) → weekly check-ins are closed.
      expect(
        () => h.submissions.submitWeeklyCheckIn(
            'u1', 'ch-1', {'weight': 190.0, 'weekNumber': 2}),
        throwsA(isA<Exception>()),
      );
    });

    test('final submission rejected outside the window (ends in 30 days)',
        () async {
      await h.seedChallenge(); // endDate = now + 30d → window not open
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      expect(
        () => h.submissions.submitFinalSubmission('u1', 'ch-1', {'weight': 180.0}),
        throwsA(isA<Exception>()),
      );
    });

    test('final submission allowed inside the window (ends in 2 days)',
        () async {
      final now = DateTime.now();
      await h.seedChallenge(
        id: 'ch-soon',
        startDate: now.subtract(const Duration(days: 20)),
        endDate: now.add(const Duration(days: 2)),
        registrationDeadline: now.subtract(const Duration(days: 19)),
      );
      await h.seedActivePaidParticipant(challengeId: 'ch-soon', userId: 'u1');
      await h.submissions.submitFinalSubmission(
          'u1', 'ch-soon', {'weight': 180.0, 'bodyFat': 24.0, 'photos': ['u://f']});
      final fin = await h.latestSubmission('u1', SubmissionType.finalSubmission);
      expect(fin, isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Admin: challenge lifecycle', () {
    test('createDraftChallenge rejects end-before-start', () async {
      final now = DateTime.now();
      expect(
        () => h.challenges.createDraftChallenge(
          title: 't', description: 'd',
          startDate: now.add(const Duration(days: 5)),
          endDate: now, // before start
          registrationDeadline: now,
          registrationFee: 0, maxParticipants: 10,
          prizeDescription: 'p', rulesSummary: 'r',
          baselineRequired: true, finalPhotoRequired: true,
          adminId: ChallengeHarness.adminId,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('activate fails without an active package', () async {
      await h.seedChallenge(id: 'd1', status: ChallengeStatus.draft);
      expect(
        () => h.challenges.activateChallenge('d1', ChallengeHarness.adminId),
        throwsA(isA<Exception>()),
      );
    });

    test('activate succeeds once a package exists', () async {
      await h.seedChallenge(id: 'd2', status: ChallengeStatus.draft);
      await h.seedPackage(challengeId: 'd2');
      await h.challenges.activateChallenge('d2', ChallengeHarness.adminId);
      final c = await h.challengeRepo.getChallengeById('d2');
      expect(c!.status, ChallengeStatus.registrationOpen);
    });

    test('every admin action writes an audit log', () async {
      await h.seedChallenge();
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      final before = await h.auditLogCount();
      await h.enrollment.approveParticipant('ch-1', 'u1', ChallengeHarness.adminId);
      expect(await h.auditLogCount(), greaterThan(before));
    });

    test('delete removes the challenge doc (draft only)', () async {
      // The repository only permits deleting DRAFT challenges.
      await h.seedChallenge(id: 'del-me', status: ChallengeStatus.draft);
      await h.challenges.deleteChallenge('del-me', ChallengeHarness.adminId);
      expect(await h.challengeRepo.getChallengeById('del-me'), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Admin: disqualification', () {
    test('reject disqualifies participant with reason', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      await h.enrollment.rejectParticipant(
          'ch-1', 'u1', ChallengeHarness.adminId, 'cheating');
      final p = await h.participant('ch-1', 'u1');
      expect(p!.status, ParticipantStatus.disqualified);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Sanitized public leaderboard', () {
    LeaderboardService buildService() => LeaderboardService(
          challengeRepository: h.challengeRepo,
          participantRepository: h.participantRepo,
          submissionRepository: h.submissionRepo,
          userRepository: UserRepository(firestore: h.db),
          leaderboardRepository: LeaderboardRepository(firestore: h.db),
        );

    test('recompute publishes a public-safe standing readable by anyone',
        () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u1', weight: 200, bodyFat: 30);
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 190.0, 'bodyFat': 25.0, 'weekNumber': 1});
      final wk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(wk!.id, ChallengeHarness.adminId);

      final service = buildService();
      await service.recomputeAndPublish('ch-1');

      final standings =
          await LeaderboardRepository(firestore: h.db).getStandings('ch-1');
      expect(standings.length, 1);
      final s = standings.first;
      expect(s.userId, 'u1');
      expect(s.officialMetric, 'compositeScore');
      // BF% change (30→25)=16.667 ×0.5 + weight loss 5% ×0.3 + muscle 0 ×0.2
      //   = 8.3333 + 1.5 = 9.8333
      expect(s.officialScore, closeTo(98.333, 0.1)); // ×10 points
      expect(s.weightLossPercent, closeTo(5.0, 0.001)); // (200-190)/200*100
      expect(s.bodyFatChangePercent, closeTo(16.6667, 0.01));

      // Sanitized: the standing doc must NOT carry absolute weight or photos.
      final raw = (await h.db
              .collection(FirestoreCollections.challenges)
              .doc('ch-1')
              .collection('leaderboard')
              .doc('u1')
              .get())
          .data()!;
      expect(raw.containsKey('weight'), isFalse);
      expect(raw.containsKey('photos'), isFalse);
      expect(raw.containsKey('paymentStatus'), isFalse);
    });

    test('admin bonus points lift a participant in the standings', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u1', weight: 200, bodyFat: 30);
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 190.0, 'bodyFat': 25.0, 'weekNumber': 1});
      final wk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(wk!.id, ChallengeHarness.adminId);

      final service = buildService();
      await service.recomputeAndPublish('ch-1');
      final before =
          (await LeaderboardRepository(firestore: h.db).getStandings('ch-1'))
              .first;
      expect(before.bonusPoints, 0);

      // Apply a bonus → score increases by exactly the bonus, recorded in the
      // standing, and the participant only (no new user created).
      await service.setBonusPoints('ch-1', 'u1', 25.0,
          adminId: ChallengeHarness.adminId);
      final standings =
          await LeaderboardRepository(firestore: h.db).getStandings('ch-1');
      expect(standings.length, 1);
      final after = standings.first;
      expect(after.bonusPoints, 25.0);
      expect(after.motivationalScore,
          closeTo(before.motivationalScore + 25.0, 0.001));
    });

    test('withdrawn participants are excluded from the published leaderboard',
        () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(challengeId: 'ch-1', userId: 'u1');
      await h.enrollment.cancelParticipation('u1', 'ch-1');

      await buildService().recomputeAndPublish('ch-1');
      final standings =
          await LeaderboardRepository(firestore: h.db).getStandings('ch-1');
      expect(standings, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Winner selection', () {
    LeaderboardService leaderboardService() => LeaderboardService(
          challengeRepository: h.challengeRepo,
          participantRepository: h.participantRepo,
          submissionRepository: h.submissionRepo,
          userRepository: UserRepository(firestore: h.db),
          leaderboardRepository: LeaderboardRepository(firestore: h.db),
        );

    WinnerSelectionService buildService() => WinnerSelectionService(
          challengeRepository: h.challengeRepo,
          participantRepository: h.participantRepo,
          leaderboardRepository: LeaderboardRepository(firestore: h.db),
          leaderboardService: leaderboardService(),
          auditService: h.auditService,
          notificationService: h.notificationService,
        );

    /// Drives a participant to an approved final metric.
    /// If [bodyFat] is null on the progress submission → weight-loss fallback.
    Future<void> finalist(String userId,
        {double finalWeight = 190, double? finalBodyFat}) async {
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: userId, weight: 200, bodyFat: 30);
      await h.submissions.submitWeeklyCheckIn(userId, 'ch-1', {
        'weight': finalWeight,
        if (finalBodyFat != null) 'bodyFat': finalBodyFat,
        'weekNumber': 1,
      });
      final wk = await h.latestSubmission(userId, SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(wk!.id, ChallengeHarness.adminId);
    }

    Future<void> markCompleted() async {
      final c = await h.challengeRepo.getChallengeById('ch-1');
      await h.challengeRepo
          .updateChallenge(c!.copyWith(status: ChallengeStatus.completed));
    }

    test('composite score weights body fat highest (50%)', () async {
      await h.seedChallenge();
      // bfUser: 5% weight loss + 16.67% BF change → composite 9.83
      await finalist('bfUser', finalWeight: 190, finalBodyFat: 25);
      // wtUser: 20% weight loss, no BF change → composite 6.0
      await finalist('wtUser', finalWeight: 160);

      final ranking = await buildService().computeRanking('ch-1');
      expect(ranking.ranked.length, 2);
      // The body-fat mover ranks first because BF% change carries 50% weight,
      // beating a much larger raw weight-loss number (which carries only 30%).
      expect(ranking.ranked.first.userId, 'bfUser');
      expect(ranking.ranked.first.officialMetric, 'compositeScore');
      expect(ranking.ranked.first.officialScore, closeTo(98.333, 0.1));
      expect(ranking.ranked[1].userId, 'wtUser');
      expect(ranking.ranked[1].officialScore, closeTo(60.0, 0.1));
    });

    test('admin bonus points change the winner ranking', () async {
      await h.seedChallenge();
      await finalist('bfUser', finalWeight: 190, finalBodyFat: 25); // composite ~9.83
      await finalist('wtUser', finalWeight: 160); // composite 6.0

      // Without a bonus, the body-fat mover leads.
      final before = await buildService().computeRanking('ch-1');
      expect(before.ranked.first.userId, 'bfUser');

      // A big admin bonus on the runner-up must lift them to #1 in the winner
      // ranking (not just the public leaderboard).
      await leaderboardService()
          .setBonusPoints('ch-1', 'wtUser', 50.0, adminId: ChallengeHarness.adminId);
      final after = await buildService().computeRanking('ch-1');
      expect(after.ranked.first.userId, 'wtUser');
      expect(after.ranked[1].userId, 'bfUser');
    });

    test('declareWinners requires a completed challenge', () async {
      await h.seedChallenge();
      await finalist('u1', finalBodyFat: 25);
      expect(
        () => buildService().declareWinners('ch-1', ChallengeHarness.adminId, [
          ChallengeWinner(
              userId: 'u1', displayName: 'U1', place: 1, awardLabel: '1st Place'),
        ]),
        throwsA(isA<Exception>()),
      );
    });

    test('declareWinners publishes results + stamps placement + notifies',
        () async {
      await h.seedChallenge();
      await finalist('u1', finalBodyFat: 25);
      await markCompleted();
      final before = await h.notificationCount('u1');

      await buildService().declareWinners('ch-1', ChallengeHarness.adminId, [
        ChallengeWinner(
            userId: 'u1', displayName: 'U1', place: 1, awardLabel: '1st Place',
            metric: 'bodyFatLossPoints', score: 5.0),
      ]);

      final c = await h.challengeRepo.getChallengeById('ch-1');
      expect(c!.resultsPublished, isTrue);
      expect(c.winners.length, 1);
      expect(c.winners.first.userId, 'u1');

      final p = await h.participant('ch-1', 'u1');
      expect(p!.finalPlacement, 1);
      expect(p.awardLabel, '1st Place');
      expect(await h.notificationCount('u1'), greaterThan(before));
    });

    test('re-declaring clears a previous winner no longer selected', () async {
      await h.seedChallenge();
      await finalist('u1', finalBodyFat: 25);
      await finalist('u2', finalBodyFat: 20);
      await markCompleted();
      final svc = buildService();

      await svc.declareWinners('ch-1', ChallengeHarness.adminId, [
        ChallengeWinner(userId: 'u1', displayName: 'U1', place: 1, awardLabel: '1st Place'),
      ]);
      expect((await h.participant('ch-1', 'u1'))!.finalPlacement, 1);

      // Re-publish with u2 as the only winner → u1's placement must clear.
      await svc.declareWinners('ch-1', ChallengeHarness.adminId, [
        ChallengeWinner(userId: 'u2', displayName: 'U2', place: 1, awardLabel: '1st Place'),
      ]);
      expect((await h.participant('ch-1', 'u1'))!.finalPlacement, isNull);
      expect((await h.participant('ch-1', 'u2'))!.finalPlacement, 1);
    });

    test('special award sets a label but no podium placement', () async {
      await h.seedChallenge();
      await finalist('u1', finalBodyFat: 25);
      await markCompleted();

      await buildService().declareWinners('ch-1', ChallengeHarness.adminId, [
        ChallengeWinner(
            userId: 'u1', displayName: 'U1', place: 0, awardLabel: 'Most Consistent'),
      ]);
      final p = await h.participant('ch-1', 'u1');
      expect(p!.finalPlacement, isNull);
      expect(p.awardLabel, 'Most Consistent');
    });

    test('FULL LIFECYCLE: join → pay → baseline → weekly → complete → winners → results',
        () async {
      await h.seedChallenge();

      // 1. JOIN — a participant record is created.
      await h.enrollment.joinChallenge(userId: 'u1', challengeId: 'ch-1');
      expect(await h.participant('ch-1', 'u1'), isNotNull);

      // 2. APPROVE participation → active.
      await h.enrollment
          .approveParticipant('ch-1', 'u1', ChallengeHarness.adminId);
      expect((await h.participant('ch-1', 'u1'))!.status,
          ParticipantStatus.active);

      // 3. PAYMENT — submit proof + admin approves → paid.
      await h.payments.submitManualPayment(
          userId: 'u1',
          challengeId: 'ch-1',
          amount: 25.0,
          method: PaymentMethod.zelle,
          externalTransactionId: 'ref-u1');
      final pay = await h.latestPayment('u1');
      await h.payments.approvePayment(pay!.id, ChallengeHarness.adminId);
      expect((await h.participant('ch-1', 'u1'))!.paymentStatus,
          PaymentStatus.paid);

      // 4. BASELINE — submit + approve → eligible for prizes.
      await h.submissions.submitBaseline('u1', 'ch-1', {
        'weight': 200.0,
        'unit': 'lbs',
        'bodyFat': 30.0,
        'source': 'manualEntry',
        'photos': <String>['x'],
      });
      final baseline = await h.latestSubmission('u1', SubmissionType.baseline);
      await h.submissions.approveSubmission(baseline!.id, ChallengeHarness.adminId);
      final afterBaseline = await h.participant('ch-1', 'u1');
      expect(afterBaseline!.baselineSubmitted, isTrue);
      expect(afterBaseline.eligibleForPrizes, isTrue);

      // 5. WEEKLY check-in — submit + approve.
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 188.0, 'bodyFat': 25.0, 'weekNumber': 1});
      final wk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(wk!.id, ChallengeHarness.adminId);

      // 6. LEADERBOARD — recompute → participant is scored.
      await leaderboardService().recomputeAndPublish('ch-1');
      final standings =
          await LeaderboardRepository(firestore: h.db).getStandings('ch-1');
      expect(standings.length, 1);
      expect(standings.first.userId, 'u1');
      expect(standings.first.weightLossPercent,
          closeTo(6.0, 0.001)); // (200-188)/200*100

      // 7. COMPLETE the challenge.
      final c = await h.challengeRepo.getChallengeById('ch-1');
      await h.challengeRepo
          .updateChallenge(c!.copyWith(status: ChallengeStatus.completed));

      // 8. DECLARE WINNERS → results published + placement stamped (this is what
      //    the participant leaderboard renders as the winners podium).
      await buildService().declareWinners('ch-1', ChallengeHarness.adminId, [
        ChallengeWinner(
            userId: 'u1',
            displayName: 'U1',
            place: 1,
            awardLabel: '1st Place',
            metric: 'bodyFatLossPoints',
            score: 5.0),
      ]);
      final done = await h.challengeRepo.getChallengeById('ch-1');
      expect(done!.resultsPublished, isTrue);
      expect(done.winners.first.userId, 'u1');
      final finalP = await h.participant('ch-1', 'u1');
      expect(finalP!.finalPlacement, 1);
      expect(finalP.awardLabel, '1st Place');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Scoring (pure calculation)', () {
    final scoring = ChallengeScoringService();

    test('composite score combines body fat, weight loss, and muscle gain',
        () async {
      await h.seedChallenge();
      // Baseline: weight 200, bodyFat 30, muscle 40.
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u1', weight: 200, bodyFat: 30, muscle: 40);
      // Progress: weight 190 (5% loss), bodyFat 25 (16.667% change), muscle 44
      //   (10% gain).
      await h.submissions.submitWeeklyCheckIn('u1', 'ch-1', {
        'weight': 190.0,
        'bodyFat': 25.0,
        'muscleMass': 44.0,
        'weekNumber': 1,
      });
      final pendingWk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(pendingWk!.id, ChallengeHarness.adminId);

      // Re-fetch AFTER approval — scoring reads `reviewStatus` off the object
      // passed in, and the pre-approval snapshot is still `pending`.
      final wk = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      final participant = await h.participant('ch-1', 'u1');
      final baseline = await h.latestSubmission('u1', SubmissionType.baseline);
      final result = scoring.calculateOfficialWinnerScore(
        participant: participant!,
        baseline: baseline,
        approvedProgress: [wk!],
        isChallengeCompleted: false,
      );
      expect(result.isEligible, isTrue);
      expect(result.metric, 'compositeScore');
      expect(result.bodyFatChangePercent, closeTo(16.6667, 0.01));
      expect(result.weightLossPercent, closeTo(5.0, 0.001));
      expect(result.muscleGainPercent, closeTo(10.0, 0.001));
      // 16.6667×0.5 + 5×0.3 + 10×0.2 = 8.3333 + 1.5 + 2.0 = 11.8333
      expect(result.score, closeTo(118.333, 0.1)); // ×10 points scale
    });

    test('composite score handles missing body fat + muscle (weight only)',
        () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u2', weight: 200, bodyFat: 30);
      // Progress with NO bodyFat / muscle → only the 30% weight component counts.
      await h.submissions.submitWeeklyCheckIn(
          'u2', 'ch-1', {'weight': 180.0, 'weekNumber': 1});
      final pending = await h.latestSubmission('u2', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(pending!.id, ChallengeHarness.adminId);

      final wk = await h.latestSubmission('u2', SubmissionType.weeklyCheckIn);
      final participant = await h.participant('ch-1', 'u2');
      final baseline = await h.latestSubmission('u2', SubmissionType.baseline);
      final result = scoring.calculateOfficialWinnerScore(
        participant: participant!,
        baseline: baseline,
        approvedProgress: [wk!],
        isChallengeCompleted: false,
      );
      expect(result.metric, 'compositeScore');
      // BF change 0 (progress has no bodyFat) + 10% weight loss ×0.3 + 0 muscle
      expect(result.weightLossPercent, closeTo(10.0, 0.001));
      expect(result.score, closeTo(30.0, 0.1)); // ×10
    });

    test('ineligible participant scores as not-eligible', () {
      final ineligible = ChallengeParticipant(
        id: 'x', challengeId: 'ch-1', userId: 'u9',
        status: ParticipantStatus.active,
        paymentStatus: PaymentStatus.pending,
        amountDue: 0, amountCollected: 0,
        eligibleForPrizes: false, disqualified: false,
        baselineSubmitted: false,
      );
      final r = scoring.calculateOfficialWinnerScore(
        participant: ineligible, baseline: null, approvedProgress: const [],
        isChallengeCompleted: false);
      expect(r.isEligible, isFalse);
    });

    test('weight-loss fallback + consistency helpers', () {
      expect(scoring.calculateWeightLossPercent(200, 180), closeTo(10.0, 0.001));
      expect(scoring.calculateBodyFatLossPoints(30, 25), closeTo(5.0, 0.001));
      expect(scoring.calculateConsistencyScore(5), closeTo(100.0, 0.001));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Accumulated points (recommended model)', () {
    final scoring = ChallengeScoringService();

    ChallengeSubmission sub(String type,
            {double? w, double? bf, double? mus, int? week, int day = 1,
            dynamic rawW, dynamic rawBf, dynamic rawMus,
            String status = ReviewStatus.approved}) =>
        ChallengeSubmission(
          id: '', challengeId: 'c', userId: 'u', type: type,
          data: {
            if (w != null) 'weight': w,
            if (bf != null) 'bodyFat': bf,
            if (mus != null) 'muscleMass': mus,
            if (rawW != null) 'weight': rawW,
            if (rawBf != null) 'bodyFat': rawBf,
            if (rawMus != null) 'muscleMass': rawMus,
            if (week != null) 'weekNumber': week,
          },
          reviewStatus: status,
          createdAt: DateTime(2026, 1, day),
        );

    ChallengeParticipant part(
            {bool disq = false, bool eligible = true,
            String status = ParticipantStatus.active}) =>
        ChallengeParticipant(
          id: 'p', challengeId: 'c', userId: 'u', status: status,
          paymentStatus: PaymentStatus.paid, amountDue: 0, amountCollected: 0,
          eligibleForPrizes: eligible, disqualified: disq, baselineSubmitted: true,
        );

    // "Rahul" from the recommended-model document.
    final rahulBaseline = sub(SubmissionType.baseline, w: 80, bf: 30, mus: 32);

    test('accumulates points across check-ins (Rahul example)', () {
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 79, bf: 29.5, mus: 32, week: 1, day: 2);
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, mus: 33, week: 2, day: 3);
      final w3 = sub(SubmissionType.weeklyCheckIn, w: 78, bf: 28, mus: 32.5, week: 3, day: 4); // worse
      final w4 = sub(SubmissionType.weeklyCheckIn, w: 75, bf: 26, mus: 33, week: 4, day: 5);
      final acc = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: [w1, w2, w3, w4]);
      // W1 +12.08, W2 +60.02, W3 +0 (regression), W4 +22.47 (beyond best) ≈ 94.56
      expect(acc.points, closeTo(94.56, 0.5));
    });

    test('per-check-in awards break out points + deltas (§16)', () {
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 79, bf: 29.5, mus: 32, week: 1, day: 2);
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, mus: 33, week: 2, day: 3);
      final w3 = sub(SubmissionType.weeklyCheckIn, w: 78, bf: 28, mus: 32.5, week: 3, day: 4);
      final w4 = sub(SubmissionType.weeklyCheckIn, w: 75, bf: 26, mus: 33, week: 4, day: 5);
      final awards = scoring.calculateCheckinAwards(
          baseline: rahulBaseline, approvedProgress: [w1, w2, w3, w4]);
      expect(awards.length, 4);
      expect(awards[0].points, closeTo(12.08, 0.2));
      expect(awards[1].points, closeTo(60.02, 0.3));
      expect(awards[2].points, closeTo(0.0, 0.01)); // regression week
      expect(awards[3].points, closeTo(22.47, 0.3));
      expect(awards[3].runningTotal, closeTo(94.56, 0.5));
      // Deltas since the previous check-in (W2 vs W1).
      expect(awards[1].weightDelta, closeTo(-3.0, 0.001)); // 76 − 79
      expect(awards[1].muscleDelta, closeTo(1.0, 0.001)); // 33 − 32
    });

    test('a poor week awards 0 and never subtracts', () {
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, mus: 33, week: 1, day: 2);
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 82, bf: 31, mus: 31, week: 2, day: 3); // worse
      final acc = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: [w1, w2]);
      final acc1 = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: [w1]);
      expect(acc.points, closeTo(acc1.points, 0.001)); // W2 added nothing
      expect(acc.points, greaterThan(0));
    });

    test('never negative (all worse than baseline)', () {
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 82, bf: 31, mus: 31, week: 1, day: 2);
      final acc = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: [w1]);
      expect(acc.points, 0);
    });

    test('anti-farming: yo-yoing back to a best earns nothing extra', () {
      final base = sub(SubmissionType.baseline, w: 80);
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 75, week: 1, day: 2); // best
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 80, week: 2, day: 3); // back up
      final w3 = sub(SubmissionType.weeklyCheckIn, w: 75, week: 3, day: 4); // same best again
      final acc = scoring.calculateAccumulatedPoints(
          baseline: base, approvedProgress: [w1, w2, w3]);
      // Only W1's 6.25% weight loss × 0.3 × 10 = 18.75 counts; W2/W3 add 0.
      expect(acc.points, closeTo(18.75, 0.1));
    });

    test('a NEW personal best earns new points', () {
      final base = sub(SubmissionType.baseline, w: 80);
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 75, week: 1, day: 2);
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 74, week: 2, day: 3); // new best
      final acc = scoring.calculateAccumulatedPoints(
          baseline: base, approvedProgress: [w1, w2]);
      // W1: 6.25%×0.3×10 = 18.75; W2: (75-74)/75=1.333%×0.3×10 = 4.0 → 22.75
      expect(acc.points, closeTo(22.75, 0.1));
    });

    test('missing a week compares to the latest available (not a fake value)', () {
      final w1 = sub(SubmissionType.weeklyCheckIn, w: 79, bf: 29.5, mus: 32, week: 1, day: 2);
      final w3 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, mus: 33, week: 3, day: 4);
      final acc = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: [w1, w3]);
      // W3 measured vs W1 (the latest best) → same as Rahul's W1+W2 ≈ 72.1
      expect(acc.points, closeTo(72.1, 0.5));
    });

    test('empty progress → 0 points', () {
      final acc = scoring.calculateAccumulatedPoints(
          baseline: rahulBaseline, approvedProgress: []);
      expect(acc.points, 0);
    });

    test('String-typed measurements (Firestore drift) do not crash', () {
      final base = sub(SubmissionType.baseline, rawW: '80', rawBf: '30', rawMus: '32');
      final w1 = sub(SubmissionType.weeklyCheckIn, rawW: '79', rawBf: '29.5', rawMus: '32', week: 1, day: 2);
      final acc = scoring.calculateAccumulatedPoints(
          baseline: base, approvedProgress: [w1]);
      expect(acc.points, closeTo(12.08, 0.1));
    });

    test('official score = accumulated points; completed needs a final', () {
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, mus: 33, week: 2);
      final r1 = scoring.calculateOfficialWinnerScore(
        participant: part(), baseline: rahulBaseline,
        approvedProgress: [w2], isChallengeCompleted: false,
      );
      expect(r1.isEligible, isTrue);
      expect(r1.score, greaterThan(0));
      final r2 = scoring.calculateOfficialWinnerScore(
        participant: part(), baseline: rahulBaseline,
        approvedProgress: [w2], isChallengeCompleted: true,
      );
      expect(r2.isEligible, isFalse);
      expect(r2.ineligibilityReason, contains('final'));
    });

    test('disqualified / payment-pending are ineligible', () {
      final w2 = sub(SubmissionType.weeklyCheckIn, w: 76, bf: 27, week: 2);
      expect(scoring.calculateOfficialWinnerScore(
        participant: part(disq: true), baseline: rahulBaseline,
        approvedProgress: [w2], isChallengeCompleted: false).isEligible, isFalse);
      expect(scoring.calculateOfficialWinnerScore(
        participant: part(eligible: false), baseline: rahulBaseline,
        approvedProgress: [w2], isChallengeCompleted: false).isEligible, isFalse);
    });

    test('LEADERBOARD accumulates and a worse week adds nothing', () async {
      final service = LeaderboardService(
        challengeRepository: h.challengeRepo,
        participantRepository: h.participantRepo,
        submissionRepository: h.submissionRepo,
        userRepository: UserRepository(firestore: h.db),
        leaderboardRepository: LeaderboardRepository(firestore: h.db),
      );

      await h.seedChallenge();
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u1', weight: 200, bodyFat: 30, muscle: 40);
      await h.submissions.submitWeeklyCheckIn('u1', 'ch-1',
          {'weight': 190.0, 'bodyFat': 24.0, 'muscleMass': 44.0, 'weekNumber': 1});
      final w1 = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(w1!.id, ChallengeHarness.adminId);
      await h.submissions.submitWeeklyCheckIn('u1', 'ch-1',
          {'weight': 196.0, 'bodyFat': 28.0, 'muscleMass': 41.0, 'weekNumber': 2});
      final w2 = await h.latestSubmission('u1', SubmissionType.weeklyCheckIn);
      await h.submissions.approveSubmission(w2!.id, ChallengeHarness.adminId);

      await service.recomputeAndPublish('ch-1');
      final s = (await LeaderboardRepository(firestore: h.db).getStandings('ch-1')).first;
      // Week 1: BF20%×0.5 + Wt5%×0.3 + Mus10%×0.2 = 13.5 → ×10 = 135. Week 2 worse → +0.
      expect(s.officialScore, closeTo(135.0, 0.5));
      expect(s.motivationalScore, closeTo(135.0, 0.5));
    });
  });
}
