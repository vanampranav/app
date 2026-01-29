import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';
import '../theme/app_theme.dart';

class AddMemberScreen extends StatefulWidget {
  final Member? existingMember; // For editing existing member

  const AddMemberScreen({Key? key, this.existingMember}) : super(key: key);

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _nicknameController = TextEditingController();
  final _memberService = MemberService();
  
  Gender _selectedGender = Gender.male;
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
      _selectedGender = widget.existingMember!.gender;
      _selectedBirthdate = widget.existingMember!.birthdate;
      _selectedHeight = widget.existingMember!.heightCm;
      _selectedUserType = widget.existingMember!.userType;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _canSave {
    return _nicknameController.text.trim().isNotEmpty &&
        _selectedBirthdate != null &&
        _selectedHeight != null;
  }

  Future<void> _saveMember() async {
    if (!_canSave) return;
    
    setState(() => _isLoading = true);
    
    try {
      final member = Member(
        id: widget.existingMember?.id ?? MemberService.generateId(),
        nickname: _nicknameController.text.trim(),
        gender: _selectedGender,
        birthdate: _selectedBirthdate!,
        heightCm: _selectedHeight!,
        userType: _selectedUserType,
        createdAt: widget.existingMember?.createdAt,
      );
      
      if (isEditing) {
        await _memberService.updateMember(member);
      } else {
        await _memberService.addMember(member);
      }
      
      if (mounted) {
        Navigator.pop(context, member);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving member: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBirthdatePicker() {
    final now = DateTime.now();
    final initialDate = _selectedBirthdate ?? DateTime(now.year - 25, 1, 1);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const Text('Birthdate', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: TextStyle(color: AppTheme.primaryColor)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumYear: 1920,
                maximumYear: now.year,
                onDateTimeChanged: (date) {
                  setState(() => _selectedBirthdate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHeightPicker() {
    final initialHeight = _selectedHeight ?? 170;
    int tempHeight = initialHeight;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const Text('Height (cm)', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedHeight = tempHeight);
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: TextStyle(color: AppTheme.primaryColor)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: initialHeight - 100,
                ),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  tempHeight = index + 100;
                },
                children: List.generate(151, (index) {
                  final height = index + 100;
                  return Center(
                    child: Text(
                      '$height cm',
                      style: const TextStyle(fontSize: 18),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: const Center(
                child: Text('User type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: UserType.values.length,
                itemBuilder: (context, index) {
                  final type = UserType.values[index];
                  final isSelected = _selectedUserType == type;
                  return ListTile(
                    title: Text(
                      type.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryColor : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      type.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: AppTheme.primaryColor)
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Member' : 'Add Member',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Personal information is used for measurement purposes only.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            
            // Avatar
            Center(
              child: GestureDetector(
                onTap: () {
                  // TODO: Implement image picker
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.grey[200],
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Nickname field
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nickname', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    maxLength: 25,
                    decoration: InputDecoration(
                      hintText: 'Please enter your Nickname',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: const UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                      counterText: '${_nicknameController.text.length}/25',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Gender selector
            _buildSelectorRow(
              'Gender',
              Row(
                children: [
                  _buildGenderButton(Gender.male, Icons.male),
                  const SizedBox(width: 16),
                  _buildGenderButton(Gender.female, Icons.female),
                ],
              ),
            ),
            
            // Birthdate selector
            _buildSelectorRow(
              'Birthdate',
              GestureDetector(
                onTap: _showBirthdatePicker,
                child: Row(
                  children: [
                    Text(
                      _selectedBirthdate != null
                          ? '${_selectedBirthdate!.year}-${_selectedBirthdate!.month.toString().padLeft(2, '0')}-${_selectedBirthdate!.day.toString().padLeft(2, '0')}'
                          : '--',
                      style: TextStyle(
                        color: _selectedBirthdate != null ? Colors.black : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            
            // Height selector
            _buildSelectorRow(
              'Height',
              GestureDetector(
                onTap: _showHeightPicker,
                child: Row(
                  children: [
                    Text(
                      _selectedHeight != null ? '$_selectedHeight cm' : '--',
                      style: TextStyle(
                        color: _selectedHeight != null ? Colors.black : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            
            // User type selector
            _buildSelectorRow(
              'User type',
              GestureDetector(
                onTap: _showUserTypePicker,
                child: Row(
                  children: [
                    Text(
                      _selectedUserType.displayName,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Confirm button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _canSave && !_isLoading ? _saveMember : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSave ? AppTheme.primaryColor : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          color: _canSave ? Colors.white : Colors.grey[500],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderButton(Gender gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildSelectorRow(String label, Widget selector) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          selector,
        ],
      ),
    );
  }
}
