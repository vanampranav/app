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
import 'package:elefit_app/features/challenge/domain/services/challenge_scoring_service.dart';
import 'package:elefit_app/features/challenge/domain/services/leaderboard_service.dart';
import 'package:elefit_app/features/challenge/domain/services/winner_selection_service.dart';
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

      // Reject a fresh baseline (resubmission) → flag + eligibility off.
      await h.submissions.submitBaseline('u1', 'ch-1', {'weight': 199.0});
      final resub = await h.latestSubmission('u1', SubmissionType.baseline);
      await h.submissions.rejectSubmission(resub!.id, ChallengeHarness.adminId, 'redo it');

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
      expect(s.officialMetric, 'bodyFatLossPoints');
      expect(s.officialScore, closeTo(5.0, 0.001)); // 30 - 25
      expect(s.weightLossPercent, closeTo(5.0, 0.001)); // (200-190)/200*100

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

    test('body-fat finalists rank above weight-only finalists', () async {
      await h.seedChallenge();
      await finalist('bfUser', finalWeight: 190, finalBodyFat: 25); // bodyFat metric, score 5
      await finalist('wtUser', finalWeight: 160); // weight metric, 20% (bigger number)

      final ranking = await buildService().computeRanking('ch-1');
      expect(ranking.ranked.length, 2);
      // Body-fat finalist first even though the weight finalist has a bigger raw number.
      expect(ranking.ranked.first.userId, 'bfUser');
      expect(ranking.ranked.first.officialMetric, 'bodyFatLossPoints');
      expect(ranking.ranked[1].userId, 'wtUser');
      expect(ranking.ranked[1].officialMetric, 'weightLossPercent');
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
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Scoring (pure calculation)', () {
    final scoring = ChallengeScoringService();

    test('official score uses body-fat loss when both fats present', () async {
      await h.seedChallenge();
      await h.seedActivePaidParticipant(
          challengeId: 'ch-1', userId: 'u1', weight: 200, bodyFat: 30);
      await h.submissions.submitWeeklyCheckIn(
          'u1', 'ch-1', {'weight': 190.0, 'bodyFat': 25.0, 'weekNumber': 1});
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
        latestProgress: wk,
        isChallengeCompleted: false,
      );
      expect(result.isEligible, isTrue);
      expect(result.metric, 'bodyFatLossPoints');
      expect(result.score, closeTo(5.0, 0.001)); // 30 - 25
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
        participant: ineligible, baseline: null, latestProgress: null,
        isChallengeCompleted: false);
      expect(r.isEligible, isFalse);
    });

    test('weight-loss fallback + consistency helpers', () {
      expect(scoring.calculateWeightLossPercent(200, 180), closeTo(10.0, 0.001));
      expect(scoring.calculateBodyFatLossPoints(30, 25), closeTo(5.0, 0.001));
      expect(scoring.calculateConsistencyScore(5), closeTo(100.0, 0.001));
    });
  });
}
