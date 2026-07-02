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
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_challenge_payments_provider.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';

class AdminChallengePaymentsScreen extends StatelessWidget {
  final String challengeId;

  const AdminChallengePaymentsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminChallengePaymentsProvider(
          challengeId: challengeId,
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
          userRepository: ctx.read<UserRepository>(),
          paymentService: ctx.read<PaymentApprovalService>(),
        ),
        child: const _AdminChallengePaymentsContent(),
      ),
    );
  }
}

class _AdminChallengePaymentsContent extends StatelessWidget {
  const _AdminChallengePaymentsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminChallengePaymentsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Payment Tracking', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: Column(
            children: [
              _buildSearchBar(context, provider),
              _buildFilterBar(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const EFLoadingStateView(message: 'Loading participants...')
                    : provider.errorMessage != null
                        ? EFErrorView(
                            title: 'Error',
                            message: provider.errorMessage!,
                            onRetry: () => provider.fetchData(),
                          )
                        : provider.viewModels.isEmpty
                            ? const EFEmptyStateView(
                                title: 'No Results',
                                message: 'No participants found matching your criteria.',
                                icon: Icons.person_search_rounded,
                              )
                            : _buildParticipantList(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, AdminChallengePaymentsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
    );
  }

  Widget _buildFilterBar(BuildContext context, AdminChallengePaymentsProvider provider) {
    final filters = ['All', 'Pending', 'Pending Review', 'Paid', 'Partially Paid', 'Refunded', 'Waived'];
    
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
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
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

  Widget _buildParticipantList(BuildContext context, AdminChallengePaymentsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.viewModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final viewModel = provider.viewModels[i];
        return _ParticipantPaymentCard(viewModel: viewModel);
      },
    );
  }
}

class _ParticipantPaymentCard extends StatelessWidget {
  final ParticipantPaymentViewModel viewModel;

  const _ParticipantPaymentCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final participant = viewModel.participant;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final provider = context.read<AdminChallengePaymentsProvider>();
    final adminId = context.read<AuthService>().currentUser?.id ?? '';

