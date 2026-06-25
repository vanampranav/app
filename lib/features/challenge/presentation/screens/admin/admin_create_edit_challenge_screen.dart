import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_challenge_detail_screen.dart';

class AdminCreateEditChallengeScreen extends StatefulWidget {
  final String? challengeId;
  final Challenge? existingChallenge;

  const AdminCreateEditChallengeScreen({
    Key? key,
    this.challengeId,
    this.existingChallenge,
  }) : super(key: key);

  @override
  State<AdminCreateEditChallengeScreen> createState() => _AdminCreateEditChallengeScreenState();
}

class _AdminCreateEditChallengeScreenState extends State<AdminCreateEditChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _feeController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _prizeController;
  late TextEditingController _rulesController;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _registrationDeadline;
  bool _baselineRequired = true;
  bool _finalPhotoRequired = true;
  
  bool _isSaving = false;
  bool _isLoading = false;
  Challenge? _challenge;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _feeController = TextEditingController(text: '0.0');
    _maxParticipantsController = TextEditingController(text: '100');
    _prizeController = TextEditingController();
    _rulesController = TextEditingController();

    if (widget.existingChallenge != null) {
      _loadExistingChallenge(widget.existingChallenge!);
    } else if (widget.challengeId != null) {
      _fetchChallenge();
    }
  }

  void _loadExistingChallenge(Challenge challenge) {
    _challenge = challenge;
    _nameController.text = challenge.title;
    _descriptionController.text = challenge.description;
    _feeController.text = challenge.registrationFee.toString();
    _maxParticipantsController.text = challenge.maxParticipants.toString();
    _prizeController.text = challenge.prizeDescription;
    _rulesController.text = challenge.rulesSummary;
    _startDate = challenge.startDate;
    _endDate = challenge.endDate;
    _registrationDeadline = challenge.registrationDeadline;
    _baselineRequired = challenge.baselineRequired;
    _finalPhotoRequired = challenge.finalPhotoRequired;
  }

  Future<void> _fetchChallenge() async {
    // This would ideally be in a provider, but for MVP keeping it simple
    setState(() => _isLoading = true);
    try {
      // In a real app, get from repository or service
      // For now, let's assume we pass the object or fetch it
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _maxParticipantsController.dispose();
    _prizeController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.lime,
              onPrimary: Colors.black,
              surface: AppTheme.surface1,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (type == 'start') _startDate = picked;
        if (type == 'end') _endDate = picked;
        if (type == 'deadline') _registrationDeadline = picked;
      });
    }
  }

  Future<void> _saveChallenge({bool shouldPop = true}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _registrationDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all dates')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    if (_registrationDeadline!.isAfter(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration deadline must be before or equal to start date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final challengeService = context.read<ChallengeService>();
      final authService = context.read<AuthService>();
      final adminId = authService.currentUser?.id ?? '';

      if (_challenge == null) {
        // Create mode
        await challengeService.createDraftChallenge(
          title: _nameController.text,
          description: _descriptionController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          registrationDeadline: _registrationDeadline!,
          registrationFee: double.tryParse(_feeController.text) ?? 0.0,
          maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 0,
          prizeDescription: _prizeController.text,
          rulesSummary: _rulesController.text,
          baselineRequired: _baselineRequired,
          finalPhotoRequired: _finalPhotoRequired,
          adminId: adminId,
        );
      } else {
        // Edit mode
        final updated = _challenge!.copyWith(
          title: _nameController.text,
          description: _descriptionController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          registrationDeadline: _registrationDeadline!,
          registrationFee: double.tryParse(_feeController.text) ?? 0.0,
          maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 0,
          prizeDescription: _prizeController.text,
          rulesSummary: _rulesController.text,
          baselineRequired: _baselineRequired,
          finalPhotoRequired: _finalPhotoRequired,
        );
        await challengeService.updateChallengeConfig(updated, adminId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge saved successfully!'), backgroundColor: AppTheme.lime),
        );
        if (shouldPop) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _challenge != null;
    final canEdit = !isEdit || _challenge!.status == ChallengeStatus.draft;

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Challenge' : 'Create Challenge', style: AppTheme.headingMD),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: AppTheme.textPrimary),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!canEdit)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Only draft challenges can be edited. This challenge is currently ${_challenge!.status}.',
                                  style: AppTheme.bodySM.copyWith(color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _buildTextField(
                        label: 'Challenge Name',
                        controller: _nameController,
                        hint: 'e.g. 30-Day Summer Shred',
                        enabled: canEdit,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        hint: 'What is this challenge about?',
                        maxLines: 3,
                        enabled: canEdit,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      Text('DATES', style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Start Date',
                              date: _startDate,
                              onTap: canEdit ? () => _selectDate(context, 'start') : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePicker(
                              label: 'End Date',
                              date: _endDate,
                              onTap: canEdit ? () => _selectDate(context, 'end') : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(
                        label: 'Registration Deadline',
                        date: _registrationDeadline,
                        onTap: canEdit ? () => _selectDate(context, 'deadline') : null,
                      ),
                      const SizedBox(height: 24),

                      Text('CONFIG', style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'Registration Fee (USD)',
                              controller: _feeController,
                              keyboardType: TextInputType.number,
                              enabled: canEdit,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              label: 'Max Participants',
                              controller: _maxParticipantsController,
                              keyboardType: TextInputType.number,
                              enabled: canEdit,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        label: 'Prize Description',
                        controller: _prizeController,
                        hint: 'e.g. 500 USD Amazon Gift Card for 1st Place',
                        enabled: canEdit,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'Rules Summary',
                        controller: _rulesController,
                        hint: 'Key rules users must follow...',
                        maxLines: 4,
                        enabled: canEdit,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      Text('REQUIREMENTS', style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
                      const SizedBox(height: 8),
                      _buildSwitch(
                        label: 'Baseline Submission Required',
                        value: _baselineRequired,
                        onChanged: canEdit ? (v) => setState(() => _baselineRequired = v) : null,
                      ),
                      _buildSwitch(
                        label: 'Final Photo Required for EleFit prizes',
                        value: _finalPhotoRequired,
                        onChanged: canEdit ? (v) => setState(() => _finalPhotoRequired = v) : null,
                      ),

                      const SizedBox(height: 40),
                      EFButton(
                        label: _isSaving ? 'Saving...' : (isEdit ? 'Update Challenge' : 'Create Draft Challenge'),
                        onTap: (canEdit && !_isSaving) ? _saveChallenge : null,
                        loading: _isSaving,
                      ),
                      
                      if (isEdit && _challenge?.status == ChallengeStatus.draft) ...[
                        const SizedBox(height: 16),
                        EFButton(
                          label: 'Activate Challenge',
                          variant: EFButtonVariant.secondary,
                          onTap: _isSaving ? null : () async {
                            final navigator = Navigator.of(context);
                            // First save any pending changes, then navigate to details to activate
                            await _saveChallenge(shouldPop: false);
                            if (mounted && _challenge != null) {
                               // After saving, go to details where activation is handled
                               navigator.pushReplacement(
                                 MaterialPageRoute(builder: (_) => AdminChallengeDetailScreen(challengeId: _challenge!.id)),
                               );
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enabled: enabled,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: AppTheme.surface1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: AppTheme.error),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null ? 'Select Date' : DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(
                    color: date == null ? Colors.white24 : Colors.white,
                  ),
                ),
                const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.lime),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch({
    required String label,
    required bool value,
    Function(bool)? onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.bodyMD),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.lime,
        ),
      ],
    );
  }
}
