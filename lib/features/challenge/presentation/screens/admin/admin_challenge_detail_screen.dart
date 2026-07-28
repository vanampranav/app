import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/domain/services/leaderboard_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_challenge_detail_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_create_edit_challenge_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_participants_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_payments_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_submissions_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_packages_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_payments_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_eligibility_dashboard_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_audit_logs_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_winner_selection_screen.dart';

import 'package:elefit_app/features/challenge/domain/services/challenge_notification_service.dart';

class AdminChallengeDetailScreen extends StatelessWidget {
  final String challengeId;

  const AdminChallengeDetailScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminChallengeDetailProvider(
          challengeId: challengeId,
          challengeRepository: ctx.read<ChallengeRepository>(),
          challengeService: ctx.read<ChallengeService>(),
          notificationService: ctx.read<ChallengeNotificationService>(),
        ),
        child: const _AdminChallengeDetailContent(),
      ),
    );
  }
}

class _AdminChallengeDetailContent extends StatelessWidget {
  const _AdminChallengeDetailContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Consumer<AdminChallengeDetailProvider>(
      builder: (context, provider, _) {
        final challenge = provider.challenge;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(challenge?.title ?? 'Challenge Details', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
            actions: [
              if (challenge != null && challenge.status == ChallengeStatus.draft)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.lime),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminCreateEditChallengeScreen(
                        challengeId: challenge.id,
                        existingChallenge: challenge,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
              : provider.errorMessage != null
                  ? _buildErrorState(context, provider.errorMessage!)
                  : challenge == null
                      ? _buildNotFoundState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusBanner(challenge),
                              const SizedBox(height: 24),
                              _buildSectionTitle('DESCRIPTION'),
                              const SizedBox(height: 8),
                              Text(challenge.description, style: AppTheme.bodyMD),
                              const SizedBox(height: 24),
                              _buildInfoGrid(challenge, dateFormat),
                              const SizedBox(height: 32),
                              _buildSectionTitle('PRIZE DETAILS'),
                              const SizedBox(height: 8),
                              Text(challenge.prizeDescription, style: AppTheme.bodyMD),
                              const SizedBox(height: 24),
                              _buildSectionTitle('RULES SUMMARY'),
                              const SizedBox(height: 8),
                              Text(challenge.rulesSummary, style: AppTheme.bodyMD),
                              const SizedBox(height: 32),
                              _buildSectionTitle('REQUIREMENTS'),
                              const SizedBox(height: 12),
                              _buildRequirementRow('Baseline Submission', challenge.baselineRequired),
                              _buildRequirementRow('Final Photo for Prizes', challenge.finalPhotoRequired),
                              const SizedBox(height: 40),
                              _buildManagementActions(context, challenge),
                              const SizedBox(height: 40),
                              _buildUtilityActions(context, provider, challenge),
                              const SizedBox(height: 40),
                              _buildLifecycleActions(context, provider, challenge),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildStatusBanner(Challenge challenge) {
    Color color;
    switch (challenge.status) {
      case 'draft': color = Colors.grey; break;
      case 'registrationOpen': color = AppTheme.lime; break;
      case 'active': color = Colors.blue; break;
      case 'completed': color = Colors.green; break;
      case 'cancelled': color = AppTheme.error; break;
      default: color = Colors.white;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'STATUS: ${challenge.status.toUpperCase()}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTheme.labelMD.copyWith(letterSpacing: 2.0));
  }

  Widget _buildInfoGrid(Challenge challenge, DateFormat dateFormat) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoItem('Start Date', dateFormat.format(challenge.startDate))),
            const SizedBox(width: 16),
            Expanded(child: _buildInfoItem('End Date', dateFormat.format(challenge.endDate))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInfoItem('Registration Deadline', dateFormat.format(challenge.registrationDeadline))),
            const SizedBox(width: 16),
            Expanded(child: _buildInfoItem('Registration Fee', '\$${challenge.registrationFee.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoItem('Max Participants', '${challenge.maxParticipants}'),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.numericMD.copyWith(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String label, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            isRequired ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isRequired ? AppTheme.lime : AppTheme.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTheme.bodyMD)),
        ],
      ),
    );
  }

  Widget _buildManagementActions(BuildContext context, Challenge challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MANAGEMENT'),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.people_outline_rounded,
          label: 'View Participants',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminParticipantsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.payments_outlined,
          label: 'Review Payments',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPaymentsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.assignment_outlined,
          label: 'Review Submissions',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSubmissionsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.payments_outlined,
          label: 'Payment Tracking',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminChallengePaymentsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.dashboard_customize_outlined,
          label: 'Eligibility Dashboard',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminChallengeEligibilityDashboardScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.history_rounded,
          label: 'View Audit Logs',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAuditLogsScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.inventory_2_outlined,
          label: 'Manage Packages',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminChallengePackagesScreen(challengeId: challenge.id))),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.leaderboard_outlined,
          label: 'Refresh Leaderboard',
          onTap: () => _refreshLeaderboard(context, challenge.id),
        ),
        if (challenge.status == ChallengeStatus.completed) ...[
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            icon: Icons.emoji_events_outlined,
            label: challenge.resultsPublished ? 'Edit Winners' : 'Select Winners',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AdminWinnerSelectionScreen(challengeId: challenge.id))),
          ),
        ],
      ],
    );
  }

  /// Recomputes and republishes the sanitized public leaderboard. Needed to
  /// backfill challenges whose submissions were approved before auto-publish,
  /// or to force a refresh. Auto-refresh already runs on each submission review.
  Future<void> _refreshLeaderboard(BuildContext context, String challengeId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Refreshing leaderboard…')),
    );
    await context.read<LeaderboardService>().recomputeAndPublish(challengeId);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Leaderboard updated.'),
        backgroundColor: AppTheme.lime,
      ),
    );
  }

  Widget _buildUtilityActions(BuildContext context, AdminChallengeDetailProvider provider, Challenge challenge) {
    if (challenge.status != 'active' && challenge.status != 'registrationOpen') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('UTILITIES (TESTING)'),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.notifications_active_outlined,
          label: 'Send Check-in Open Notification',
          onTap: () => _showReminderDialog(context, provider, 'open'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.notification_important_outlined,
          label: 'Send Due Date Reminders',
          onTap: () => _showReminderDialog(context, provider, 'due'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.assignment_turned_in_outlined,
          label: 'Send Final Submission Open',
          onTap: () => _showFinalReminderDialog(context, provider, 'open'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          icon: Icons.announcement_outlined,
          label: 'Send Final Due Reminders',
          onTap: () => _showFinalReminderDialog(context, provider, 'due'),
        ),
      ],
    );
  }

  Future<void> _showFinalReminderDialog(BuildContext context, AdminChallengeDetailProvider provider, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: Text(type == 'open' ? 'Send Final Open Notification' : 'Send Final Due Reminders', style: AppTheme.headingSM),
        content: Text(type == 'open' 
          ? 'This will notify all active participants that final submission is now open.' 
          : 'This will remind all active participants who haven\'t submitted their final data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (type == 'open') {
        await provider.triggerFinalSubmissionOpen();
      } else {
        await provider.triggerFinalSubmissionDueReminders();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications triggered successfully'), backgroundColor: AppTheme.lime),
        );
      }
    }
  }

  Future<void> _showReminderDialog(BuildContext context, AdminChallengeDetailProvider provider, String type) async {
    final controller = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: Text(type == 'open' ? 'Send "Week Open" Notifications' : 'Send "Check-in Due" Reminders', style: AppTheme.headingSM),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Target week number:', style: AppTheme.bodySM),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface2,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final week = int.parse(controller.text);
      if (type == 'open') {
        await provider.triggerWeeklyCheckInOpen(week);
      } else {
        await provider.triggerWeeklyCheckInDueReminders(week);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications triggered successfully'), backgroundColor: AppTheme.lime),
        );
      }
    }
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return EFCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.lime),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTheme.labelLG,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
        ],
      ),
    );
  }

  Widget _buildLifecycleActions(BuildContext context, AdminChallengeDetailProvider provider, Challenge challenge) {
    final authService = context.read<AuthService>();
    final adminId = authService.currentUser?.id ?? '';

    if (challenge.status == ChallengeStatus.draft) {
      return EFButton(
        label: 'Activate Challenge',
        onTap: provider.isActionInProgress ? null : () => _confirmActivate(context, provider, adminId),
        loading: provider.isActionInProgress,
      );
    }

    if (challenge.status == ChallengeStatus.registrationOpen || 
        challenge.status == ChallengeStatus.active) {
      return EFButton(
        label: 'Close Challenge',
        variant: EFButtonVariant.danger,
        onTap: provider.isActionInProgress ? null : () => _confirmClose(context, provider, adminId),
        loading: provider.isActionInProgress,
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _confirmActivate(BuildContext context, AdminChallengeDetailProvider provider, String adminId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Activate Challenge?', style: AppTheme.headingSM),
        content: const Text('This will open the challenge for registrations. You will no longer be able to edit core configurations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.activateChallenge(adminId);
      if (context.mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _confirmClose(BuildContext context, AdminChallengeDetailProvider provider, String adminId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Close Challenge?', style: AppTheme.headingSM),
        content: const Text('This will end the challenge and prevent any further registrations or submissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.closeChallenge(adminId);
      if (context.mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
      }
    }
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMD),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Center(
      child: Text('Challenge not found', style: AppTheme.bodyLG),
    );
  }
}
