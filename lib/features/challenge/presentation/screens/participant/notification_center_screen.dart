import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_notification.dart';
import 'package:elefit_app/features/challenge/presentation/providers/notification_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_dashboard_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_leaderboard_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_my_submissions_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_weekly_checkin_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/submissions/participant_final_submission_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Notifications', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationProvider>().markAllAsRead(),
            child: const Text('Mark all as read', style: TextStyle(color: AppTheme.lime, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(provider.errorMessage!);
          }

          if (provider.notifications.isEmpty) {
            return _buildEmptyState();
          }

          return _buildNotificationList(context, provider.notifications);
        },
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, List<ChallengeNotification> notifications) {
    final now = DateTime.now();
    final today = notifications.where((n) {
      final date = n.createdAt ?? now;
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).toList();

    final earlier = notifications.where((n) {
      final date = n.createdAt ?? now;
      return !(date.year == now.year && date.month == now.month && date.day == now.day);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        // Real-time stream handles refresh, but we can provide a small delay for feedback
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppTheme.lime,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          if (today.isNotEmpty) ...[
            _buildSectionHeader('TODAY'),
            ...today.map((n) => _NotificationCard(notification: n)),
            const SizedBox(height: 24),
          ],
          if (earlier.isNotEmpty) ...[
            _buildSectionHeader('EARLIER'),
            ...earlier.map((n) => _NotificationCard(notification: n)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, color: AppTheme.textTertiary, size: 64),
          SizedBox(height: 16),
          Text('No notifications yet.', style: AppTheme.bodyLG),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMD.copyWith(color: AppTheme.error)),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final ChallengeNotification notification;

  const _NotificationCard({Key? key, required this.notification}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EFCard(
        onTap: () => _handleTap(context, provider),
        color: notification.isRead ? AppTheme.surface1 : AppTheme.surface1.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getTypeLabel(),
                          style: AppTheme.labelSM.copyWith(
                            color: _getTypeColor(),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.title,
                    style: AppTheme.headingSM.copyWith(
                      fontSize: 14,
                      color: notification.isRead ? AppTheme.textPrimary : Colors.white,
                      fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: AppTheme.bodySM.copyWith(
                      color: notification.isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 20),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, NotificationProvider provider) {
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    final deepLink = notification.deepLink;
    final challengeId = notification.challengeId ?? notification.data?['challengeId'];

    if (deepLink == null || challengeId == null) return;

    if (deepLink == 'challenge_dashboard') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantChallengeDashboardScreen(challengeId: challengeId)));
    } else if (deepLink == 'leaderboard') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantLeaderboardScreen(challengeId: challengeId)));
    } else if (deepLink == 'my_submissions') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantMySubmissionsScreen(challengeId: challengeId)));
    } else if (deepLink == 'weekly_checkin') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantWeeklyCheckinScreen(challengeId: challengeId)));
    } else if (deepLink == 'final_submission') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantFinalSubmissionScreen(challengeId: challengeId)));
    }
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color = AppTheme.lime;

    switch (notification.type) {
      case 'submissionApproved':
        iconData = Icons.check_circle_outline_rounded;
        break;
      case 'submissionRejected':
        iconData = Icons.cancel_outlined;
        color = AppTheme.error;
        break;
      case 'resubmissionRequested':
        iconData = Icons.error_outline_rounded;
        color = AppTheme.purple;
        break;
      case 'paymentApproved':
        iconData = Icons.payments_outlined;
        break;
      case 'challengeJoined':
        iconData = Icons.emoji_events_outlined;
        break;
      case 'weeklyCheckInOpen':
        iconData = Icons.event_available_rounded;
        break;
      case 'weeklyCheckInDue':
        iconData = Icons.notification_important_rounded;
        color = AppTheme.purple;
        break;
      case 'finalSubmissionOpen':
        iconData = Icons.assignment_turned_in_rounded;
        break;
      case 'finalSubmissionDue':
        iconData = Icons.announcement_rounded;
        color = AppTheme.purple;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  String _getTypeLabel() {
    switch (notification.type) {
      case 'submissionApproved': return '✓ APPROVED';
      case 'submissionRejected': return '✕ REJECTED';
      case 'resubmissionRequested': return '⚠ ACTION REQUIRED';
      case 'paymentApproved': return '💰 PAYMENT';
      case 'challengeJoined': return '🏆 CHALLENGE';
      case 'weeklyCheckInOpen': return '📅 CHECK-IN OPEN';
      case 'weeklyCheckInDue': return '⚠ DUE SOON';
      case 'finalSubmissionOpen': return '🏁 FINAL OPEN';
      case 'finalSubmissionDue': return '🏁 FINAL REMINDER';
      default: return 'NOTIFICATION';
    }
  }

  Color _getTypeColor() {
    switch (notification.type) {
      case 'submissionRejected': return AppTheme.error;
      case 'resubmissionRequested': return AppTheme.purple;
      case 'weeklyCheckInDue': return AppTheme.purple;
      case 'finalSubmissionDue': return AppTheme.purple;
      default: return AppTheme.lime;
    }
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }
}
