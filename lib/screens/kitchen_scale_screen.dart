import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../models/food_models.dart';
import '../services/fitdays_service.dart';
import '../services/nutrition_service.dart';
import '../theme/app_theme.dart';
import 'food_search_screen.dart';
import 'meal_details_screen.dart';
import 'nutrient_analysis_screen.dart';
import '../widgets/unit_selector_modal.dart';

class KitchenScaleScreen extends StatefulWidget {
  final FitDaysDevice connectedDevice;
  final FitDaysService fitDaysService;

  const KitchenScaleScreen({
    Key? key,
    required this.connectedDevice,
    required this.fitDaysService,
  }) : super(key: key);

  @override
  State<KitchenScaleScreen> createState() => _KitchenScaleScreenState();
}

class _KitchenScaleScreenState extends State<KitchenScaleScreen> {
  WeightMeasurement? _latestMeasurement;
  DailySummary? _dailySummary;
  final NutritionService _nutritionService = NutritionService();
  bool _isConnected = true; // Device is connected when entering this screen
  String _currentUnit = 'g';

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadDailySummary();
  }

  void _setupListeners() {
    // Only accept kitchen scale readings.
    // Body fat scale readings are tagged bodyFatScale by FitDaysService
    // (or weigh ≥ 10 kg which food almost never does).
    widget.fitDaysService.weightDataStream.listen((measurement) {
      if (!mounted) return;
      if (measurement.source == WeightSource.bodyFatScale) return;
      setState(() {
        _latestMeasurement = measurement;
        if (measurement.unit.isNotEmpty) _currentUnit = measurement.unit;
        _isConnected = true;
      });
    });
    
    // Listen for connection state changes
    widget.fitDaysService.connectionStateStream.listen((state) {
      // Android SDK sends macAddress not deviceId
      final deviceMac = state["macAddress"] ?? state["deviceId"];
      if (mounted && deviceMac == widget.connectedDevice.macAddress) {
        setState(() {
          _isConnected = state["state"] == "connected";
        });
      }
    });
  }


  Future<void> _loadDailySummary() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    // Use YYYY-MM-DD format for consistent date keys
    final dateKey = 'meal_entries_${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final entriesJson = prefs.getString(dateKey);

    debugPrint('Loading meals for date key: $dateKey');
    
    if (entriesJson != null) {
      try {
        final List<dynamic> entriesList = jsonDecode(entriesJson);
        final entries = entriesList.map((e) => MealEntry.fromJson(e)).toList();
        debugPrint('Loaded ${entries.length} meal entries');
        setState(() {
          _dailySummary = DailySummary(date: today, entries: entries);
        });
      } catch (e) {
        debugPrint('Error loading meal entries: $e');
        setState(() {
          _dailySummary = DailySummary(date: today, entries: []);
        });
      }
    } else {
      debugPrint('No saved meals found');
      setState(() {
        _dailySummary = DailySummary(date: today, entries: []);
      });
    }
  }

  Future<void> _saveDailySummary() async {
    if (_dailySummary == null) return;
    final prefs = await SharedPreferences.getInstance();
    final date = _dailySummary!.date;
    // Use YYYY-MM-DD format for consistent date keys
    final dateKey = 'meal_entries_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final entriesJson = jsonEncode(_dailySummary!.entries.map((e) => e.toJson()).toList());
    await prefs.setString(dateKey, entriesJson);
    debugPrint('Saved ${_dailySummary!.entries.length} meal entries to $dateKey');
  }

  void _addFood(MealType meal) async {
    // Get weight from scale and convert to grams
    double currentWeight = _latestMeasurement?.weight ?? 0.0;
    final unit = _latestMeasurement?.unit ?? 'g';
    
    // Convert to grams based on unit
    switch (unit.toLowerCase()) {
      case 'kg':
        currentWeight = currentWeight * 1000;
        break;
      case 'oz':
        currentWeight = currentWeight * 28.3495;
        break;
      case 'lb':
        // lb:oz is usually transmitted as lbs (decimal) or we handled it as such in Android
        currentWeight = currentWeight * 453.592;
        break;
      case 'ml':
      case 'ml_m': // Assuming 1:1 for simplicity or user can adjust
        currentWeight = currentWeight; 
        break;
      case 'fl_oz':
      case 'fl_oz_m':
        currentWeight = currentWeight * 29.5735;
        break;
      case 'mg':
        currentWeight = currentWeight / 1000;
        break;
      default:
        // 'g' or unknown, leave as is
        break;
    }
    
    debugPrint('Current weight for food search: ${currentWeight.toStringAsFixed(1)} g (original: ${_latestMeasurement?.weight} $unit)');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          meal: meal,
          currentWeight: currentWeight,
          nutritionService: _nutritionService,
          weightStream: widget.fitDaysService.weightDataStream,
        ),
      ),
    );

    if (result != null && result is List<MealEntry>) {
      setState(() {
        _dailySummary?.entries.addAll(result);
      });
      await _saveDailySummary();
    }
  }

  Future<void> _handleTare() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected')),
      );
      return;
    }
    
    final success = await widget.fitDaysService.sendTareCommand(
      widget.connectedDevice.macAddress,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scale tared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tare failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUnitSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => UnitSelectorModal(
        currentUnit: _currentUnit,
        onUnitSelected: (unit) async {
          Navigator.pop(context);
          
          if (_isConnected) {
            final success = await widget.fitDaysService.sendUnitChangeCommand(
              widget.connectedDevice.macAddress,
              unit,
            );
            
            if (success) {
              setState(() => _currentUnit = unit);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unit changed to $unit'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unit change failed'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            // Just update UI when disconnected
            setState(() => _currentUnit = unit);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unit set to $unit (will apply when connected)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weight = _latestMeasurement?.weight.toString() ?? "0.0";
    final unit = _latestMeasurement?.unit ?? "g";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Kitchen Scale'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Bluetooth status
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                  const SizedBox(width: 8),
                  const Icon(Icons.qr_code_scanner, color: Colors.grey, size: 20),
                ],
              ),
            ),

            // Weight Display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        weight,
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w300,
                          color: (_latestMeasurement?.weight ?? 0) < 0 ? Colors.red : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unit, Add, Tare buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showUnitSelector,
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
                  ElevatedButton(
                    onPressed: () => _addFood(MealType.snacks),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isConnected ? _handleTare : null,
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
            ),

            // Daily calorie intake
            _buildDailyIntakeCard(),

            // Meal sections
            _buildMealSection('Breakfast', MealType.breakfast, Icons.free_breakfast),
            _buildMealSection('Lunch', MealType.lunch, Icons.lunch_dining),
            _buildMealSection('Dinner', MealType.dinner, Icons.dinner_dining),
            _buildMealSection('Snacks', MealType.snacks, Icons.fastfood),

            // Nutrient Analysis button
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                  if (_dailySummary != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NutrientAnalysisScreen(
                          dailySummary: _dailySummary!,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.analytics_outlined, color: AppTheme.primaryColor),
                label: const Text('Nutrient Analysis', style: TextStyle(color: AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyIntakeCard() {
    final summary = _dailySummary;
    final totalCalories = summary?.totalCalories ?? 0;
    final targetCalories = summary?.targetCalories ?? 2067;
    final fatPercent = summary != null && summary.totalCalories > 0
        ? ((summary.totalFat * 9 / summary.totalCalories) * 100).round()
        : 0;
    final carbsPercent = summary != null && summary.totalCalories > 0
        ? ((summary.totalCarbs * 4 / summary.totalCalories) * 100).round()
        : 0;
    final proteinPercent = summary != null && summary.totalCalories > 0
        ? ((summary.totalProtein * 4 / summary.totalCalories) * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Daily calorie intake',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppTheme.primaryColor),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Intake circle
              Column(
                children: [
                  const Text('Intake', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${totalCalories.toInt()}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('kcal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${targetCalories.toInt()} kcal',
                    style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Macros
              Expanded(
                child: Column(
                  children: [
                    _buildMacroRow('Fat', summary?.totalFat.toStringAsFixed(1) ?? '0', fatPercent),
                    const SizedBox(height: 8),
                    _buildMacroRow('Carbs', summary?.totalCarbs.toStringAsFixed(1) ?? '0', carbsPercent),
                    const SizedBox(height: 8),
                    _buildMacroRow('Protein', summary?.totalProtein.toStringAsFixed(1) ?? '0', proteinPercent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String name, String amount, int percent) {
    return Row(
      children: [
        Icon(_getMacroIcon(name), size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text('${amount}g/${percent}%', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  IconData _getMacroIcon(String name) {
    switch (name) {
      case 'Fat':
        return Icons.opacity;
      case 'Carbs':
        return Icons.grain;
      case 'Protein':
        return Icons.egg;
      default:
        return Icons.circle;
    }
  }

  Widget _buildMealSection(String title, MealType meal, IconData icon) {
    final mealEntries = _dailySummary?.getMealEntries(meal) ?? [];
    final mealCalories = _dailySummary?.getMealCalories(meal) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title ${mealCalories.toInt()}kcal',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (mealEntries.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealDetailsScreen(
                          meal: meal,
                          entries: mealEntries,
                          date: _dailySummary!.date,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Meal Details', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
          if (mealEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...mealEntries.map((entry) => _buildFoodEntry(entry)),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _addFood(meal),
            icon: const Icon(Icons.add, size: 16, color: Colors.grey),
            label: const Text('Add Food', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodEntry(MealEntry entry) {
    return GestureDetector(
      onTap: () {
        // Show nutrition details modal
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildFoodNutritionModal(entry),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (entry.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  entry.imageUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[300],
                    child: const Icon(Icons.fastfood, size: 20),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.fastfood, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.foodName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${entry.weight.toStringAsFixed(1)}g',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.nutrition.calories.toInt()} kcal',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodNutritionModal(MealEntry entry) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                Text(
                  entry.foodName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${entry.weight.toStringAsFixed(1)} g',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Calorie circle with macros
                  Row(
                    children: [
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
                                    entry.nutrition.calories.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('kcal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildMacroRowModal('Fat', entry.nutrition.fat, Colors.orange),
                            const SizedBox(height: 8),
                            _buildMacroRowModal('Carbs', entry.nutrition.carbs, Colors.blue),
                            const SizedBox(height: 8),
                            _buildMacroRowModal('Protein', entry.nutrition.protein, Colors.purple),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Detailed nutrients
                  const Text('Nutrients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _buildNutrientRowModal('Dietary Fiber', entry.nutrition.fiber, 'g'),
                  if (entry.nutrition.cholesterol != null && entry.nutrition.cholesterol! > 0)
                    _buildNutrientRowModal('Cholesterol', entry.nutrition.cholesterol!, 'mg'),
                  if (entry.nutrition.calcium != null && entry.nutrition.calcium! > 0)
                    _buildNutrientRowModal('Calcium', entry.nutrition.calcium!, 'mg'),
                  if (entry.nutrition.iron != null && entry.nutrition.iron! > 0)
                    _buildNutrientRowModal('Iron', entry.nutrition.iron!, 'mg'),
                  if (entry.nutrition.sodium != null && entry.nutrition.sodium! > 0)
                    _buildNutrientRowModal('Sodium', entry.nutrition.sodium!, 'mg'),
                  if (entry.nutrition.potassium != null && entry.nutrition.potassium! > 0)
                    _buildNutrientRowModal('Potassium', entry.nutrition.potassium!, 'mg'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRowModal(String name, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Text('${value.toStringAsFixed(3)}g', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildNutrientRowModal(String name, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(name, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text('${value.toStringAsFixed(2)} $unit', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
