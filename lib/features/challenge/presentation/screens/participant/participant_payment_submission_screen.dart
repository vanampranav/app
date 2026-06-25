import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_payment_submission_provider.dart';

class ParticipantPaymentSubmissionScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantPaymentSubmissionScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => ParticipantPaymentSubmissionProvider(
        challengeId: challengeId,
        userId: userId,
        challengeRepository: ctx.read<ChallengeRepository>(),
        participantRepository: ctx.read<ChallengeParticipantRepository>(),
        paymentRepository: ctx.read<PaymentRecordRepository>(),
        paymentService: ctx.read<PaymentApprovalService>(),
      ),
      child: const _ParticipantPaymentSubmissionContent(),
    );
  }
}

class _ParticipantPaymentSubmissionContent extends StatefulWidget {
  const _ParticipantPaymentSubmissionContent({Key? key}) : super(key: key);

  @override
  State<_ParticipantPaymentSubmissionContent> createState() => _ParticipantPaymentSubmissionContentState();
}

class _ParticipantPaymentSubmissionContentState extends State<_ParticipantPaymentSubmissionContent> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _selectedMethod = 'zelle';
  final _picker = ImagePicker();

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ParticipantPaymentSubmissionProvider provider) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.lime),
              title: const Text('Take Photo', style: AppTheme.bodyLG),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.lime),
              title: const Text('Choose from Gallery', style: AppTheme.bodyLG),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        provider.setProofImage(File(pickedFile.path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParticipantPaymentSubmissionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: Center(child: CircularProgressIndicator(color: AppTheme.lime)),
          );
        }

        final challenge = provider.challenge;
        final payment = provider.existingPayment;
        final isPaid = payment?.status == PaymentStatus.paid;

        if (challenge == null) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: Center(child: Text('Challenge not found', style: AppTheme.bodyLG)),
          );
        }

        // Initialize controllers if not already done and we have data
        if (_amountController.text.isEmpty && payment != null) {
          _amountController.text = payment.amount.toString();
          _referenceController.text = payment.externalTransactionId ?? '';
          _selectedMethod = payment.method;
        } else if (_amountController.text.isEmpty) {
          _amountController.text = challenge.registrationFee.toString();
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Submit Payment', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChallengeInfo(challenge),
                const SizedBox(height: 32),
                if (isPaid)
                  _buildSuccessState()
                else ...[
                  _buildInstructions(),
                  const SizedBox(height: 24),
                  if (payment?.status == PaymentStatus.rejected)
                    _buildRejectionNote(payment!.adminNotes),
                  const SizedBox(height: 24),
                  _buildForm(provider, challenge),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeInfo(Challenge challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(challenge.title, style: AppTheme.headingSM),
        const SizedBox(height: 8),
        Text(
          'Registration Fee: \$${challenge.registrationFee.toStringAsFixed(2)}',
          style: AppTheme.bodyLG.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return const EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INSTRUCTIONS', style: AppTheme.labelSM),
          SizedBox(height: 8),
          Text(
            '1. Send the registration fee to the EleFit account.\n'
            '2. Capture a screenshot of the transaction.\n'
            '3. Upload the screenshot and provide the reference ID below.',
            style: AppTheme.bodyMD,
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionNote(String? notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PAYMENT REJECTED', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(notes ?? 'Please provide a clearer proof of payment.', style: AppTheme.bodySM),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.lime, size: 64),
          const SizedBox(height: 16),
          const Text('Payment Verified!', style: AppTheme.headingSM),
          const SizedBox(height: 8),
          Text('Your registration for this challenge is active.', style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildForm(ParticipantPaymentSubmissionProvider provider, Challenge challenge) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Reference / Transaction ID',
            controller: _referenceController,
            hint: 'e.g. 123456789',
            validator: (v) => (_selectedMethod != 'other' && (v == null || v.isEmpty)) ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Amount Paid (\$)',
            controller: _amountController,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final val = double.tryParse(v);
              if (val == null) return 'Invalid amount';
              if (val < challenge.registrationFee) return 'Amount must be at least \$${challenge.registrationFee}';
              return null;
            },
          ),
          const SizedBox(height: 32),
          const Text('PAYMENT PROOF', style: AppTheme.labelSM),
          const SizedBox(height: 8),
          _buildImagePicker(provider),
          const SizedBox(height: 40),
          EFButton(
            label: provider.isSubmitting ? 'Submitting...' : 'Submit Proof',
            onTap: provider.isSubmitting ? null : () => _handleSubmit(provider),
            loading: provider.isSubmitting,
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(provider.errorMessage!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: AppTheme.labelSM),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMethod,
              isExpanded: true,
              dropdownColor: AppTheme.surface1,
              items: ['zelle', 'venmo', 'cashApp', 'other'].map((m) {
                return DropdownMenuItem(value: m, child: Text(m.toUpperCase(), style: const TextStyle(color: Colors.white)));
              }).toList(),
              onChanged: (v) => setState(() => _selectedMethod = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, String? hint, String? Function(String?)? validator, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: AppTheme.surface1,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildImagePicker(ParticipantPaymentSubmissionProvider provider) {
    final hasImage = provider.proofImage != null || provider.proofImageUrl != null;
    
    return GestureDetector(
      onTap: () => _pickImage(provider),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: hasImage
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: provider.proofImage != null
                          ? Image.file(provider.proofImage!, fit: BoxFit.cover)
                          : Image.network(provider.proofImageUrl!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () => _pickImage(provider),
                      ),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: AppTheme.textTertiary, size: 40),
                  SizedBox(height: 12),
                  Text('Upload transaction screenshot', style: AppTheme.bodySM),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSubmit(ParticipantPaymentSubmissionProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    
    await provider.submitPayment(
      method: _selectedMethod,
      amount: _amountController.text,
      referenceId: _referenceController.text,
    );

    if (mounted && provider.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment proof submitted successfully!'), backgroundColor: AppTheme.lime));
      Navigator.pop(context);
    }
  }
}
