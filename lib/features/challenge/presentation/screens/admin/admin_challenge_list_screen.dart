import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_challenge_list_provider.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/challenge_status_label.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_detail_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_create_edit_challenge_screen.dart';

class AdminChallengeListScreen extends StatelessWidget {
  const AdminChallengeListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminChallengeListProvider(
          challengeRepository: ctx.read<ChallengeRepository>(),
        ),
        child: const _AdminChallengeListContent(),
      ),
    );
  }
}

class _AdminChallengeListContent extends StatelessWidget {
  const _AdminChallengeListContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Manage Challenges', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminCreateEditChallengeScreen()),
        ),
        label: const Text('Create Challenge'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.lime,
        foregroundColor: Colors.black,
      ),
      body: Consumer<AdminChallengeListProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(provider.errorMessage!, textAlign: TextAlign.center, style: AppTheme.bodyMD),
                    const SizedBox(height: 24),
                    EFButton(
                      label: 'Retry',
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminChallengeListScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.challenges.isEmpty) {
            return const Center(
              child: Text(
                'No challenges created yet.',
                style: AppTheme.bodyLG,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.challenges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final challenge = provider.challenges[i];
              return _ChallengeAdminCard(challenge: challenge);
            },
          );
        },
      ),
    );
  }
}

class _ChallengeAdminCard extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeAdminCard({Key? key, required this.challenge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return EFCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminChallengeDetailScreen(challengeId: challenge.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTheme.headingSM,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(challenge: challenge),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                color: AppTheme.surface2,
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: const [
                      Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                      SizedBox(width: 8),
                      Text('Delete challenge', style: TextStyle(color: AppTheme.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: '${dateFormat.format(challenge.startDate)} - ${dateFormat.format(challenge.endDate)}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Fee: \$' + challenge.registrationFee.toStringAsFixed(2),
                ),
              ),
              Expanded(
                child: _InfoRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Max: ${challenge.maxParticipants}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Delete challenge?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This permanently deletes "${challenge.title}". This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final adminId = context.read<AuthService>().currentUser?.id ?? '';
      await context.read<ChallengeService>().deleteChallenge(challenge.id, adminId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${challenge.title}"'), backgroundColor: AppTheme.surface2),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({Key? key, required this.icon, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Challenge challenge;

  const _StatusBadge({Key? key, required this.challenge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final view = challengeStatusView(challenge);
    final color = view.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        view.label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      ),
    );
  }
}
