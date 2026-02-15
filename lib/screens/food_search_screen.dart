import 'package:flutter/material.dart';
import '../models/food_models.dart';
import '../models/device_model.dart';
import '../services/nutrition_service.dart';
import '../theme/app_theme.dart';
import '../widgets/food_detail_modal.dart';

class FoodSearchScreen extends StatefulWidget {
  final MealType meal;
  final double currentWeight;
  final NutritionService nutritionService;
  final Stream<WeightMeasurement>? weightStream;

  const FoodSearchScreen({
    Key? key,
    required this.meal,
    required this.currentWeight,
    required this.nutritionService,
    this.weightStream,
  }) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<FoodItem> _recentlyUsed = [];
  List<MealEntry> _tempFoodList = [];
  bool _isLoading = false;
  String? _errorMessage;
  late MealType _selectedMealType;
  MealType _selectedSavedListTab = MealType.breakfast;

  // Meal types for dropdown
  final List<MealType> _mealTypes = [
    MealType.breakfast,
    MealType.lunch,
    MealType.dinner,
    MealType.snacks,
  ];

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.meal;
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
        weightStream: widget.weightStream,
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
        meal: _selectedMealType,
        timestamp: DateTime.now(),
        imageUrl: food.imageUrl,
      );

      // Save to recently used
      await widget.nutritionService.saveToRecentlyUsed(food);

      // Add to temp list instead of popping
      setState(() {
        _tempFoodList.add(entry);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.foodName} added to list')),
      );
    }
  }

  void _removeTempEntry(int index) {
    setState(() {
      _tempFoodList.removeAt(index);
    });
  }

  void _completeSelection() {
    Navigator.pop(context, _tempFoodList);
  }

  String _getMealName(MealType meal) {
    switch (meal) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch: return 'Lunch';
      case MealType.dinner: return 'Dinner';
      case MealType.snacks: return 'Snacks';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: DropdownButton<MealType>(
          value: _selectedMealType,
          underline: Container(),
          icon: const Icon(Icons.arrow_drop_down),
          items: _mealTypes.map((meal) {
            return DropdownMenuItem(
              value: meal,
              child: Text(
                _getMealName(meal),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedMealType = value;
              });
            }
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

          // Saved items preview (if any)
          if (_tempFoodList.isNotEmpty)
            _buildSavedItemsList(),

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
                  child: Text(
                    '${_tempFoodList.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getMealName(_selectedMealType),
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _tempFoodList.isNotEmpty ? _completeSelection : null,
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

  Widget _buildSavedItemsList() {
    // Filter items for the selected tab
    final currentItems = _tempFoodList.where((item) => item.meal == _selectedSavedListTab).toList();
    
    // Calculate total calories for current tab
    double totalCalories = 0;
    for (var item in currentItems) {
      if (item.nutrition != null) {
        totalCalories += item.nutrition!.calories;
      }
    }

    return Container(
      height: 300, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Sidebar (Tabs)
          Container(
            width: 100,
            color: Colors.grey[50], // Slightly different bg for sidebar
            child: Column(
              children: _mealTypes.map((meal) {
                final isSelected = _selectedSavedListTab == meal;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSavedListTab = meal;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: isSelected 
                        ? const Border(left: BorderSide(color: AppTheme.primaryColor, width: 4))
                        : null,
                    ),
                    child: Center(
                      child: Text(
                        _getMealName(meal),
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Right Content (Food List)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header for Selected Meal
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total of ${currentItems.length} records, with total of",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${totalCalories.toStringAsFixed(1)}kcal",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentItems.isEmpty 
                    ? Center(
                        child: Text(
                          "No foods needed", 
                          style: TextStyle(color: Colors.grey[400], fontSize: 12)
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: currentItems.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = currentItems[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                // Image
                                if (entry.imageUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20), // Circle as per mockup
                                    child: Image.network(
                                      entry.imageUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const CircleAvatar(radius: 20, backgroundColor: Colors.grey, child: Icon(Icons.fastfood, size: 16, color: Colors.white)),
                                    ),
                                  )
                                else
                                  const CircleAvatar(radius: 20, backgroundColor: Colors.grey, child: Icon(Icons.fastfood, size: 16, color: Colors.white)),
                                
                                const SizedBox(width: 12),
                                // Text Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.foodName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        "${entry.weight >= 1000 ? (entry.weight/1000).toStringAsFixed(2) + ' kg' : entry.weight.toStringAsFixed(1) + ' g'} / ${(entry.nutrition?.calories ?? 0).toStringAsFixed(1)}kcal", 
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete Action
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _tempFoodList.remove(entry);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
}
