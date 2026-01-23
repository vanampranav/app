import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UnitSelectorModal extends StatefulWidget {
  final String currentUnit;
  final Function(String) onUnitSelected;

  const UnitSelectorModal({
    Key? key,
    required this.currentUnit,
    required this.onUnitSelected,
  }) : super(key: key);

  @override
  State<UnitSelectorModal> createState() => _UnitSelectorModalState();
}

class _UnitSelectorModalState extends State<UnitSelectorModal> {
  late String _selectedUnit;

  final List<Map<String, String>> _units = [
    {'value': 'ml', 'label': 'ml'},
    {'value': 'ml_m', 'label': 'ml(m)'},
    {'value': 'oz', 'label': 'oz'},
    {'value': 'lb', 'label': 'lb:oz'},
    {'value': 'fl_oz', 'label': 'fl\'oz'},
    {'value': 'fl_oz_m', 'label': 'fl\'oz(m)'},
    {'value': 'g', 'label': 'g'},
    {'value': 'mg', 'label': 'mg'},
    {'value': 'kg', 'label': 'kg'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.currentUnit;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Kitchen Scale Unit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Unit list
          Expanded(
            child: ListView.builder(
              itemCount: _units.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final unit = _units[index];
                final isSelected = _selectedUnit == unit['value'];
                
                return RadioListTile<String>(
                  value: unit['value']!,
                  groupValue: _selectedUnit,
                  onChanged: (value) {
                    setState(() {
                      _selectedUnit = value!;
                    });
                  },
                  title: Text(
                    unit['label']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : Colors.black,
                    ),
                  ),
                  activeColor: AppTheme.primaryColor,
                );
              },
            ),
          ),

          // Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onUnitSelected(_selectedUnit);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
