import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_challenge_list_provider.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
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
              _StatusBadge(status: challenge.status),
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
        Text(label, style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'draft':
        color = Colors.grey;
        break;
      case 'registrationOpen':
        color = AppTheme.lime;
        break;
      case 'active':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = AppTheme.error;
        break;
      default:
        color = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
