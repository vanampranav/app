import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_participants_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_participant_detail_screen.dart';

class AdminParticipantsScreen extends StatelessWidget {
  final String challengeId;

  const AdminParticipantsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminParticipantsProvider(
          challengeId: challengeId,
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
          userRepository: ctx.read<UserRepository>(),
          enrollmentService: ctx.read<ParticipantEnrollmentService>(),
        ),
        child: const _AdminParticipantsContent(),
      ),
    );
  }
}

class _AdminParticipantsContent extends StatelessWidget {
  const _AdminParticipantsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Participants', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<AdminParticipantsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilterBar(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const EFLoadingStateView(message: 'Loading participants...')
                    : provider.errorMessage != null
                        ? _buildErrorState(context, provider)
                        : provider.participants.isEmpty
                            ? EFEmptyStateView(
                                title: 'No Participants',
                                message: 'No ${provider.currentFilter.toLowerCase()} participants found.',
                                icon: Icons.people_outline_rounded,
                              )
                            : _buildParticipantList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AdminParticipantsProvider provider) {
    final filters = ['All', 'Pending', 'Approved', 'Rejected'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = provider.currentFilter == filter;
          
          return GestureDetector(
            onTap: () => provider.setFilter(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.lime : AppTheme.surface1,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? AppTheme.lime : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticipantList(BuildContext context, AdminParticipantsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: provider.participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final viewModel = provider.participants[i];
        return _ParticipantCard(viewModel: viewModel);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, AdminParticipantsProvider provider) {
    return EFErrorView.map(
      provider.errorMessage!,
      screenName: 'AdminParticipantsScreen',
      featureName: 'AdminManagement',
      onRetry: () => provider.fetchData(),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final ParticipantViewModel viewModel;

  const _ParticipantCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final participant = viewModel.participant;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final provider = context.read<AdminParticipantsProvider>();
    final adminId = context.read<AuthService>().currentUser?.id ?? '';

    return EFCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminParticipantDetailScreen(
          userId: participant.userId,
          challengeId: participant.challengeId,
        )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.displayName,
                      style: AppTheme.headingSM,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined: ${participant.joinedAt != null ? dateFormat.format(participant.joinedAt!) : 'N/A'}',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: participant.status, type: 'participant'),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USER ID: ${participant.userId.substring(0, 8)}...',
                      style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('PAYMENT STATUS', style: AppTheme.labelSM.copyWith(fontSize: 9)),
                    const SizedBox(height: 4),
                    _StatusBadge(status: participant.paymentStatus, type: 'payment'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (participant.status == ParticipantStatus.joined || participant.status == ParticipantStatus.invited)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.lime),
                      onPressed: () => _confirmApproval(context, provider, participant, adminId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                      onPressed: () => _showRejectionDialog(context, provider, participant, adminId),
                    ),
                  ],
                ),
            ],
          ),
          if (participant.adminNotes != null && participant.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${participant.adminNotes}',
                style: AppTheme.bodySM.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmApproval(BuildContext context, AdminParticipantsProvider provider, ChallengeParticipant participant, String adminId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Approve Participant?', style: AppTheme.headingSM),
        content: const Text('This will set the participant status to Active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.approveParticipant(participant.id, adminId);
      if (context.mounted) {
        if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participant approved.'), backgroundColor: AppTheme.lime));
        }
      }
    }
  }

  Future<void> _showRejectionDialog(BuildContext context, AdminParticipantsProvider provider, ChallengeParticipant participant, String adminId) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Reject Participant?', style: AppTheme.headingSM),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Reason for rejection',
              hintStyle: TextStyle(color: Colors.white24),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Reason required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.rejectParticipant(participant.id, adminId, reasonController.text);
      if (context.mounted) {
        if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participant rejected.'), backgroundColor: AppTheme.lime));
        }
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String type;

  const _StatusBadge({Key? key, required this.status, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (type == 'participant') {
      switch (status) {
        case 'active': color = AppTheme.lime; break;
        case 'joined':
        case 'invited': color = Colors.blue; break;
        case 'completed': color = Colors.green; break;
        case 'withdrawn':
        case 'disqualified': color = AppTheme.error; break;
        default: color = Colors.grey;
      }
    } else {
      // payment
      switch (status) {
        case 'paid': color = AppTheme.lime; break;
        case 'pending': color = Colors.amber; break;
        case 'waived': color = Colors.blue; break;
        case 'refunded':
        case 'rejected': color = AppTheme.error; break;
        default: color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
