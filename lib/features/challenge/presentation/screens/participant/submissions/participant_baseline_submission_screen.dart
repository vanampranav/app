import 'dart:io';
import 'package:elefit_app/utils/safe_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elefit_app/utils/decimal_input_formatter.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/challenge_scale_sync_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_baseline_submission_provider.dart';
import 'package:elefit_app/screens/shop_screen.dart';

class ParticipantBaselineSubmissionScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantBaselineSubmissionScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => ParticipantBaselineSubmissionProvider(
        challengeId: challengeId,
        userId: userId,
        challengeRepository: ctx.read<ChallengeRepository>(),
        participantRepository: ctx.read<ChallengeParticipantRepository>(),
        submissionRepository: ctx.read<ChallengeSubmissionRepository>(),
        submissionService: ctx.read<SubmissionReviewService>(),
      ),
      child: const _ParticipantBaselineSubmissionContent(),
    );
  }
}

class _ParticipantBaselineSubmissionContent extends StatefulWidget {
  const _ParticipantBaselineSubmissionContent({Key? key}) : super(key: key);

  @override
  State<_ParticipantBaselineSubmissionContent> createState() => _ParticipantBaselineSubmissionContentState();
}

class _ParticipantBaselineSubmissionContentState extends State<_ParticipantBaselineSubmissionContent> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _muscleController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _weightUnit = 'kg';
  String _measurementSource = 'manualEntry';
  final _picker = ImagePicker();
  bool _initializedWithPrefill = false;

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _muscleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ParticipantBaselineSubmissionProvider provider) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      final pickedFile = await safePickImage(context, _picker, source: source, imageQuality: 70);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        provider.addPhoto(File(pickedFile.path), bytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParticipantBaselineSubmissionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: EFLoadingStateView(message: 'Loading baseline data...'),
          );
        }

        // Only a LOAD failure (the challenge data never loaded) gets the
        // full-screen error. A SUBMISSION error keeps the user on the form and
        // is shown inline under the Submit button, so validation feedback no
        // longer bounces them to a separate screen.
        if (provider.errorMessage != null && provider.challenge == null) {
          return Scaffold(
            backgroundColor: AppTheme.bg,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton()),
            body: _buildErrorState(context, provider),
          );
        }

        final challenge = provider.challenge;
        final submission = provider.existingSubmission;
        
        if (challenge == null) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: EFEmptyStateView(
              title: 'Not Found',
              message: 'Challenge not found.',
              icon: Icons.search_off_rounded,
            ),
          );
        }

        final isApproved = submission?.reviewStatus == ReviewStatus.approved;
        final isResubmissionRequired = submission?.reviewStatus == ReviewStatus.needsClarification;

        // Pre-fill form if existing submission exists OR from profile
        if (!_initializedWithPrefill) {
          if (submission != null) {
            _weightController.text = formatMeasurement(submission.data['weight']);
            _bodyFatController.text = formatMeasurement(submission.data['bodyFat']);
            _muscleController.text = formatMeasurement(submission.data['muscleMass']);
            _notesController.text = submission.data['notes'] ?? '';
            _weightUnit = submission.data['unit'] ?? 'kg';
            _measurementSource = submission.data['source'] ?? 'manualEntry';
            _initializedWithPrefill = true;
          } else if (provider.hasProfilePrefill) {
            _weightController.text = formatMeasurement(provider.prefilledWeight);
            _bodyFatController.text = formatMeasurement(provider.prefilledBodyFat);
            _weightUnit = provider.prefilledUnit ?? 'kg';
            _measurementSource = 'profilePrefill';
            _initializedWithPrefill = true;
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Baseline Submission', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChallengeHeader(challenge),
                const SizedBox(height: 24),
                
                if (submission == null && provider.hasProfilePrefill)
                  _buildPrefillBanner()
                else if (submission == null && !provider.hasProfilePrefill)
                  _buildNoDataBanner(),

                if (isApproved)
                  _buildStatusBanner(ReviewStatus.approved, null)
                else if (isResubmissionRequired)
                  _buildStatusBanner(ReviewStatus.needsClarification, submission!.adminReviewNotes)
                else if (submission != null)
                  _buildStatusBanner(submission.reviewStatus, null),
                
                const SizedBox(height: 24),
                if (isApproved)
                  _buildReadOnlyView(submission!)
                else
                  _buildForm(provider, challenge),
                
                if (!isApproved) ...[
                  const SizedBox(height: 32),
                  _buildScaleCTA(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrefillBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lime.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.lime, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We prefilled this from your profile. Please review and confirm before submitting.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.lime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add your starting weight manually or use a body composition scale for more accurate tracking.',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleCTA() {
    return EFCard(
      color: AppTheme.purple.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_weight_outlined, color: AppTheme.lime),
              const SizedBox(width: 12),
              Text('Need a body composition scale?', style: AppTheme.headingSM.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'EleFit smart scales automatically sync weight and body fat percentage to your profile.',
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          EFButton(
            label: 'View EleFit Scale Options',
            height: 44,
            onTap: () {
              Navigator.push(context, EFPageRoute(page: const ShopScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeHeader(challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(challenge.title, style: AppTheme.headingSM),
        const SizedBox(height: 8),
        const Text(
          'Please submit your starting measurements and photos to begin the challenge.',
          style: AppTheme.bodySM,
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String status, String? notes) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ReviewStatus.approved:
        color = AppTheme.lime;
        label = 'Baseline Approved';
        icon = Icons.check_circle_rounded;
        break;
      case ReviewStatus.needsClarification:
        color = AppTheme.purple;
        label = 'Resubmission Requested';
        icon = Icons.error_outline_rounded;
        break;
      case ReviewStatus.rejected:
        color = AppTheme.error;
        label = 'Baseline Rejected';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = Colors.amber;
        label = 'Pending Review';
        icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTheme.labelLG.copyWith(color: color))),
            ],
          ),
          if (notes != null) ...[
            const SizedBox(height: 8),
            Text('Admin Feedback: $notes', style: AppTheme.bodySM),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(ParticipantBaselineSubmissionProvider provider, challenge) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChallengeScaleSyncButton(
            onReading: (m) => setState(() {
              _weightController.text = m.weight.toStringAsFixed(1);
              _weightUnit = m.unit.toLowerCase().startsWith('lb') ? 'lb' : 'kg';
              if (m.bodyFat != null) {
                _bodyFatController.text = m.bodyFat!.toStringAsFixed(1);
              }
              if (m.muscle != null) {
                _muscleController.text = m.muscle!.toStringAsFixed(1);
              }
              _measurementSource = 'elefit4ElectrodeScale';
            }),
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  label: 'Current Weight *',
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter(decimalRange: 1, maxIntegerDigits: 3)],
                  hint: '0.0',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final val = double.tryParse(v);
                    if (val == null || val <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  label: 'Unit *',
                  value: _weightUnit,
                  items: ['kg', 'lb'],
                  onChanged: (v) => setState(() => _weightUnit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Body Fat % *',
            controller: _bodyFatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalTextInputFormatter(decimalRange: 1, maxIntegerDigits: 3)],
            hint: 'e.g. 15.5',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final val = double.tryParse(v);
              if (val == null || val < 1 || val > 75) return '1-75 only';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Muscle Mass ($_weightUnit) *',
            controller: _muscleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalTextInputFormatter(decimalRange: 1, maxIntegerDigits: 3)],
            hint: 'e.g. 32.4',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final val = double.tryParse(v);
              if (val == null || val <= 0) return 'Invalid';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            label: 'Measurement Source *',
            value: _measurementSource,
            items: [
              'profilePrefill',
              'manualEntry',
              'elefit4ElectrodeScale',
              'elefit8ElectrodeScale',
              'thirdPartyScan'
            ],
            onChanged: (v) => setState(() => _measurementSource = v!),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Notes (Optional)',
            controller: _notesController,
            maxLines: 2,
            maxLength: 500,
            hint: 'Any details about your measurements...',
          ),
          const SizedBox(height: 32),
          _fieldLabel('PHOTOS *'),
          const SizedBox(height: 12),
          _buildPhotoGrid(provider),
          const SizedBox(height: 40),
          EFButton(
            label: provider.isSubmitting
                ? 'Submitting...'
                : (provider.existingSubmission == null
                    ? 'Submit Baseline'
                    : (provider.existingSubmission?.reviewStatus == ReviewStatus.needsClarification
                        ? 'Resubmit Baseline'
                        : 'Update Submission')),
            onTap: provider.isSubmitting ? null : () => _handleSubmit(provider),
            loading: provider.isSubmitting || provider.isUploading,
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

  Widget _buildReadOnlyView(ChallengeSubmission submission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EFCard(
          child: Column(
            children: [
              _buildReadOnlyRow('Weight', '${submission.data['weight']} ${submission.data['unit']}'),
              const Divider(height: 24, color: Colors.white10),
              _buildReadOnlyRow('Body Fat', '${submission.data['bodyFat'] ?? 'N/A'}%'),
              const Divider(height: 24, color: Colors.white10),
              _buildReadOnlyRow('Muscle Mass', submission.data['muscleMass'] != null ? '${submission.data['muscleMass']} ${submission.data['unit'] ?? ''}' : 'N/A'),
              const Divider(height: 24, color: Colors.white10),
              _buildReadOnlyRow('Source', submission.data['source']?.toString() ?? 'N/A'),
            ],
          ),
        ),
        if (submission.data['photos'] is List && (submission.data['photos'] as List).isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text('SUBMITTED PHOTOS', style: AppTheme.labelSM),
          const SizedBox(height: 12),
          _buildReadOnlyPhotoGrid(List<String>.from(submission.data['photos'])),
        ],
      ],
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPhotoGrid(ParticipantBaselineSubmissionProvider provider) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Existing Photos
        ...provider.existingPhotoUrls.asMap().entries.map((e) => _buildPhotoItem(
          url: e.value, 
          onRemove: () => provider.removeExistingPhoto(e.key)
        )),
        // New Photos
        ...provider.newPhotos.asMap().entries.map((e) => _buildPhotoItem(
          file: e.value, 
          onRemove: () => provider.removeNewPhoto(e.key)
        )),
        // Add Button
        GestureDetector(
          onTap: () => _pickImage(provider),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyPhotoGrid(List<String> urls) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: urls.map((url) => Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      )).toList(),
    );
  }

  Widget _buildPhotoItem({String? url, File? file, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: url != null ? NetworkImage(url) as ImageProvider : FileImage(file!),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  // Renders a field label; a trailing " *" is shown as a red "required" marker.
  Widget _fieldLabel(String label) {
    if (label.endsWith(' *')) {
      return Text.rich(
        TextSpan(
          style: AppTheme.labelSM,
          children: [
            TextSpan(text: label.substring(0, label.length - 2)),
            const TextSpan(text: ' *', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return Text(label, style: AppTheme.labelSM);
  }

  Widget _buildTextField({required String label, required TextEditingController controller, String? hint, int maxLines = 1, int? maxLength, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) {
    final bool multiline = maxLines != 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: multiline ? maxLines : 1,
          maxLines: multiline ? null : 1,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          keyboardType: multiline ? TextInputType.multiline : keyboardType,
          textInputAction: multiline ? TextInputAction.newline : null,
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

  Widget _buildDropdown({required String label, required String value, required List<String> items, required Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppTheme.surface1, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.surface1,
              items: items.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(ParticipantBaselineSubmissionProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    // A photo is required for the baseline.
    if (provider.newPhotos.isEmpty && provider.existingPhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one baseline photo.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    await provider.submitBaseline(
      weight: double.parse(_weightController.text),
      unit: _weightUnit,
      bodyFat: _bodyFatController.text.isNotEmpty ? double.parse(_bodyFatController.text) : null,
      muscleMass: _muscleController.text.isNotEmpty ? double.parse(_muscleController.text) : null,
      source: _measurementSource,
      notes: _notesController.text,
    );

    if (mounted && provider.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Baseline submitted successfully!'), backgroundColor: AppTheme.lime));
      Navigator.pop(context);
    }
  }

  Widget _buildErrorState(BuildContext context, ParticipantBaselineSubmissionProvider provider) {
    return EFErrorView.map(
      provider.errorMessage!,
      screenName: 'ParticipantBaselineSubmissionScreen',
      featureName: 'ChallengeSubmissions',
      userId: provider.userId,
      onBack: () => Navigator.pop(context),
    );
  }
}
