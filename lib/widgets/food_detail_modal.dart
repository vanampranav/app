import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../services/nutrition_service.dart';
import '../theme/app_theme.dart';

class FoodDetailModal extends StatefulWidget {
  final FoodItem food;
  final double weight;
  final NutritionService nutritionService;

  const FoodDetailModal({
    Key? key,
    required this.food,
    required this.weight,
    required this.nutritionService,
  }) : super(key: key);

  @override
  State<FoodDetailModal> createState() => _FoodDetailModalState();
}

class _FoodDetailModalState extends State<FoodDetailModal> {
  NutritionData? _nutritionData;
  String? _foodName;
  double? _calculatedWeight;
  bool _isLoading = true;
  String? _errorMessage;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.weight.toStringAsFixed(1));
    _calculateNutrition();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _calculateNutrition() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weight = double.tryParse(_weightController.text) ?? widget.weight;
      final result = await widget.nutritionService.calculateNutrition(
        widget.food.fdcId,
        weight,
      );

      setState(() {
        _foodName = result['foodName'];
        _calculatedWeight = result['weight'];
        _nutritionData = result['nutrition'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to calculate nutrition: $e';
        _isLoading = false;
      });
    }
  }

  void _save() {
    final weight = double.tryParse(_weightController.text);
    if (_nutritionData != null && _foodName != null && weight != null) {
      Navigator.pop(context, {
        'foodName': _foodName,
        'weight': weight,
        'nutrition': _nutritionData,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
              children: [
                const Icon(Icons.star_border, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Collect', style: TextStyle(fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _calculateNutrition,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bluetooth status
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Phone's bluetooth is turned off.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const Spacer(),
                        const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Food image and name
                    Center(
                      child: Column(
                        children: [
                          if (widget.food.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.food.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                              ),
                            )
                          else
                            _buildPlaceholderImage(),
                          const SizedBox(height: 12),
                          Text(
                            _foodName ?? widget.food.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Editable weight field
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.0',
                                  ),
                                  onChanged: (value) {
                                    // Recalculate nutrition when weight changes
                                    if (value.isNotEmpty && double.tryParse(value) != null) {
                                      _calculateNutrition();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'g',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Weight from scale (editable)',
                            style: const TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Unit, Save, Tare buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('⚖ Unit', style: TextStyle(color: AppTheme.primaryColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('💾 Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('□ Tare', style: TextStyle(color: AppTheme.primaryColor)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Nutritional composition
                    const Text(
                      'Nutritional composition',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // Calorie circle with macros
                    Row(
                      children: [
                        // Calorie circle
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            children: [
                              Center(
                                child: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: 1.0,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _nutritionData?.calories.toStringAsFixed(1) ?? '0',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      'kcal',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Macros
                        Expanded(
                          child: Column(
                            children: [
                              _buildMacroRow('Fat', _nutritionData?.fat ?? 0, Colors.orange),
                              const SizedBox(height: 8),
                              _buildMacroRow('Carbs', _nutritionData?.carbs ?? 0, Colors.blue),
                              const SizedBox(height: 8),
                              _buildMacroRow('Protein', _nutritionData?.protein ?? 0, Colors.purple),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Detailed nutrients
                    _buildNutrientRow('Dietary Fiber', _nutritionData?.fiber),
                    _buildNutrientRow('Carotene', _nutritionData?.carotene),
                    _buildNutrientRow('Retinol Equivalent', _nutritionData?.retinol),
                    _buildNutrientRow('Cholesterol', _nutritionData?.cholesterol),
                    _buildNutrientRow('Vitamin A', _nutritionData?.vitaminA),
                    _buildNutrientRow('Vitamin B1', _nutritionData?.vitaminB1),
                    _buildNutrientRow('Vitamin B2', _nutritionData?.vitaminB2),
                    _buildNutrientRow('Vitamin C', _nutritionData?.vitaminC),
                    _buildNutrientRow('Vitamin E', _nutritionData?.vitaminE),
                    _buildNutrientRow('K', _nutritionData?.potassium),
                    _buildNutrientRow('Na', _nutritionData?.sodium),
                    _buildNutrientRow('Ca', _nutritionData?.calcium),
                    _buildNutrientRow('Mg', _nutritionData?.magnesium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
    );
  }

  Widget _buildMacroRow(String name, double value, Color color) {
    final totalMacros = (_nutritionData?.fat ?? 0) + 
                       (_nutritionData?.carbs ?? 0) + 
                       (_nutritionData?.protein ?? 0);
    final percent = totalMacros > 0 ? ((value / totalMacros) * 100).round() : 0;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(1)}g  $percent%',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(String name, double? value) {
    if (value == null || value == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(name, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(2)}${_getUnit(name)}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getUnit(String nutrient) {
    if (nutrient.contains('Vitamin') || nutrient.contains('Retinol') || nutrient.contains('Carotene')) {
      return 'μg';
    } else if (nutrient.contains('Cholesterol') || nutrient == 'Na' || nutrient == 'K' || 
               nutrient == 'Ca' || nutrient == 'Mg') {
      return 'mg';
    } else {
      return 'g';
    }
  }
}
