import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_payments_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_participant_detail_screen.dart';

class AdminPaymentsScreen extends StatelessWidget {
  final String challengeId;

  const AdminPaymentsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminPaymentsProvider(
          challengeId: challengeId,
          paymentRepository: ctx.read<PaymentRecordRepository>(),
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
          userRepository: ctx.read<UserRepository>(),
          paymentService: ctx.read<PaymentApprovalService>(),
        ),
        child: const _AdminPaymentsContent(),
      ),
    );
  }
}

class _AdminPaymentsContent extends StatelessWidget {
  const _AdminPaymentsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Review Payments', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<AdminPaymentsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilterBar(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
                    : provider.errorMessage != null
                        ? _buildErrorState(provider.errorMessage!)
                        : provider.payments.isEmpty
                            ? _buildEmptyState(provider.currentFilter)
                            : _buildPaymentList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AdminPaymentsProvider provider) {
    final filters = ['All', 'Pending', 'Approved/Paid', 'Failed'];
    
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

  Widget _buildPaymentList(BuildContext context, AdminPaymentsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final viewModel = provider.payments[i];
        return _PaymentCard(viewModel: viewModel);
      },
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Text(
        'No $filter payments found.',
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

class _PaymentCard extends StatelessWidget {
  final PaymentViewModel viewModel;

  const _PaymentCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final payment = viewModel.payment;
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final provider = context.read<AdminPaymentsProvider>();
    final adminId = context.read<AuthService>().currentUser?.id ?? '';

    return EFCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminParticipantDetailScreen(
          userId: payment.userId,
          challengeId: payment.challengeId,
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
                      'Submitted: ${payment.createdAt != null ? dateFormat.format(payment.createdAt!) : 'N/A'}',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: payment.status),
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
                    Text('USER ID: ${payment.userId.substring(0, 8)}...', style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
                    const SizedBox(height: 4),
                    Text('AMOUNT', style: AppTheme.labelSM.copyWith(fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(
                      '${payment.amount} ${payment.currency}',
                      style: AppTheme.numericMD.copyWith(fontSize: 18, color: AppTheme.lime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('METHOD', style: AppTheme.labelSM.copyWith(fontSize: 9)),
                  const SizedBox(height: 4),
                  Text(payment.method.toUpperCase(), style: AppTheme.labelMD),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (payment.externalTransactionId != null) ...[
            Text('REFERENCE / TX ID', style: AppTheme.labelSM.copyWith(fontSize: 9)),
            const SizedBox(height: 4),
            Text(payment.externalTransactionId!, style: AppTheme.bodySM),
            const SizedBox(height: 12),
          ],
          if (payment.proofImageUrl != null)
            EFButton(
              label: 'View Payment Proof',
              variant: EFButtonVariant.ghost,
              height: 40,
              onTap: () => _viewProof(context, payment.proofImageUrl!),
            ),
          
          if (payment.status == PaymentStatus.pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: EFButton(
                    label: 'Approve',
                    height: 44,
                    onTap: () => _confirmApproval(context, provider, payment, adminId),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EFButton(
                    label: 'Reject',
                    variant: EFButtonVariant.danger,
                    height: 44,
                    onTap: () => _showRejectionDialog(context, provider, payment, adminId),
                  ),
                ),
              ],
            ),
          ],
          
          if (payment.adminNotes != null && payment.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin Note: ${payment.adminNotes}',
                style: AppTheme.bodySM.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewProof(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.surface1,
                  padding: const EdgeInsets.all(40),
                  child: const Text('Failed to load image'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApproval(BuildContext context, AdminPaymentsProvider provider, PaymentRecord payment, String adminId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Approve Payment?', style: AppTheme.headingSM),
        content: Text('Confirming payment of ${payment.amount} ${payment.currency} via ${payment.method}.'),
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
      await provider.approvePayment(payment.id, adminId);
      if (context.mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment approved'), backgroundColor: AppTheme.lime));
      }
    }
  }

  Future<void> _showRejectionDialog(BuildContext context, AdminPaymentsProvider provider, PaymentRecord payment, String adminId) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: const Text('Reject Payment?', style: AppTheme.headingSM),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Reason for rejection (e.g. proof not clear)',
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
      await provider.rejectPayment(payment.id, adminId, reasonController.text);
      if (context.mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment rejected'), backgroundColor: Colors.orange));
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'paid': color = AppTheme.lime; break;
      case 'pending': color = Colors.amber; break;
      case 'waived': color = Colors.blue; break;
      case 'refunded':
      case 'failed':
      case 'rejected': color = AppTheme.error; break;
      default: color = Colors.grey;
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
