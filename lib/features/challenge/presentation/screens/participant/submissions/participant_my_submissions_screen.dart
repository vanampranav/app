import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_my_submissions_provider.dart';

class ParticipantMySubmissionsScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantMySubmissionsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => ParticipantMySubmissionsProvider(
        challengeId: challengeId,
        userId: userId,
        submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
      ),
      child: const _ParticipantMySubmissionsContent(),
    );
  }
}

class _ParticipantMySubmissionsContent extends StatelessWidget {
  const _ParticipantMySubmissionsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('My Submissions', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<ParticipantMySubmissionsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilterBar(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
                    : provider.errorMessage != null
                        ? _buildErrorState(provider.errorMessage!)
                        : provider.submissions.isEmpty
                            ? _buildEmptyState(provider.currentFilter)
                            : _buildSubmissionList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ParticipantMySubmissionsProvider provider) {
    final filters = [
      'All', 
      'Baseline', 
      'Weekly', 
      'Final', 
      'Pending Review', 
      'Approved', 
      'Rejected', 
      'Resubmission Required'
    ];
    
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.lime : AppTheme.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.lime : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionList(BuildContext context, ParticipantMySubmissionsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final submission = provider.submissions[i];
        return _ParticipantSubmissionCard(submission: submission);
      },
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Text(
        'No $filter submissions found.',
        style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
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

class _ParticipantSubmissionCard extends StatelessWidget {
  final ChallengeSubmission submission;

  const _ParticipantSubmissionCard({Key? key, required this.submission}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    
    // Extract data from the submission's dynamic map
    final weight = submission.data['weight']?.toString() ?? '--';
    final unit = submission.data['unit'] ?? 'kg';
    final bodyFat = submission.data['bodyFat']?.toString();
    final source = submission.data['source'] ?? 'Manual';
    final weekNumber = submission.data['weekNumber'];
    final List<dynamic> photoUrls = submission.data['photos'] ?? [];

    String typeLabel = submission.type.toUpperCase();
    if (submission.type == SubmissionType.weeklyCheckIn && weekNumber != null) {
      typeLabel = 'WEEK $weekNumber CHECK-IN';
    }

    return EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                typeLabel, 
                style: AppTheme.labelSM.copyWith(color: AppTheme.lime, letterSpacing: 1.2, fontWeight: FontWeight.w900)
              ),
              _StatusBadge(status: submission.reviewStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Submitted: ${submission.createdAt != null ? dateFormat.format(submission.createdAt!) : 'N/A'}',
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
          ),
          const Divider(height: 32, color: Colors.white10),
          
          Row(
            children: [
              Flexible(child: _MetricItem(label: 'WEIGHT', value: '$weight $unit')),
              if (bodyFat != null) ...[
                const SizedBox(width: 24),
                Flexible(child: _MetricItem(label: 'BODY FAT', value: '$bodyFat%')),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('SOURCE', style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      source,
                      style: AppTheme.bodySM.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('PHOTOS', style: AppTheme.labelSM.copyWith(fontSize: 9)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
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
                      width: 70, height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          if (submission.adminReviewNotes != null && submission.adminReviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: submission.reviewStatus == ReviewStatus.needsClarification 
                    ? AppTheme.purple.withValues(alpha: 0.1) 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: submission.reviewStatus == ReviewStatus.needsClarification 
                      ? AppTheme.purple.withValues(alpha: 0.3) 
                      : Colors.transparent
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.reviewStatus == ReviewStatus.needsClarification ? 'RESUBMISSION REQUEST' : 'ADMIN FEEDBACK', 
                    style: AppTheme.labelSM.copyWith(
                      fontSize: 9, 
                      color: submission.reviewStatus == ReviewStatus.needsClarification ? AppTheme.purple : AppTheme.textTertiary
                    )
                  ),
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
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetricItem({required this.label, required this.value});

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
    if (status == 'needsClarification') label = 'FIX REQUIRED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }
}
