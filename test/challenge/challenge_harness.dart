// Test harness for the challenge feature.
//
// Wires every challenge repository + domain service onto a single in-memory
// FakeFirebaseFirestore, so tests exercise the REAL Dart business logic
// (join guards, payment state machine, baseline→eligibility recalculation,
// scoring, admin review) with zero network and zero production impact.
//
// Nothing here touches Firebase — FakeFirebaseFirestore is a pure in-memory
// implementation of the cloud_firestore API.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';

import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_package_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_notification_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/admin_audit_log_repository.dart';

import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_notification_service.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';

/// A fully-wired challenge backend running on an in-memory Firestore.
class ChallengeHarness {
  final FakeFirebaseFirestore db;

  // Repositories
  final ChallengeRepository challengeRepo;
  final ChallengeParticipantRepository participantRepo;
  final ChallengeSubmissionRepository submissionRepo;
  final ChallengePackageRepository packageRepo;
  final PaymentRecordRepository paymentRepo;
  final ChallengeNotificationRepository notificationRepo;
  final AdminAuditLogRepository auditRepo;

  // Services
  final AdminAuditService auditService;
  final ChallengeNotificationService notificationService;
  final ParticipantEnrollmentService enrollment;
  final PaymentApprovalService payments;
  final SubmissionReviewService submissions;
  final ChallengeService challenges;
  final ChallengePackageService packages;

  ChallengeHarness._({
    required this.db,
    required this.challengeRepo,
    required this.participantRepo,
    required this.submissionRepo,
    required this.packageRepo,
    required this.paymentRepo,
    required this.notificationRepo,
    required this.auditRepo,
    required this.auditService,
    required this.notificationService,
    required this.enrollment,
    required this.payments,
    required this.submissions,
    required this.challenges,
    required this.packages,
  });

  factory ChallengeHarness() {
    final db = FakeFirebaseFirestore();

    final challengeRepo = ChallengeRepository(firestore: db);
    final participantRepo = ChallengeParticipantRepository(firestore: db);
    final submissionRepo = ChallengeSubmissionRepository(firestore: db);
    final packageRepo = ChallengePackageRepository(firestore: db);
    final paymentRepo = PaymentRecordRepository(firestore: db);
    final notificationRepo = ChallengeNotificationRepository(firestore: db);
    final auditRepo = AdminAuditLogRepository(firestore: db);

    final auditService = AdminAuditService(auditLogRepository: auditRepo);
    final notificationService = ChallengeNotificationService(
      notificationRepository: notificationRepo,
      participantRepository: participantRepo,
      submissionRepository: submissionRepo,
    );
    final enrollment = ParticipantEnrollmentService(
      participantRepository: participantRepo,
      challengeRepository: challengeRepo,
      auditService: auditService,
      notificationService: notificationService,
    );
    final payments = PaymentApprovalService(
      paymentRepository: paymentRepo,
      participantRepository: participantRepo,
      challengeRepository: challengeRepo,
      auditService: auditService,
      notificationService: notificationService,
    );
    final submissions = SubmissionReviewService(
      submissionRepository: submissionRepo,
      participantRepository: participantRepo,
      challengeRepository: challengeRepo,
      auditService: auditService,
      notificationService: notificationService,
    );
    final challenges = ChallengeService(
      challengeRepository: challengeRepo,
      auditService: auditService,
      packageRepository: packageRepo,
    );
    final packages = ChallengePackageService(
      packageRepository: packageRepo,
      participantRepository: participantRepo,
    );

    return ChallengeHarness._(
      db: db,
      challengeRepo: challengeRepo,
      participantRepo: participantRepo,
      submissionRepo: submissionRepo,
      packageRepo: packageRepo,
      paymentRepo: paymentRepo,
      notificationRepo: notificationRepo,
      auditRepo: auditRepo,
      auditService: auditService,
      notificationService: notificationService,
      enrollment: enrollment,
      payments: payments,
      submissions: submissions,
      challenges: challenges,
      packages: packages,
    );
  }

  // ─── Constants used across tests ──────────────────────────────────────────
  static const String adminId = 'admin-uid-1';

  // ─── Seed helpers ───────────────────────────────────────────────────────

