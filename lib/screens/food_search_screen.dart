import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/food_models.dart';
import '../models/device_model.dart';
import '../services/nutrition_service.dart';
import '../theme/app_theme.dart';
import '../utils/food_emoji_helper.dart';
import '../utils/food_icon_helper.dart';
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

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<FoodItem>  _searchResults    = [];
  List<FoodItem>  _recentlyUsed     = [];
  List<MealEntry> _tempFoodList     = [];
  List<String>    _suggestions      = [];
  bool _isLoading        = false;
  bool _hasSearched      = false;
  bool _showCart         = false;
  bool _showSuggestions  = false;
  bool _isBarcodeLoading = false;
  String? _errorMessage;
  Timer? _debounce;
  late MealType _selectedMealType;

  static const _mealEmoji = {
    MealType.breakfast: '🌅',
    MealType.lunch:     '☀️',
    MealType.dinner:    '🌙',
    MealType.snacks:    '🍎',
  };
  static const _mealColor = {
    MealType.breakfast: Color(0xFFFF8C42),
    MealType.lunch:     Color(0xFF3B9EFF),
    MealType.dinner:    Color(0xFF8B5CF6),
    MealType.snacks:    Color(0xFF4ECDC4),
  };

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.meal;
    _loadRecentlyUsed();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentlyUsed() async {
    final items = await widget.nutritionService.getRecentlyUsed();
    if (mounted) setState(() => _recentlyUsed = items);
  }

  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _hasSearched = false; });
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; _hasSearched = true; });
    try {
      final results = await widget.nutritionService.searchFood(query.trim());
      if (mounted) setState(() { _searchResults = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Search failed. Check your connection.'; _isLoading = false; });
    }
  }

  Future<void> _selectFood(FoodItem food) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailModal(
        food: food,
        weight: widget.currentWeight,
        nutritionService: widget.nutritionService,
        weightStream: widget.weightStream,
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
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
      await widget.nutritionService.saveToRecentlyUsed(food);
      setState(() => _tempFoodList.add(entry));
    }
  }

  void _completeSelection() => Navigator.pop(context, _tempFoodList);

  String _mealName(MealType m) {
    switch (m) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
      case MealType.snacks:    return 'Snacks';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _mealColor[_selectedMealType]!;

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(accent),
            _buildSearchBar(keyboardOpen: keyboardOpen),
            // Tapping anywhere in the results area dismisses the suggestions
            // dropdown and the keyboard (result cards keep their own taps).
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_showSuggestions || _searchFocus.hasFocus) {
                    _searchFocus.unfocus();
                    setState(() {
                      _showSuggestions = false;
                    });
                  }
                },
                child: _buildBody(),
              ),
            ),
            if (!(keyboardOpen && _showSuggestions)) _buildFatSecretBadge(),
            _buildBottomBar(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildFatSecretBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nutrition data powered by ',
            style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary),
          ),
          Text(
            'fatsecret',
            style: AppTheme.labelSM.copyWith(
              color: const Color(0xFF8CC63F),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 18),
            onPressed: () => Navigator.pop(context, _tempFoodList),
          ),
          const SizedBox(width: 4),
          Text(
            '${_mealEmoji[_selectedMealType]} Log',
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(width: 6),
          // Meal selector
          GestureDetector(
            onTap: _showMealPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_mealName(_selectedMealType),
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 16, color: accent),
              ]),
            ),
          ),
          const Spacer(),
          if (widget.weightStream != null)
            Row(children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppTheme.lime,
                ),
              ),
              const SizedBox(width: 5),
              Text('Scale', style: AppTheme.labelMD.copyWith(color: AppTheme.lime)),
            ]),
        ],
      ),
    );
  }

  void _showMealPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('Log to', style: AppTheme.headingSM),
          ),
          ...MealType.values.map((m) {
            final c = _mealColor[m]!;
            return ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(_mealEmoji[m]!,
                    style: const TextStyle(fontSize: 18))),
              ),
              title: Text(_mealName(m), style: AppTheme.headingSM),
              onTap: () {
                setState(() => _selectedMealType = m);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar({bool keyboardOpen = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary),
                  cursorColor: AppTheme.lime,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    // Cancel any pending autocomplete so it can't re-open the
                    // suggestions after we close them, and dismiss the keyboard.
                    _debounce?.cancel();
                    _searchFocus.unfocus();
                    setState(() {
                      _showSuggestions = false;
                      _suggestions = [];
                    });
                    _searchFood(v);
                  },
                  onChanged: (v) {
                    if (v.isEmpty) {
                      _debounce?.cancel();
                      setState(() {
                        _searchResults = [];
                        _hasSearched = false;
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                      return;
                    }
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () async {
                      final results = await widget.nutritionService.searchAutocomplete(v);
                      // Only reopen suggestions if the field is still focused —
                      // otherwise an in-flight autocomplete would re-show the
                      // dropdown right after the user tapped Search / picked one.
                      if (mounted &&
                          _searchController.text == v &&
                          _searchFocus.hasFocus) {
                        setState(() {
                          _suggestions = results;
                          _showSuggestions = results.isNotEmpty;
                        });
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search food…',
                    hintStyle: AppTheme.bodyLG.copyWith(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textTertiary, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppTheme.textTertiary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _hasSearched = false;
                                _suggestions = [];
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.lime, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Barcode scan button
              GestureDetector(
                onTap: _isBarcodeLoading ? null : _openBarcodeScanner,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.surface1,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: _isBarcodeLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.lime,
                          ),
                        )
                      : const Icon(Icons.qr_code_scanner_rounded,
                          color: AppTheme.lime, size: 24),
                ),
              ),
            ],
          ),
          // Autocomplete dropdown (floats over body, height capped to prevent overflow)
          if (_showSuggestions)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: keyboardOpen ? 176 : 264),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _suggestions.map((s) => InkWell(
                      onTap: () {
                        _debounce?.cancel();
                        _searchFocus.unfocus();
                        _searchController.text = s;
                        setState(() { _showSuggestions = false; _suggestions = []; });
                        _searchFood(s);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: AppTheme.textTertiary, size: 16),
                            const SizedBox(width: 10),
                            Text(s, style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Barcode scanner ─────────────────────────────────────────────────────────
  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (result == null || !mounted) return;

    setState(() => _isBarcodeLoading = true);
    try {
      final food = await widget.nutritionService.searchByBarcode(result);
      if (!mounted) return;
      if (food == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No food found for this barcode. Try searching by name.'),
        ));
      } else {
        _selectFood(food);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Barcode lookup failed: ${e.toString().replaceAll('Exception: ', '')}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isBarcodeLoading = false);
    }
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.lime, strokeWidth: 2),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: AppTheme.bodyMD, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _searchFood(_searchController.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text('Try again', style: AppTheme.labelLG),
            ),
          ),
        ]),
      );
    }

    if (_hasSearched && _searchResults.isNotEmpty) {
      return _buildResultsList(_searchResults);
    }
    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No results found', style: AppTheme.headingSM),
          const SizedBox(height: 8),
          Text('Try a different search term', style: AppTheme.bodyMD),
        ]),
      );
    }

    // Default: recently used
    return _buildRecentlyUsed();
  }

  Widget _buildRecentlyUsed() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        if (_recentlyUsed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('RECENTLY USED',
                style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
          ),
          ..._recentlyUsed.map((f) => _buildFoodCard(f)),
        ] else
          const SizedBox(
            height: 200,
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🥗', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Search to find foods',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 6),
                Text('Type a food name and press search',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsList(List<FoodItem> foods) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: foods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildFoodCard(foods[i]),
    );
  }

  Widget _buildFoodCard(FoodItem food) {
    return GestureDetector(
      onTap: () => _selectFood(food),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(children: [
          // Food icon / image
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: food.imageUrl != null
                ? Image.network(
                    food.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(FoodEmojiHelper.get(food.name),
                          style: const TextStyle(fontSize: 22))),
                  )
                : Center(
                    child: Text(FoodEmojiHelper.get(food.name),
                        style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          // Name + serving
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(food.name,
                  style: AppTheme.headingSM.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(food.servingSize,
                  style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
            ]),
          ),
          const SizedBox(width: 10),
          // Calories + add
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${food.caloriesPer100g.round()}',
                style: AppTheme.numericMD.copyWith(
                    fontSize: 18, color: AppTheme.lime)),
            Text('kcal', style: AppTheme.labelSM),
          ]),
          const SizedBox(width: 10),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.lime.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: AppTheme.lime, size: 18),
          ),
        ]),
      ),
    );
  }

  // ── Bottom bar + expandable cart panel ────────────────────────────────────
  Widget _buildBottomBar(Color accent) {
    final count = _tempFoodList.length;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Expanded cart panel ──────────────────────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: _showCart && count > 0
            ? _buildCartPanel()
            : const SizedBox.shrink(),
      ),
      // ── Action bar ──────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: Row(children: [
          // Count badge — tap to expand/collapse
          GestureDetector(
            onTap: count > 0 ? () => setState(() => _showCart = !_showCart) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _showCart && count > 0
                    ? AppTheme.lime.withOpacity(0.12)
                    : AppTheme.surface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: _showCart && count > 0
                      ? AppTheme.lime.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (count > 0) ...[
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: AppTheme.lime, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$count',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('item${count == 1 ? '' : 's'}',
                      style: AppTheme.bodyMD),
                  const SizedBox(width: 4),
                  Icon(
                    _showCart
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppTheme.lime, size: 18,
                  ),
                ] else ...[
                  const Icon(Icons.restaurant_menu_rounded,
                      color: AppTheme.textTertiary, size: 18),
                  const SizedBox(width: 8),
                  Text('0 added',
                      style: AppTheme.bodyMD.copyWith(
                          color: AppTheme.textTertiary)),
                ],
              ]),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: count > 0 ? _completeSelection : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: count > 0 ? AppTheme.lime : AppTheme.surface3,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: count > 0
                    ? [BoxShadow(
                          color: AppTheme.lime.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))]
                    : [],
              ),
              child: Text(
                count > 0 ? 'Done' : 'Add food',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: count > 0 ? Colors.black : AppTheme.textTertiary,
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildCartPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        border: Border(
          top:    BorderSide(color: Colors.white.withOpacity(0.06)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _tempFoodList.length,
        separatorBuilder: (_, __) => Divider(
            height: 1, color: Colors.white.withOpacity(0.04), indent: 16),
        itemBuilder: (_, i) {
          final entry = _tempFoodList[i];
          final meta  = _mealMeta(entry.meal);
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              // Meal badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                      color: meta.color.withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(MealIconHelper.icon(entry.meal),
                      size: 12, color: meta.color),
                  const SizedBox(width: 4),
                  Text(meta.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: meta.color)),
                ]),
              ),
              const SizedBox(width: 10),
              // Food name
              Expanded(
                child: Text(
                  entry.foodName,
                  style: AppTheme.headingSM.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Weight + calories
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${entry.weight.round()}g',
                    style: AppTheme.bodySM
                        .copyWith(color: AppTheme.textTertiary)),
                Text('${entry.nutrition.calories.round()} kcal',
                    style: AppTheme.labelMD
                        .copyWith(color: AppTheme.lime)),
              ]),
              const SizedBox(width: 8),
              // Remove
              GestureDetector(
                onTap: () => setState(() {
                  _tempFoodList.removeAt(i);
                  if (_tempFoodList.isEmpty) _showCart = false;
                }),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.error, size: 15),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Cart meta helper ─────────────────────────────────────────────────────
  static _CartMeta _mealMeta(MealType m) {
    switch (m) {
      case MealType.breakfast: return const _CartMeta('🌅','Breakfast', Color(0xFFFF8C42));
      case MealType.lunch:     return const _CartMeta('☀️','Lunch',     Color(0xFF3B9EFF));
      case MealType.dinner:    return const _CartMeta('🌙','Dinner',    Color(0xFF8B5CF6));
      case MealType.snacks:    return const _CartMeta('🍎','Snacks',    Color(0xFF4ECDC4));
    }
  }
}

class _CartMeta {
  final String emoji, label;
  final Color color;
  const _CartMeta(this.emoji, this.label, this.color);
}

// ── Barcode scanner full-screen page ────────────────────────────────────────
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();
  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scanner.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
              final code = barcode?.rawValue;
              if (code != null && code.isNotEmpty) {
                _scanned = true;
                Navigator.of(context).pop(code);
              }
            },
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.lime, width: 2.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0, right: 0,
            child: Text(
              'Point your camera at a food barcode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