    return EFCard(
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
                    Text(viewModel.displayName, style: AppTheme.headingSM),
                    if (participant.leaderboardDisplayName != null)
                      Text('Nickname: ${participant.leaderboardDisplayName}', 
                          style: AppTheme.bodySM.copyWith(color: AppTheme.lime, fontSize: 11)),
                  ],
                ),
              ),
              _StatusBadge(status: participant.paymentStatus),
            ],
          ),
          const SizedBox(height: 12),
          Text('Package: ${participant.selectedPackageName ?? 'Default'}', 
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
          const Divider(height: 24, color: Colors.white10),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricItem(label: 'DUE', value: '${participant.amountDue} ${participant.currency ?? "USD"}'),
              _MetricItem(label: 'COLLECTED', value: '${participant.amountCollected} ${participant.currency ?? "USD"}', 
                  color: participant.amountCollected >= participant.amountDue ? AppTheme.lime : Colors.amber),
              _MetricItem(label: 'ENROLLED', value: participant.joinedAt != null ? dateFormat.format(participant.joinedAt!) : 'N/A'),
            ],
          ),

          if (participant.paymentReference != null || participant.paymentMethod != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (participant.paymentMethod != null)
                  _Tag(label: participant.paymentMethod!.toUpperCase()),
                if (participant.paymentReference != null) ...[
                  const SizedBox(width: 8),
                  Expanded(child: Text('Ref: ${participant.paymentReference}', 
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
          ],

          if (participant.paymentNotes != null && participant.paymentNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Text('Notes: ${participant.paymentNotes}', style: AppTheme.bodySM.copyWith(fontStyle: FontStyle.italic)),
            ),
          ],

          if (participant.paymentStatus == PaymentStatus.pendingReview) ...[
            const SizedBox(height: 16),
            _buildProofSection(participant),
          ],

          const SizedBox(height: 20),
          EFButton(
            label: 'Update Payment',
            onTap: () => _showUpdateDialog(context, provider, participant, adminId),
            variant: EFButtonVariant.secondary,
            height: 40,
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, AdminChallengePaymentsProvider provider, ChallengeParticipant participant, String adminId) {
    final amountController = TextEditingController(text: participant.amountCollected.toString());
    final refController = TextEditingController(text: participant.paymentReference ?? '');
    final notesController = TextEditingController(text: participant.paymentNotes ?? '');
    
    final formKey = GlobalKey<FormState>();
    String selectedStatus = participant.paymentStatus;
    String selectedMethod = participant.paymentMethod ?? PaymentMethod.manual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update Payment: ${viewModel.displayName}', style: AppTheme.headingMD),
                  const SizedBox(height: 24),
                  
                  _buildLabel('Payment Status'),
                  _buildDropdown<String>(
                    value: selectedStatus,
                    items: const [
                      PaymentStatus.pending,
                      PaymentStatus.pendingReview,
                      PaymentStatus.partiallyPaid,
                      PaymentStatus.paid,
                      PaymentStatus.waived,
                      PaymentStatus.refunded,
                      PaymentStatus.failed,
                    ],
                    onChanged: (val) => setModalState(() => selectedStatus = val!),
                  ),
                  
                  const SizedBox(height: 20),
                  _buildLabel('Amount Collected (${participant.currency ?? "USD"})'),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface1),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid amount' : null,
                  ),

                  const SizedBox(height: 20),
                  _buildLabel('Payment Method'),
                  _buildDropdown<String>(
                    value: selectedMethod,
                    items: [
                      PaymentMethod.manual,
                      PaymentMethod.cash,
                      PaymentMethod.zelle,
                      PaymentMethod.venmo,
                      PaymentMethod.paypal,
                      PaymentMethod.upi,
                      PaymentMethod.stripe,
                    ],
                    onChanged: (val) => setModalState(() => selectedMethod = val!),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel('Reference Number / TX ID'),
                  TextFormField(
                    controller: refController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface1, hintText: 'Optional'),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel('Admin Notes'),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface1, hintText: 'Internal or for participant'),
                  ),

                  const SizedBox(height: 40),
                  EFButton(
                    label: 'Save Changes',
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        await provider.updatePayment(
                          participantId: participant.id,
                          adminId: adminId,
                          newStatus: selectedStatus,
                          amountCollected: double.parse(amountController.text),
                          paymentMethod: selectedMethod,
                          reference: refController.text,
                          notes: notesController.text,
                        );
                        if (context.mounted) Navigator.pop(ctx);
                      }
                    },
                    loading: provider.isActionInProgress,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: AppTheme.labelSM.copyWith(color: AppTheme.textSecondary)),
    );
  }

  Widget _buildProofSection(ChallengeParticipant p) {
    final df = DateFormat('MMM dd, HH:mm');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text('UPDATED PROOF SUBMITTED', style: AppTheme.labelSM.copyWith(color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 12),
          if (p.paymentProofSubmittedAt != null)
            Text('Submitted: ${df.format(p.paymentProofSubmittedAt!)}', style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
          if (p.paymentProofNotes != null && p.paymentProofNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('User Notes: ${p.paymentProofNotes}', style: AppTheme.bodySM),
            ),
          if (p.paymentProofUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(p.paymentProofUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({required T value, required List<T> items, required ValueChanged<T?> onChanged}) {
    // Guard: DropdownButton asserts if `value` isn't present exactly once in
    // `items`. If the stored value is a legacy/unlisted option, include it so
    // the dropdown renders instead of crashing.
    final safeItems = items.contains(value) ? items : [value, ...items];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppTheme.surface1, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surface1,
          items: safeItems.map((i) => DropdownMenuItem(value: i, child: Text(i.toString(), style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MetricItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(fontSize: 8, color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.numericMD.copyWith(fontSize: 14, color: color ?? AppTheme.textPrimary)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
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
      case 'paid':
      case 'waived': color = AppTheme.lime; break;
      case 'pending':
      case 'partiallyPaid': color = Colors.amber; break;
      case 'refunded': color = Colors.blue; break;
      case 'failed': color = AppTheme.error; break;
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
