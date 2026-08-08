import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/challenge_auth_guard.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/services/analytics_service.dart';

class ParticipantPaymentRecoveryScreen extends StatefulWidget {
  final String challengeId;

  const ParticipantPaymentRecoveryScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<ParticipantPaymentRecoveryScreen> createState() => _ParticipantPaymentRecoveryScreenState();
}

class _ParticipantPaymentRecoveryScreenState extends State<ParticipantPaymentRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  File? _image;
  Uint8List? _imageBytes; // captured at pick time so upload never depends on a temp file
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  ChallengeParticipant? _participant;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadParticipant();
  }

  Future<void> _loadParticipant() async {
    setState(() => _isLoading = true);
    final userId = context.read<AuthService>().currentUser?.id ?? '';
    try {
      final repo = context.read<ChallengeParticipantRepository>();
      _participant = await repo.getParticipantByUserAndChallenge(userId, widget.challengeId);
      // Pre-fill what the participant submitted last time so they can see what
      // to fix instead of starting from empty fields.
      _refController.text = _participant?.paymentReference ?? '';
      _notesController.text = _participant?.paymentProofNotes ?? '';
      if (kDebugMode) {
        debugPrint('RecoveryScreen: Loaded participant. paymentStatus: ${_participant?.paymentStatus}');
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _image = File(pickedFile.path);
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_participant == null) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a new payment screenshot.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    final paymentService = context.read<PaymentApprovalService>();

    try {
      await ensureFirebaseSdkSignedIn();
      String? proofUrl;
      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('payments')
            .child('${_participant!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        // Upload in-memory bytes, not the temp file path (image_picker's cache
        // file can be gone by submit time → file.absolute.existsSync() assertion).
        await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        proofUrl = await ref.getDownloadURL();
      }

      await paymentService.resubmitPaymentProof(
        challengeId: _participant!.challengeId,
        userId: _participant!.userId,
        reference: _refController.text.trim(),
        notes: _notesController.text.trim(),
        proofUrl: proofUrl,
      );

      AnalyticsService.logEvent('payment_proof_submitted', {
        'challenge_id': widget.challengeId,
        'participant_id': _participant!.userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment proof submitted for review!'), backgroundColor: AppTheme.lime),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: EFLoadingStateView(message: 'Loading details...'));
    if (_errorMessage != null) return Scaffold(body: EFErrorView(title: 'Error', message: _errorMessage!, onRetry: _loadParticipant));
    if (_participant == null) return const Scaffold(body: EFEmptyStateView(title: 'Not Found', message: 'Enrollment record not found.'));

    // Route Guard: Only allow access if payment status is failed
    if (_participant!.paymentStatus != PaymentStatus.failed) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton()),
        body: EFEmptyStateView(
          title: 'Access Restricted',
          message: 'Payment recovery is only available for failed verification. Your current status is: ${_participant!.paymentStatus.toUpperCase()}',
          icon: Icons.lock_outline_rounded,
          action: EFButton(
            label: 'Go Back',
            onTap: () => Navigator.pop(context),
            fullWidth: false,
            padding: const EdgeInsets.symmetric(horizontal: 32),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Update Payment Proof', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFailureNotice(),
              const SizedBox(height: 32),
              _buildLabel('Reference Number / Transaction ID'),
              TextFormField(
                controller: _refController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Zelle Ref #, Venmo User',
                  filled: true,
                  fillColor: AppTheme.surface1,
                ),
                validator: (v) => v!.isEmpty ? 'Reference is required' : null,
              ),
              const SizedBox(height: 24),
              _buildLabel('Additional Notes'),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Any details to help us verify your payment',
                  filled: true,
                  fillColor: AppTheme.surface1,
                ),
              ),
              const SizedBox(height: 32),
              _buildLabel('Screenshot *'),
              if (_participant?.paymentProofUrl != null) ...[
                const SizedBox(height: 8),
                Text('Previously submitted (rejected) — upload a clearer one:',
                    style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _participant!.paymentProofUrl!,
                    height: 90,
                    width: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textTertiary, size: 40),
                            SizedBox(height: 8),
                            Text('Upload Payment Screenshot', style: AppTheme.bodySM),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48),
              EFButton(
                label: _isUploading ? 'Submitting...' : 'Submit for Review',
                onTap: _isUploading ? null : _submit,
                loading: _isUploading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailureNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
              const SizedBox(width: 8),
              Text('Verification Failed', style: AppTheme.labelLG.copyWith(color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _participant!.paymentFailureReason ?? 'No reason provided.',
            style: AppTheme.bodyMD,
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: AppTheme.labelSM.copyWith(color: AppTheme.textSecondary)),
    );
  }
}
