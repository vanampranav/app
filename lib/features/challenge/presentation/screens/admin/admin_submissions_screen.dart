import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_submissions_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_participant_detail_screen.dart';

class AdminSubmissionsScreen extends StatelessWidget {
  final String challengeId;

  const AdminSubmissionsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminSubmissionsProvider(
          challengeId: challengeId,
          submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
          userRepository: ctx.read<UserRepository>(),
          submissionService: ctx.read<SubmissionReviewService>(),
        ),
        child: const _AdminSubmissionsContent(),
      ),
    );
  }
}

class _AdminSubmissionsContent extends StatelessWidget {
  const _AdminSubmissionsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Review Submissions', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<AdminSubmissionsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilterSection(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
                    : provider.errorMessage != null
                        ? _buildErrorState(provider.errorMessage!)
                        : provider.submissions.isEmpty
                            ? _buildEmptyState()
                            : _buildSubmissionList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, AdminSubmissionsProvider provider) {
    return Column(
      children: [
        _buildScrollableFilter(
          options: ['All', 'Pending Review', 'Approved', 'Rejected', 'Resubmission Required'],
          selected: provider.currentStatusFilter,
          onSelected: provider.setStatusFilter,
        ),
        _buildScrollableFilter(
          options: ['All Types', 'Baseline', 'Weekly', 'Final'],
          selected: provider.currentTypeFilter,
          onSelected: provider.setTypeFilter,
          isCompact: true,
        ),
      ],
    );
  }

  Widget _buildScrollableFilter({
    required List<String> options,
    required String selected,
    required Function(String) onSelected,
    bool isCompact = false,
  }) {
    return Container(
      height: isCompact ? 40 : 46,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final option = options[i];
          final isSelected = selected == option;
          
          return GestureDetector(
            onTap: () => onSelected(option),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.lime : AppTheme.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.lime : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Center(
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionList(BuildContext context, AdminSubmissionsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final viewModel = provider.submissions[i];
        return _SubmissionCard(viewModel: viewModel);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No matching submissions found.',
        style: AppTheme.bodyLG,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.error),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final SubmissionViewModel viewModel;

  const _SubmissionCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final submission = viewModel.submission;
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final provider = context.read<AdminSubmissionsProvider>();
    final adminId = context.read<AuthService>().currentUser?.id ?? '';
    
    // Extract data from the submission's dynamic map
    final weight = submission.data['weight']?.toString() ?? '--';
    final bodyFat = submission.data['bodyFat']?.toString();
    final List<dynamic> photoUrls = submission.data['photos'] ?? [];

    return EFCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminParticipantDetailScreen(
          userId: submission.userId,
          challengeId: submission.challengeId,
        )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(submission.type.toUpperCase(), style: AppTheme.labelSM.copyWith(color: AppTheme.lime, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(viewModel.displayName, style: AppTheme.headingSM),
                ],
              ),
              _StatusBadge(status: submission.reviewStatus),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Submitted: ${submission.createdAt != null ? dateFormat.format(submission.createdAt!) : 'N/A'}',
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
          ),
          const Divider(height: 24, color: Colors.white10),
          
          Row(
            children: [
              _SubmissionMetric(label: 'WEIGHT', value: '$weight kg'),
              if (bodyFat != null) ...[
                const SizedBox(width: 32),
                _SubmissionMetric(label: 'BODY FAT', value: '$bodyFat%'),
              ],
              const Spacer(),
              Text('USER ID: ${submission.userId.substring(0, 8)}...', style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
            ],
          ),
          
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('PHOTOS', style: AppTheme.labelSM.copyWith(fontSize: 9)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _viewPhoto(context, photoUrls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrls[i],
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          if (submission.reviewStatus == ReviewStatus.submitted) ...[
            const SizedBox(height: 20),
            EFButton(
              label: 'Approve Submission',
              height: 44,
              onTap: () => _confirmApproval(context, provider, submission, adminId),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: EFButton(
                    label: 'Request Resubmission',
                    variant: EFButtonVariant.secondary,
                    height: 40,
                    onTap: () => _showReviewDialog(context, provider, submission, adminId, 'request_resubmission'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: EFButton(
                    label: 'Reject',
                    variant: EFButtonVariant.danger,
                    height: 40,
                    onTap: () => _showReviewDialog(context, provider, submission, adminId, 'reject'),
                  ),
                ),
              ],
            ),
          ],
          
          if (submission.adminReviewNotes != null && submission.adminReviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADMIN NOTES', style: AppTheme.labelSM.copyWith(fontSize: 9, color: AppTheme.textTertiary)),
                  const SizedBox(height: 4),
                  Text(
                    submission.adminReviewNotes!,
                    style: AppTheme.bodySM.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApproval(BuildContext context, AdminSubmissionsProvider provider, ChallengeSubmission submission, String adminId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Approve Submission?', style: AppTheme.headingSM),
        content: const Text('Confirm that this submission meets the challenge requirements.'),
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
      await provider.approveSubmission(submission.id, adminId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission approved'), backgroundColor: AppTheme.lime));
      }
    }
  }

  Future<void> _showReviewDialog(BuildContext context, AdminSubmissionsProvider provider, ChallengeSubmission submission, String adminId, String action) async {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isResubmission = action == 'request_resubmission';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: Text(isResubmission ? 'Request Resubmission' : 'Reject Submission', style: AppTheme.headingSM),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: noteController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter reason or feedback for the participant',
              hintStyle: TextStyle(color: Colors.white24),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Notes required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isResubmission ? AppTheme.purple : AppTheme.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isResubmission ? 'Send Request' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (isResubmission) {
        await provider.requestResubmission(submission.id, adminId, noteController.text);
      } else {
        await provider.rejectSubmission(submission.id, adminId, noteController.text);
      }
    }
  }
}

class _SubmissionMetric extends StatelessWidget {
  final String label;
  final String value;
  const _SubmissionMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 9, color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.numericMD.copyWith(fontSize: 16)),
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
      case 'approved': color = AppTheme.lime; break;
      case 'submitted': color = Colors.amber; break;
      case 'rejected': color = AppTheme.error; break;
      case 'needsClarification': color = AppTheme.purple; break;
      default: color = Colors.grey;
    }

    String label = status;
    if (status == 'needsClarification') label = 'Resubmission Required';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }
}
