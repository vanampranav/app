import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/services/analytics_service.dart';
import 'admin_audit_service.dart';
import 'challenge_notification_service.dart';

class PaymentApprovalService {
  final PaymentRecordRepository _paymentRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeRepository _challengeRepository;
  final AdminAuditService _auditService;
  final ChallengeNotificationService _notificationService;

  PaymentApprovalService({
    required PaymentRecordRepository paymentRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeRepository challengeRepository,
    required AdminAuditService auditService,
    required ChallengeNotificationService notificationService,
  })  : _paymentRepository = paymentRepository,
        _participantRepository = participantRepository,
        _challengeRepository = challengeRepository,
        _auditService = auditService,
        _notificationService = notificationService;

  Future<void> submitManualPayment({
    required String userId,
    required String challengeId,
    required double amount,
    required String method,
    String? externalTransactionId,
    String? proofImageUrl,
  }) async {
    final payment = PaymentRecord(
      id: '', // Firestore will generate
      userId: userId,
      challengeId: challengeId,
      amount: amount,
      method: method,
      status: PaymentStatus.pending,
      externalTransactionId: externalTransactionId,
      proofImageUrl: proofImageUrl,
      createdAt: DateTime.now(),
    );

    final paymentId = await _paymentRepository.createPaymentRecord(payment);

    // Update participant payment status to pending_review
    final participant = await _participantRepository.getParticipant(challengeId, userId);
    if (participant != null) {
      await _participantRepository.updateParticipant(participant.copyWith(
        paymentStatus: PaymentStatus.pendingReview,
        paymentMethod: method,
        paymentReference: externalTransactionId,
        paymentProofUrl: proofImageUrl,
        paymentProofSubmittedAt: DateTime.now(),
        latestPaymentRecordId: paymentId,
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> approvePayment(String paymentId, String adminId) async {
    final payment = await _paymentRepository.getPaymentRecord(paymentId);
    if (payment == null) {
      throw Exception('Payment record not found.');
    }

    final previousData = payment.toMap();
    final updatedPayment = payment.copyWith(
      status: PaymentStatus.paid,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
      paymentDate: DateTime.now(),
    );

    await _paymentRepository.updatePaymentRecord(updatedPayment);

    // Also update participant payment status
    final participant = await _participantRepository.getParticipantByUserAndChallenge(payment.userId, payment.challengeId);
    if (participant != null) {
      // Recalculate eligibility based on all rules
      final bool isEligible = participant.baselineSubmitted && 
                              participant.status == ParticipantStatus.active && 
                              !participant.disqualified;

      final updatedParticipant = participant.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentRecordId: paymentId,
        latestPaymentRecordId: paymentId,
        eligibleForPrizes: isEligible,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _participantRepository.updateParticipant(updatedParticipant);
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: payment.challengeId,
      action: 'approve_payment',
      targetCollection: FirestoreCollections.paymentRecords,
      targetId: paymentId,
      previousData: previousData,
      newData: updatedPayment.toMap(),
    );

    final challenge = await _challengeRepository.getChallengeById(payment.challengeId);
    if (challenge != null) {
      await _notificationService.notifyPaymentApproved(payment.userId, challenge.title, challenge.id);
    }
  }

  Future<void> rejectPayment(String paymentId, String adminId, String reason) async {
    if (reason.isEmpty) {
      throw Exception('Reason is required for payment rejection.');
    }

    final payment = await _paymentRepository.getPaymentRecord(paymentId);
    if (payment == null) {
      throw Exception('Payment record not found.');
    }

    final previousData = payment.toMap();
    final updatedPayment = payment.copyWith(
      status: PaymentStatus.rejected,
      adminNotes: reason,
      lastUpdatedByAdminId: adminId,
      updatedAt: DateTime.now(),
    );

    await _paymentRepository.updatePaymentRecord(updatedPayment);

    // Also update participant payment status to rejected
    final participant = await _participantRepository.getParticipantByUserAndChallenge(payment.userId, payment.challengeId);
    if (participant != null) {
      final updatedParticipant = participant.copyWith(
        paymentStatus: PaymentStatus.failed,
        paymentFailureReason: reason,
        paymentFailedAt: DateTime.now(),
        paymentFailedByAdminId: adminId,
        latestPaymentRecordId: paymentId,
        eligibleForPrizes: false,
        updatedAt: DateTime.now(),
      );
      await _participantRepository.updateParticipant(updatedParticipant);
    }

    await _auditService.logAction(
      adminId: adminId,
      challengeId: payment.challengeId,
      action: 'reject_payment',
      targetCollection: FirestoreCollections.paymentRecords,
      targetId: paymentId,
      previousData: previousData,
      newData: updatedPayment.toMap(),
      reason: reason,
    );

    // Notify the participant that their payment was rejected and needs resubmission.
    final challenge = await _challengeRepository.getChallengeById(payment.challengeId);
    if (challenge != null) {
      await _notificationService.notifyPaymentFailed(
          payment.userId, challenge.title, challenge.id, reason);
    }
  }

  Stream<List<PaymentRecord>> streamPendingPayments(String challengeId) {
    return _paymentRepository.streamPendingPayments(challengeId);
  }

  Future<void> updateManualPaymentStatus({
    required String challengeId,
    required String userId,
    required String adminId,
    required String newStatus,
    double? amountCollected,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) async {
    final participant = await _participantRepository.getParticipant(challengeId, userId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }

    final previousData = participant.toMap();
    final previousStatus = participant.paymentStatus;
    
    // Determine prize eligibility based on all rules
    final bool isPaymentEligible = newStatus == PaymentStatus.paid || newStatus == PaymentStatus.waived;
    final bool isEligible = isPaymentEligible && 
                            participant.baselineSubmitted && 
                            participant.status == ParticipantStatus.active && 
                            !participant.disqualified;

    final updatedParticipant = participant.copyWith(
      paymentStatus: newStatus,
      paymentMethod: paymentMethod ?? participant.paymentMethod,
      amountCollected: amountCollected ?? participant.amountCollected,
      paymentReference: reference ?? participant.paymentReference,
      paymentNotes: notes ?? participant.paymentNotes,
      eligibleForPrizes: isEligible,
      verifiedByAdminId: adminId,
      paymentUpdatedAt: DateTime.now(),
      paidAt: newStatus == PaymentStatus.paid ? DateTime.now() : null,
      paymentFailureReason: newStatus == PaymentStatus.failed ? notes : participant.paymentFailureReason,
      paymentFailedAt: newStatus == PaymentStatus.failed ? DateTime.now() : participant.paymentFailedAt,
      paymentFailedByAdminId: newStatus == PaymentStatus.failed ? adminId : participant.paymentFailedByAdminId,
      paymentReviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);

    // Update the linked PaymentRecord if it exists
    if (participant.latestPaymentRecordId != null) {
      final record = await _paymentRepository.getPaymentRecord(participant.latestPaymentRecordId!);
      if (record != null) {
        await _paymentRepository.updatePaymentRecord(record.copyWith(
          status: newStatus,
          amount: amountCollected ?? record.amount,
          adminNotes: notes ?? record.adminNotes,
          lastUpdatedByAdminId: adminId,
          updatedAt: DateTime.now(),
        ));
      }
    }

    // Audit Logging
    await _auditService.logAction(
      adminId: adminId,
      challengeId: participant.challengeId,
      action: 'manual_payment_update',
      targetCollection: FirestoreCollections.challengeParticipants,
      targetId: userId,
      previousData: previousData,
      newData: updatedParticipant.toMap(),
      reason: notes,
    );

    // Analytics
    await AnalyticsService.logPaymentStatusChanged(
      challengeId: participant.challengeId,
      participantId: participant.userId,
      packageId: participant.selectedPackageId,
      previousStatus: previousStatus,
      newStatus: newStatus,
      paymentMethod: paymentMethod,
      amount: amountCollected,
    );

    final challenge = await _challengeRepository.getChallengeById(participant.challengeId);

    if (newStatus == PaymentStatus.paid) {
      await AnalyticsService.logPaymentVerified(
        challengeId: participant.challengeId,
        participantId: participant.userId,
        amount: amountCollected ?? participant.amountCollected,
        paymentMethod: paymentMethod ?? 'manual',
      );
      
      if (challenge != null) {
        await _notificationService.notifyPaymentApproved(participant.userId, challenge.title, challenge.id);
      }
    } else if (newStatus == PaymentStatus.failed) {
      if (challenge != null) {
        await _notificationService.notifyPaymentFailed(participant.userId, challenge.title, challenge.id, notes ?? 'Unknown reason');
      }
    }
  }

  Future<void> resubmitPaymentProof({
    required String challengeId,
    required String userId,
    required String reference,
    String? notes,
    String? proofUrl,
  }) async {
    final participant = await _participantRepository.getParticipant(challengeId, userId);
    if (participant == null) {
      throw Exception('Participant not found.');
    }

    if (participant.paymentStatus != PaymentStatus.failed) {
      throw Exception('Payment resubmission is only allowed for failed payments.');
    }

    // Create a new historical payment record for this attempt
    final payment = PaymentRecord(
      id: '', 
      userId: userId,
      challengeId: challengeId,
      amount: participant.amountDue,
      method: participant.paymentMethod ?? 'manual',
      status: PaymentStatus.pending,
      externalTransactionId: reference,
      proofImageUrl: proofUrl,
      adminNotes: 'Resubmission after failure.',
      createdAt: DateTime.now(),
    );
    final paymentId = await _paymentRepository.createPaymentRecord(payment);

    final updatedParticipant = participant.copyWith(
      paymentStatus: PaymentStatus.pendingReview,
      paymentReference: reference,
      paymentProofNotes: notes,
      paymentProofUrl: proofUrl,
      paymentProofSubmittedAt: DateTime.now(),
      latestPaymentRecordId: paymentId,
      eligibleForPrizes: false,
      updatedAt: DateTime.now(),
    );

    await _participantRepository.updateParticipant(updatedParticipant);

    await AnalyticsService.logEvent('payment_resubmitted_for_review', {
      'challenge_id': challengeId,
      'participant_id': userId,
      'payment_method': participant.paymentMethod ?? 'unknown',
    });
  }
}
