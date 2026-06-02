import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';
import '../theme/app_theme.dart';

class AddMemberScreen extends StatefulWidget {
  final Member? existingMember;

  const AddMemberScreen({Key? key, this.existingMember}) : super(key: key);

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _nicknameController = TextEditingController();
  final _memberService = MemberService();

  Gender _selectedGender   = Gender.male;
  DateTime? _selectedBirthdate;
  int? _selectedHeight;
  UserType _selectedUserType = UserType.standard;
  bool _isLoading = false;

  bool get isEditing => widget.existingMember != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingMember != null) {
      _nicknameController.text = widget.existingMember!.nickname;
      _selectedGender     = widget.existingMember!.gender;
      _selectedBirthdate  = widget.existingMember!.birthdate;
      _selectedHeight     = widget.existingMember!.heightCm;
      _selectedUserType   = widget.existingMember!.userType;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nicknameController.text.trim().isNotEmpty &&
      _selectedBirthdate != null &&
      _selectedHeight != null;

  Future<void> _saveMember() async {
    if (!_canSave) return;
    setState(() => _isLoading = true);
    try {
      final member = Member(
        id: widget.existingMember?.id ?? MemberService.generateId(),
        nickname:   _nicknameController.text.trim(),
        gender:     _selectedGender,
        birthdate:  _selectedBirthdate!,
        heightCm:   _selectedHeight!,
        userType:   _selectedUserType,
        createdAt:  widget.existingMember?.createdAt,
      );
      if (isEditing) {
        await _memberService.updateMember(member);
      } else {
        await _memberService.addMember(member);
      }
      if (mounted) Navigator.pop(context, member);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving member: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pickers ─────────────────────────────────────────────────────────────

  void _showBirthdatePicker() {
    final now = DateTime.now();
    DateTime tempDate = _selectedBirthdate ?? DateTime(now.year - 25, 1, 1);
    _showPickerSheet(
      title: 'Birthdate',
      onDone: () => setState(() => _selectedBirthdate = tempDate),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: tempDate,
        minimumYear: 1920,
        maximumYear: now.year,
        onDateTimeChanged: (d) => tempDate = d,
      ),
    );
  }

  void _showHeightPicker() {
    final initial = _selectedHeight ?? 170;
    int tempH = initial;
    _showPickerSheet(
      title: 'Height (cm)',
      onDone: () => setState(() => _selectedHeight = tempH),
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: initial - 100),
        itemExtent: 44,
        onSelectedItemChanged: (i) => tempH = i + 100,
        children: List.generate(151, (i) {
          final h = i + 100;
          return Center(
            child: Text('$h cm',
                style: const TextStyle(
                    fontSize: 18, color: AppTheme.textPrimary)),
          );
        }),
      ),
    );
  }

  void _showPickerSheet({
    required String title,
    required VoidCallback onDone,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      builder: (_) => SizedBox(
        height: 300,
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: AppTheme.labelLG.copyWith(
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                  child: Center(
                      child: Text(title, style: AppTheme.headingSM))),
              TextButton(
                onPressed: () {
                  onDone();
                  Navigator.pop(context);
                },
                child: Text('Done',
                    style: AppTheme.labelLG.copyWith(color: AppTheme.lime)),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          Expanded(child: child),
        ]),
      ),
    );
  }

  void _showUserTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('User type', style: AppTheme.headingSM),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              itemCount: UserType.values.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.white.withOpacity(0.04)),
              itemBuilder: (_, i) {
                final type = UserType.values[i];
                final selected = _selectedUserType == type;
                return ListTile(
                  title: Text(
                    type.displayName,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppTheme.lime : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(type.description,
                      style: AppTheme.bodySM),
                  trailing: selected
                      ? const Icon(Icons.check_rounded,
                          color: AppTheme.lime, size: 18)
                      : null,
                  onTap: () {
                    setState(() => _selectedUserType = type);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Center(
                    child: Text('Done',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondary)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Member' : 'Add Member',
          style: AppTheme.headingSM,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.textTertiary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Personal information is used for body composition calculations only.',
                  style: AppTheme.bodyMD,
                ),
              ),
            ]),
          ),

          // Avatar
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(
                  color: AppTheme.surface3,
                  shape: BoxShape.circle,
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: AppTheme.textSecondary, size: 28),
                      const SizedBox(height: 4),
                      Text('Photo',
                          style: AppTheme.bodySM.copyWith(
                              color: AppTheme.textTertiary)),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Nickname
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NICKNAME',
                  style: AppTheme.labelMD.copyWith(
                      color: AppTheme.textTertiary)),
              const SizedBox(height: 10),
              TextField(
                controller: _nicknameController,
                maxLength: 25,
                style: AppTheme.headingSM,
                cursorColor: AppTheme.lime,
                decoration: InputDecoration(
                  hintText: 'Enter a nickname',
                  hintStyle: AppTheme.headingSM.copyWith(
                      color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surface1,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: AppTheme.lime, width: 1.5),
                  ),
                  counterStyle: AppTheme.bodySM,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Selector rows
          _buildRow(
            'Gender',
            Row(children: [
              _genderBtn(Gender.male, Icons.male, 'Male'),
              const SizedBox(width: 10),
              _genderBtn(Gender.female, Icons.female, 'Female'),
            ]),
          ),
          _buildRow(
            'Birthdate',
            GestureDetector(
              onTap: _showBirthdatePicker,
              child: Row(children: [
                Text(
                  _selectedBirthdate != null
                      ? '${_selectedBirthdate!.year}-'
                          '${_selectedBirthdate!.month.toString().padLeft(2, '0')}-'
                          '${_selectedBirthdate!.day.toString().padLeft(2, '0')}'
                      : 'Tap to select',
                  style: AppTheme.headingSM.copyWith(
                    color: _selectedBirthdate != null
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary, size: 18),
              ]),
            ),
          ),
          _buildRow(
            'Height',
            GestureDetector(
              onTap: _showHeightPicker,
              child: Row(children: [
                Text(
                  _selectedHeight != null
                      ? '$_selectedHeight cm'
                      : 'Tap to select',
                  style: AppTheme.headingSM.copyWith(
                    color: _selectedHeight != null
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary, size: 18),
              ]),
            ),
          ),
          _buildRow(
            'User type',
            GestureDetector(
              onTap: _showUserTypePicker,
              child: Row(children: [
                Text(_selectedUserType.displayName,
                    style: AppTheme.headingSM),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary, size: 18),
              ]),
            ),
          ),

          const SizedBox(height: 32),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _canSave && !_isLoading ? _saveMember : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _canSave ? AppTheme.lime : AppTheme.surface3,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: _canSave
                      ? [
                          BoxShadow(
                            color: AppTheme.lime.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _canSave
                                ? Colors.black
                                : AppTheme.textTertiary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _genderBtn(Gender gender, IconData icon, String label) {
    final selected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime.withOpacity(0.12) : AppTheme.surface3,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected ? AppTheme.lime : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected ? AppTheme.lime : AppTheme.textSecondary,
              size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppTheme.lime : AppTheme.textSecondary,
              )),
        ]),
      ),
    );
  }

  Widget _buildRow(String label, Widget trailing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(children: [
        Text(label, style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary)),
        const Spacer(),
        trailing,
      ]),
    );
  }
}
