import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../theme/app_theme.dart';

class NutrientAnalysisScreen extends StatelessWidget {
  final DailySummary dailySummary;

  const NutrientAnalysisScreen({
    Key? key,
    required this.dailySummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalCalories = dailySummary.totalCalories;
    
    // Aggregate all nutrients
    double totalFiber = 0;
    double totalCholesterol = 0;
    double totalCalcium = 0;
    double totalIron = 0;
    double totalSodium = 0;
    double totalPotassium = 0;
    double totalMagnesium = 0;
    double totalZinc = 0;
    
    for (var entry in dailySummary.entries) {
      totalFiber += entry.nutrition.fiber;
      totalCholesterol += entry.nutrition.cholesterol ?? 0;
      totalCalcium += entry.nutrition.calcium ?? 0;
      totalIron += entry.nutrition.iron ?? 0;
      totalSodium += entry.nutrition.sodium ?? 0;
      totalPotassium += entry.nutrition.potassium ?? 0;
      totalMagnesium += entry.nutrition.magnesium ?? 0;
      totalZinc += entry.nutrition.zinc ?? 0;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Nutrient Analysis'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calorie intake card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            totalCalories.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Kcal',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Calorie Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Macronutrients
            const Text(
              'Macronutrients',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildNutrientCard('Fat', dailySummary.totalFat, 'g', Colors.orange),
            _buildNutrientCard('Carbs', dailySummary.totalCarbs, 'g', Colors.blue),
            _buildNutrientCard('Protein', dailySummary.totalProtein, 'g', Colors.purple),
            _buildNutrientCard('Dietary Fiber', totalFiber, 'g', Colors.green),
            
            const SizedBox(height: 24),

            // Minerals
            const Text(
              'Minerals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (totalCalcium > 0) _buildNutrientCard('Ca', totalCalcium, 'mg', Colors.teal),
            if (totalIron > 0) _buildNutrientCard('Fe', totalIron, 'mg', Colors.red),
            if (totalMagnesium > 0) _buildNutrientCard('Mg', totalMagnesium, 'mg', Colors.indigo),
            if (totalPotassium > 0) _buildNutrientCard('K', totalPotassium, 'mg', Colors.amber),
            if (totalSodium > 0) _buildNutrientCard('Na', totalSodium, 'mg', Colors.pink),
            if (totalZinc > 0) _buildNutrientCard('Zn', totalZinc, 'mg', Colors.cyan),
            
            const SizedBox(height: 24),

            // Other
            const Text(
              'Other',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (totalCholesterol > 0) 
              _buildNutrientCard('Cholesterol', totalCholesterol, 'mg', Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String name, double value, String unit, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} $unit',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
