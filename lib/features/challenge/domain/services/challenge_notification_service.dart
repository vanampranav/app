import 'package:elefit_app/features/challenge/data/models/challenge_notification.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_notification_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ChallengeNotificationService {
  final ChallengeNotificationRepository _notificationRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;

  ChallengeNotificationService({
    required ChallengeNotificationRepository notificationRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeSubmissionRepository submissionRepository,
  })  : _notificationRepository = notificationRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository;

  Future<void> createChallengeNotification({
    required String recipientUserId,
    String? challengeId,
    required String title,
    required String body,
    required String type,
    String category = 'challenge',
    String priority = 'normal',
    Map<String, dynamic>? data,
    String? deepLink,
    String? adminId,
  }) async {
    final notification = ChallengeNotification(
      id: '',
      recipientUserId: recipientUserId,
      challengeId: challengeId,
      title: title,
      body: body,
      type: type,
      category: category,
      priority: priority,
      data: data,
      deepLink: deepLink,
      createdAt: DateTime.now(),
      createdByAdminId: adminId,
    );
    await _notificationRepository.createNotification(notification);
  }

  Future<void> notifyParticipantJoined(String userId, String challengeTitle, String challengeId) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Challenge Joined!',
      body: 'You have successfully joined "$challengeTitle". Complete your baseline submission to get started.',
      type: 'challengeJoined',
      data: {'challengeId': challengeId},
      deepLink: 'challenge_dashboard',
    );
  }

  Future<void> notifyPaymentApproved(String userId, String challengeTitle, String challengeId) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Payment Approved',
      body: 'Your payment for "$challengeTitle" has been approved. You are now an active participant!',
      type: 'paymentApproved',
      category: 'payment',
      data: {'challengeId': challengeId},
      deepLink: 'challenge_dashboard',
    );
  }

  Future<void> notifyParticipantApproved(String userId, String challengeTitle, String challengeId) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: "You're In!",
      body: 'Your entry to "$challengeTitle" has been approved. Open the challenge to complete your next steps.',
      type: 'participantApproved',
      category: 'participation',
      data: {'challengeId': challengeId},
      deepLink: 'challenge_dashboard',
    );
  }

  Future<void> notifyParticipantRejected(String userId, String challengeTitle, String challengeId, String reason) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Entry Not Approved',
      body: 'Your entry to "$challengeTitle" was not approved. Reason: $reason',
      type: 'participantRejected',
      category: 'participation',
      priority: 'high',
      data: {'challengeId': challengeId, 'reason': reason},
    );
  }

  Future<void> notifyPaymentFailed(String userId, String challengeTitle, String challengeId, String reason) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Payment Verification Failed',
      body: 'Please review your challenge payment for "$challengeTitle" and submit updated proof. Reason: $reason',
      type: 'paymentFailed',
      category: 'payment',
      priority: 'high',
      data: {'challengeId': challengeId, 'reason': reason},
      deepLink: 'challenge_dashboard',
    );
  }

  /// Turns a raw SubmissionType into readable text for notification copy.
  String _humanType(String t) {
    switch (t) {
      case 'weeklyCheckIn':
        return 'weekly check-in';
      case 'finalSubmission':
        return 'final';
      default:
        return t; // 'baseline'
    }
  }

  Future<void> notifySubmissionApproved(String userId, String challengeTitle, String submissionType, String challengeId) async {
    String body = 'Your ${_humanType(submissionType)} submission for "$challengeTitle" has been approved.';
    if (submissionType == 'baseline') {
      body = 'Your baseline has been approved. Your progress tracking for "$challengeTitle" is now active.';
    }

    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Submission Approved',
      body: body,
      type: 'submissionApproved',
      data: {'challengeId': challengeId, 'submissionType': submissionType},
      deepLink: submissionType == 'baseline' ? 'leaderboard' : 'challenge_dashboard',
    );
  }

  Future<void> notifySubmissionRejected(String userId, String challengeTitle, String submissionType, String challengeId) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Submission Rejected',
      body: 'Your ${_humanType(submissionType)} submission for "$challengeTitle" was rejected. Please review admin notes.',
      type: 'submissionRejected',
      priority: 'high',
      data: {'challengeId': challengeId, 'submissionType': submissionType},
      deepLink: 'my_submissions',
    );
  }

  Future<void> notifyResubmissionRequested(String userId, String challengeTitle, String submissionType, String challengeId) async {
    await createChallengeNotification(
      recipientUserId: userId,
      title: 'Action Required',
      body: 'Your ${_humanType(submissionType)} submission for "$challengeTitle" requires clarification. Please review notes and resubmit.',
      type: 'resubmissionRequested',
      priority: 'high',
      data: {'challengeId': challengeId, 'submissionType': submissionType},
      deepLink: 'my_submissions',
    );
  }

  // ─── Weekly Check-in Reminders ─────────────────────────────────────────────

  Future<void> createWeeklyCheckInOpenNotifications(String challengeId, int weekNumber, String challengeTitle) async {
    final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;
    
    for (var p in participants) {
      if (p.status == ParticipantStatus.active) {
        // Check if already notified
        final alreadyNotified = await hasReminderAlreadyBeenSent(challengeId, p.userId, weekNumber, 'weeklyCheckInOpen');
        if (alreadyNotified) continue;

        await createChallengeNotification(
          recipientUserId: p.userId,
          challengeId: challengeId,
          title: 'Week $weekNumber check-in is now open',
          body: 'Week $weekNumber check-in is now open for "$challengeTitle".',
          type: 'weeklyCheckInOpen',
          data: {'challengeId': challengeId, 'weekNumber': weekNumber},
          deepLink: 'weekly_checkin',
        );
      }
    }
  }

  Future<void> createWeeklyCheckInDueReminders(String challengeId, int weekNumber, String challengeTitle) async {
    final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;

    for (var p in participants) {
      if (p.status == ParticipantStatus.active) {
        // Check if submitted
        final hasSubmitted = await hasParticipantSubmittedWeeklyCheckIn(challengeId, p.userId, weekNumber);
        if (hasSubmitted) continue;

        // Check if already reminded
        final alreadyReminded = await hasReminderAlreadyBeenSent(challengeId, p.userId, weekNumber, 'weeklyCheckInDue');
        if (alreadyReminded) continue;

        await createChallengeNotification(
          recipientUserId: p.userId,
          challengeId: challengeId,
          title: 'Action Required',
          body: 'Reminder: submit your Week $weekNumber check-in for "$challengeTitle".',
          type: 'weeklyCheckInDue',
          priority: 'high',
          data: {'challengeId': challengeId, 'weekNumber': weekNumber},
          deepLink: 'weekly_checkin',
        );
      }
    }
  }

  Future<bool> hasParticipantSubmittedWeeklyCheckIn(String challengeId, String userId, int weekNumber) async {
    final submissions = await _submissionRepository.streamSubmissionsByParticipant(userId).first;
    return submissions.any((s) => 
      s.challengeId == challengeId && 
      s.type == SubmissionType.weeklyCheckIn && 
      s.data['weekNumber'] == weekNumber &&
      (s.reviewStatus == ReviewStatus.submitted || s.reviewStatus == ReviewStatus.approved)
    );
  }

  Future<bool> hasReminderAlreadyBeenSent(String challengeId, String userId, int weekNumber, String type) async {
    final notifications = await _notificationRepository.streamNotificationsForUser(userId).first;
    return notifications.any((n) => 
      n.type == type && 
      n.data?['challengeId'] == challengeId && 
      n.data?['weekNumber'] == weekNumber
    );
  }

  // ─── Final Submission Reminders ───────────────────────────────────────────

  Future<void> createFinalSubmissionOpenNotifications(String challengeId, String challengeTitle) async {
    final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;

    for (var p in participants) {
      if (p.status == ParticipantStatus.active) {
        final alreadyNotified = await hasFinalReminderAlreadyBeenSent(challengeId, p.userId, 'finalSubmissionOpen');
        if (alreadyNotified) continue;

        await createChallengeNotification(
          recipientUserId: p.userId,
          challengeId: challengeId,
          title: 'Final submission is open',
          body: 'Submit your final measurements and photos for "$challengeTitle" to complete the challenge.',
          type: 'finalSubmissionOpen',
          priority: 'high',
          data: {'challengeId': challengeId, 'submissionType': 'final'},
          deepLink: 'final_submission',
        );
      }
    }
  }

  Future<void> createFinalSubmissionDueReminders(String challengeId, String challengeTitle) async {
    final participants = await _participantRepository.streamParticipantsByChallenge(challengeId).first;

    for (var p in participants) {
      if (p.status == ParticipantStatus.active) {
        final hasSubmitted = await hasParticipantSubmittedFinalSubmission(challengeId, p.userId);
        if (hasSubmitted) continue;

        final alreadyReminded = await hasFinalReminderAlreadyBeenSent(challengeId, p.userId, 'finalSubmissionDue');
        if (alreadyReminded) continue;

        await createChallengeNotification(
          recipientUserId: p.userId,
          challengeId: challengeId,
          title: 'Final submission reminder',
          body: 'Complete your final submission for "$challengeTitle" before the deadline.',
          type: 'finalSubmissionDue',
          priority: 'high',
          data: {'challengeId': challengeId, 'submissionType': 'final'},
          deepLink: 'final_submission',
        );
      }
    }
  }

  Future<bool> hasParticipantSubmittedFinalSubmission(String challengeId, String userId) async {
    final submissions = await _submissionRepository.streamSubmissionsByParticipant(userId).first;
    return submissions.any((s) => 
      s.challengeId == challengeId && 
      s.type == SubmissionType.finalSubmission && 
      (s.reviewStatus == ReviewStatus.submitted || s.reviewStatus == ReviewStatus.approved || s.reviewStatus == ReviewStatus.needsClarification)
    );
  }

  Future<bool> hasFinalReminderAlreadyBeenSent(String challengeId, String userId, String type) async {
    final notifications = await _notificationRepository.streamNotificationsForUser(userId).first;
    return notifications.any((n) => 
      n.type == type && 
      n.challengeId == challengeId
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationRepository.markNotificationAsRead(notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _notificationRepository.markAllAsRead(userId);
  }

  Stream<List<ChallengeNotification>> streamUserNotifications(String userId) {
    return _notificationRepository.streamNotificationsForUser(userId);
  }

  Stream<int> streamUnreadCount(String userId) {
    return _notificationRepository.streamUnreadNotificationsForUser(userId).map((list) => list.length);
  }
}
