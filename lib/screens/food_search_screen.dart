import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../services/nutrition_service.dart';
import '../theme/app_theme.dart';
import '../widgets/food_detail_modal.dart';

class FoodSearchScreen extends StatefulWidget {
  final MealType meal;
  final double currentWeight;
  final NutritionService nutritionService;

  const FoodSearchScreen({
    Key? key,
    required this.meal,
    required this.currentWeight,
    required this.nutritionService,
  }) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<FoodItem> _recentlyUsed = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentlyUsed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentlyUsed() async {
    final recently = await widget.nutritionService.getRecentlyUsed();
    setState(() {
      _recentlyUsed = recently;
    });
  }

  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await widget.nutritionService.searchFood(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search: $e';
        _isLoading = false;
      });
    }
  }

  void _selectFood(FoodItem food) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodDetailModal(
        food: food,
        weight: widget.currentWeight,
        nutritionService: widget.nutritionService,
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      // Create meal entry
      final entry = MealEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        foodName: result['foodName'],
        fdcId: food.fdcId,
        weight: result['weight'],
        nutrition: result['nutrition'],
        meal: widget.meal,
        timestamp: DateTime.now(),
        imageUrl: food.imageUrl,
      );

      // Save to recently used
      await widget.nutritionService.saveToRecentlyUsed(food);

      // Return to kitchen scale screen
      if (mounted) {
        Navigator.pop(context, entry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: DropdownButton<MealType>(
          value: widget.meal,
          underline: Container(),
          icon: const Icon(Icons.arrow_drop_down),
          items: MealType.values.map((meal) {
            return DropdownMenuItem(
              value: meal,
              child: Text(_getMealName(meal)),
            );
          }).toList(),
          onChanged: (value) {
            // TODO: Update meal type
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Please enter the name of the food',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              onSubmitted: _searchFood,
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Recently Used'),
              Tab(text: 'Collect'),
              Tab(text: 'Customization'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentlyUsedTab(),
                _buildCollectTab(),
                _buildCustomizationTab(),
              ],
            ),
          ),

          // Complete button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '0',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getMealName(widget.meal),
                  style: const TextStyle(fontSize: 16),
                ),
                const Icon(Icons.arrow_drop_down),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Complete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyUsedTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _searchFood(_searchController.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final foods = _searchResults.isNotEmpty ? _searchResults : _recentlyUsed;

    if (foods.isEmpty) {
      return const Center(
        child: Text(
          'No foods found. Try searching for a food.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return ListTile(
          leading: food.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    food.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  ),
                )
              : _buildPlaceholderImage(),
          title: Text(food.name),
          subtitle: Text('${food.servingSize} / ${food.caloriesPer100g.toInt()}kcal'),
          onTap: () => _selectFood(food),
        );
      },
    );
  }

  Widget _buildCollectTab() {
    return const Center(
      child: Text('Collect tab - Coming soon', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildCustomizationTab() {
    return const Center(
      child: Text('Customization tab - Coming soon', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }

  String _getMealName(MealType meal) {
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
}
