import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class MealDetailsScreen extends StatelessWidget {
  final MealType meal;
  final List<MealEntry> entries;
  final DateTime date;

  const MealDetailsScreen({
    Key? key,
    required this.meal,
    required this.entries,
    required this.date,
  }) : super(key: key);

  String get mealName {
    switch (meal) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snacks:
        return 'Snacks';
    }
  }

  double get totalCalories => entries.fold(0, (sum, e) => sum + e.nutrition.calories);
  double get totalFat => entries.fold(0, (sum, e) => sum + e.nutrition.fat);
  double get totalCarbs => entries.fold(0, (sum, e) => sum + e.nutrition.carbs);
  double get totalProtein => entries.fold(0, (sum, e) => sum + e.nutrition.protein);

  @override
  Widget build(BuildContext context) {
    final totalMacros = totalFat + totalCarbs + totalProtein;
    final fatPercent = totalMacros > 0 ? ((totalFat / totalMacros) * 100).round() : 0;
    final carbsPercent = totalMacros > 0 ? ((totalCarbs / totalMacros) * 100).round() : 0;
    final proteinPercent = totalMacros > 0 ? ((totalProtein / totalMacros) * 100).round() : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Meal Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with meal name and date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.purple[50],
              ),
              child: Column(
                children: [
                  Text(
                    mealName,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Food composition statistics
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Food composition statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // Calorie circle
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          children: [
                            Center(
                              child: SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    totalCalories.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Kcal',
                                    style: TextStyle(fontSize: 14, color: Colors.grey),
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
                            _buildMacroRow('Fat', totalFat, fatPercent, Colors.blue),
                            const SizedBox(height: 12),
                            _buildMacroRow('Carbs', totalCarbs, carbsPercent, Colors.purple),
                            const SizedBox(height: 12),
                            _buildMacroRow('Protein', totalProtein, proteinPercent, Colors.orange),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Food Type section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Food Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  ...entries.map((entry) => _buildFoodItem(entry)),
                ],
              ),
            ),

            // Add Food button
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, color: Colors.grey),
                label: const Text('Add Food', style: TextStyle(color: Colors.grey)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(String name, double value, int percent, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(1)}g | $percent%',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFoodItem(MealEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (entry.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                entry.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
              ),
            )
          else
            _buildPlaceholderImage(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.foodName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.weight.toStringAsFixed(0)}g | ${entry.nutrition.calories.toStringAsFixed(1)}kcal',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, size: 30, color: Colors.grey),
    );
  }
}
