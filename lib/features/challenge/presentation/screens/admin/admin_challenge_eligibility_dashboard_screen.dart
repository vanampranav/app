import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_eligibility_dashboard_provider.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';

class AdminChallengeEligibilityDashboardScreen extends StatelessWidget {
  final String challengeId;

  const AdminChallengeEligibilityDashboardScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminEligibilityDashboardProvider(
          challengeId: challengeId,
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
          userRepository: ctx.read<UserRepository>(),
          auditService: ctx.read<AdminAuditService>(),
        ),
        child: const _AdminEligibilityDashboardContent(),
      ),
    );
  }
}

class _AdminEligibilityDashboardContent extends StatelessWidget {
  const _AdminEligibilityDashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminEligibilityDashboardProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Eligibility Dashboard', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: provider.isLoading
              ? const EFLoadingStateView(message: 'Loading dashboard...')
              : provider.errorMessage != null
                  ? EFErrorView(
                      title: 'Error',
                      message: provider.errorMessage!,
                      onRetry: () => provider.setFilter('All'), // Trigger reload
                    )
                  : Column(
                      children: [
                        _buildSummaryGrids(context, provider),
                        _buildSearchAndFilters(context, provider),
                        Expanded(child: _buildParticipantList(context, provider)),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildSummaryGrids(BuildContext context, AdminEligibilityDashboardProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _SummaryCard(label: 'TOTAL', value: '${provider.totalCount}', color: Colors.blue),
          _SummaryCard(label: 'ELIGIBLE', value: '${provider.eligibleCount}', color: AppTheme.lime),
          _SummaryCard(label: 'NOT ELIGIBLE', value: '${provider.notEligibleCount}', color: Colors.amber),
          _SummaryCard(label: 'PAID', value: '${provider.paymentVerifiedCount}', color: Colors.green),
          _SummaryCard(label: 'UNPAID', value: '${provider.paymentPendingCount}', color: Colors.red),
          _SummaryCard(label: 'BASELINE', value: '${provider.baselineSubmittedCount}', color: Colors.purple),
          _SummaryCard(label: 'DISQUALIFIED', value: '${provider.disqualifiedCount}', color: AppTheme.error),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, AdminEligibilityDashboardProvider provider) {
    final filters = ['All', 'Eligible', 'Not Eligible', 'Payment Pending', 'Missing Baseline', 'Disqualified'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, nickname or email',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.surface1,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: provider.setSearchQuery,
          ),
        ),
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final filter = filters[i];
              final isSelected = provider.currentFilter == filter;
              return GestureDetector(
                onTap: () => provider.setFilter(filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.lime : AppTheme.surface1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantList(BuildContext context, AdminEligibilityDashboardProvider provider) {
    if (provider.viewModels.isEmpty) {
      return const EFEmptyStateView(
        title: 'No Results',
        message: 'No participants match your criteria.',
        icon: Icons.person_search_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.viewModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final vm = provider.viewModels[i];
        return _EligibilityParticipantCard(viewModel: vm);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.numericMD.copyWith(fontSize: 20, color: color)),
        ],
      ),
    );
  }
}

class _EligibilityParticipantCard extends StatelessWidget {
  final ParticipantEligibilityViewModel viewModel;

  const _EligibilityParticipantCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = viewModel.participant;
    final df = DateFormat('MMM dd');
    final adminId = context.read<AuthService>().currentUser?.id ?? '';
    final provider = context.read<AdminEligibilityDashboardProvider>();

    return EFCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(viewModel.displayName, style: AppTheme.headingSM),
                    Text(viewModel.email, style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontSize: 11)),
                    if (p.leaderboardDisplayName != null)
                      Text('Nickname: ${p.leaderboardDisplayName}', style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontSize: 10)),
                  ],
                ),
              ),
              _EligibilityBadge(isEligible: viewModel.isEligible, isDisqualified: p.disqualified),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusItem(label: 'PAYMENT', status: p.paymentStatus),
              _StatusItem(label: 'BASELINE', status: p.baselineSubmitted ? 'submitted' : 'missing'),
              _StatusItem(label: 'STATUS', status: p.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Last update: ${p.updatedAt != null ? df.format(p.updatedAt!) : 'N/A'}', 
                  style: AppTheme.bodySM.copyWith(fontSize: 10, color: AppTheme.textTertiary)),
              const Spacer(),
              EFButton(
                label: 'Actions',
                onTap: () => _showActions(context, provider, p, adminId),
                variant: EFButtonVariant.secondary,
                height: 32,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, AdminEligibilityDashboardProvider provider, ChallengeParticipant participant, String adminId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: AppTheme.lime),
              title: const Text('Add/Edit Admin Notes'),
              onTap: () {
                Navigator.pop(ctx);
                _showNotesDialog(context, provider, participant);
              },
            ),
            if (!participant.disqualified)
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppTheme.error),
                title: const Text('Disqualify Participant'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDisqualifyDialog(context, provider, participant, adminId);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded, color: Colors.green),
                title: const Text('Reinstate Participant'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReinstateDialog(context, provider, participant, adminId);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showNotesDialog(BuildContext context, AdminEligibilityDashboardProvider provider, ChallengeParticipant p) {
    final controller = TextEditingController(text: p.adminNotes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Admin Notes', style: AppTheme.headingSM),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface2, hintText: 'Private notes...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () {
              provider.updateNotes(p.id, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDisqualifyDialog(BuildContext context, AdminEligibilityDashboardProvider provider, ChallengeParticipant p, String adminId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('Disqualify Participant?', style: AppTheme.headingSM),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The participant will no longer be eligible for prizes. This action is audited.', style: AppTheme.bodySM),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface1, hintText: 'Reason for disqualification'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.disqualifyParticipant(p.id, adminId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Disqualify'),
          ),
        ],
      ),
    );
  }

  void _showReinstateDialog(BuildContext context, AdminEligibilityDashboardProvider provider, ChallengeParticipant p, String adminId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        title: const Text('Reinstate Participant?', style: AppTheme.headingSM),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Participant eligibility will be recalculated based on their payment and submission status.', style: AppTheme.bodySM),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface1, hintText: 'Reason for reinstatement'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.reinstateParticipant(p.id, adminId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Reinstate'),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String status;
  const _StatusItem({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
      case 'waived':
      case 'submitted':
      case 'active':
        color = AppTheme.lime;
        break;
      case 'pending':
      case 'partiallypaid':
        color = Colors.amber;
        break;
      case 'missing':
      case 'failed':
      case 'disqualified':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.textTertiary;
    }

    return Column(
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _EligibilityBadge extends StatelessWidget {
  final bool isEligible;
  final bool isDisqualified;
  const _EligibilityBadge({required this.isEligible, required this.isDisqualified});

  @override
  Widget build(BuildContext context) {
    final String label = isDisqualified ? 'DISQUALIFIED' : (isEligible ? 'ELIGIBLE' : 'NOT ELIGIBLE');
    final Color color = isDisqualified ? AppTheme.error : (isEligible ? AppTheme.lime : Colors.amber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