  /// Writes a challenge doc directly (bypassing draft/auto-id) so tests can
  /// use deterministic IDs. Defaults to a registration-open challenge whose
  /// window is "now" so baseline/weekly submissions are allowed.
  Future<Challenge> seedChallenge({
    String id = 'ch-1',
    String status = ChallengeStatus.registrationOpen,
    double registrationFee = 25.0,
    int maxParticipants = 100,
    bool baselineRequired = true,
    bool finalPhotoRequired = true,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? registrationDeadline,
  }) async {
    final now = DateTime.now();
    final challenge = Challenge(
      id: id,
      title: 'Test Challenge $id',
      description: 'A challenge used by the automated test suite.',
      startDate: startDate ?? now.subtract(const Duration(days: 1)),
      endDate: endDate ?? now.add(const Duration(days: 30)),
      registrationDeadline:
          registrationDeadline ?? now.add(const Duration(days: 7)),
      registrationFee: registrationFee,
      maxParticipants: maxParticipants,
      prizeDescription: '\$500 grand prize',
      rulesSummary: 'Be consistent. No cheating.',
      baselineRequired: baselineRequired,
      finalPhotoRequired: finalPhotoRequired,
      status: status,
      createdByAdminId: adminId,
      createdAt: now,
    );
    await challengeRepo.createChallenge(challenge);
    return challenge;
  }

  /// Adds an active package to a challenge (needed for activation + realistic
  /// joins).
  Future<ChallengePackage> seedPackage({
    required String challengeId,
    String id = 'pkg-1',
    double price = 25.0,
    bool isActive = true,
  }) async {
    final pkg = ChallengePackage(
      id: id,
      challengeId: challengeId,
      name: 'Standard Entry',
      description: 'Challenge entry + starter kit',
      packagePrice: price,
      isActive: isActive,
      shopifyVariants: [
        ChallengeShopifyVariant(
          productId: 'p1',
          variantId: 'v1',
          quantity: 1,
        ),
      ],
    );
    await packageRepo.savePackage(pkg);
    return pkg;
  }

  // ─── Read-back helpers ────────────────────────────────────────────────────

  Future<ChallengeParticipant?> participant(String challengeId, String userId) =>
      participantRepo.getParticipant(challengeId, userId);

  Future<List<ChallengeSubmission>> submissionsFor(String userId) =>
      submissionRepo.streamSubmissionsByParticipant(userId).first;

  /// The most recent submission of a given type for a user (by createdAt).
  Future<ChallengeSubmission?> latestSubmission(
      String userId, String type) async {
    final all = await submissionsFor(userId);
    final ofType = all.where((s) => s.type == type).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    return ofType.isEmpty ? null : ofType.first;
  }

  Future<List<PaymentRecord>> paymentsFor(String userId) =>
      paymentRepo.streamPaymentsByUser(userId).first;

  /// The most recent payment record for a user.
  Future<PaymentRecord?> latestPayment(String userId) async {
    final all = await paymentsFor(userId);
    if (all.isEmpty) return null;
    all.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return all.first;
  }

  /// Count of notifications delivered to a user (used to assert side effects).
  Future<int> notificationCount(String userId) async {
    final snap = await db
        .collection(FirestoreCollections.notifications)
        .where('recipientUserId', isEqualTo: userId)
        .get();
    return snap.docs.length;
  }

  /// Count of audit-log entries (asserts admin actions are recorded).
  Future<int> auditLogCount() async {
    final snap = await db.collection(FirestoreCollections.adminAuditLogs).get();
    return snap.docs.length;
  }

  /// Drives a participant all the way to an approved, prize-eligible baseline
  /// so submission tests can start from a known-good state. Returns the userId.
  Future<String> seedActivePaidParticipant({
    required String challengeId,
    required String userId,
    double weight = 200.0,
    double bodyFat = 30.0,
    double? muscle,
  }) async {
    await enrollment.joinChallenge(userId: userId, challengeId: challengeId);
    await enrollment.approveParticipant(challengeId, userId, adminId);
    await payments.submitManualPayment(
      userId: userId,
      challengeId: challengeId,
      amount: 25.0,
      method: PaymentMethod.zelle,
      externalTransactionId: 'ref-$userId',
    );
    final pay = await latestPayment(userId);
    await payments.approvePayment(pay!.id, adminId);
    await submissions.submitBaseline(userId, challengeId, {
      'weight': weight,
      'unit': 'lbs',
      'bodyFat': bodyFat,
      if (muscle != null) 'muscleMass': muscle,
      'source': 'manualEntry',
      'photos': <String>['https://example.com/baseline.jpg'],
    });
    final baseline = await latestSubmission(userId, SubmissionType.baseline);
    await submissions.approveSubmission(baseline!.id, adminId);
    return userId;
  }
}
