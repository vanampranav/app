import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
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

    await _paymentRepository.createPaymentRecord(payment);
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
      final updatedParticipant = participant.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentRecordId: paymentId,
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
        paymentStatus: PaymentStatus.rejected,
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
  }

  Stream<List<PaymentRecord>> streamPendingPayments(String challengeId) {
    return _paymentRepository.streamPendingPayments(challengeId);
  }
}
