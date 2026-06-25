import 'package:elefit_app/features/challenge/data/models/challenge_notification.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_notification_repository.dart';

class ChallengeNotificationService {
  final ChallengeNotificationRepository _notificationRepository;

  ChallengeNotificationService({
    required ChallengeNotificationRepository notificationRepository,
  }) : _notificationRepository = notificationRepository;

  Future<void> createChallengeNotification({
    required String recipientUserId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    String? adminId,
  }) async {
    final notification = ChallengeNotification(
      id: '',
      recipientUserId: recipientUserId,
      title: title,
      body: body,
      type: type,
      data: data,
      createdAt: DateTime.now(),
      createdByAdminId: adminId,
    );
    await _notificationRepository.createNotification(notification);
  }

  Future<void> notifyParticipantJoined(String userId, String challengeTitle) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Challenge Joined!',
      body: 'You have successfully joined "$challengeTitle". Complete your baseline submission to get started.',
      type: 'challenge_update',
    );
  }

  Future<void> notifyPaymentApproved(String userId, String challengeTitle) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Payment Approved',
      body: 'Your payment for "$challengeTitle" has been approved. You are now an active participant!',
      type: 'payment_update',
    );
  }

  Future<void> notifySubmissionApproved(String userId, String challengeTitle, String submissionType) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Submission Approved',
      body: 'Your $submissionType submission for "$challengeTitle" has been approved.',
      type: 'challenge_update',
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationRepository.markNotificationAsRead(notificationId);
  }

  Stream<List<ChallengeNotification>> streamUserNotifications(String userId) {
    return _notificationRepository.streamNotificationsForUser(userId);
  }
}
