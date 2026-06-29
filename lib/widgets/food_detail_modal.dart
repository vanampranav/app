import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_models.dart';
import '../models/device_model.dart';
import '../services/nutrition_service.dart';
import '../services/fitdays_service.dart';
import '../utils/food_emoji_helper.dart';
import '../utils/food_icon_helper.dart';
import '../utils/nutrition_validator.dart';
import '../theme/app_theme.dart';

class FoodDetailModal extends StatefulWidget {
  final FoodItem food;
  final double weight;
  final NutritionService nutritionService;
  final Stream<WeightMeasurement>? weightStream;

  const FoodDetailModal({
    Key? key,
    required this.food,
    required this.weight,
    required this.nutritionService,
    this.weightStream,
  }) : super(key: key);

  @override
  State<FoodDetailModal> createState() => _FoodDetailModalState();
}

class _FoodDetailModalState extends State<FoodDetailModal> {
  NutritionData? _nutrition;
  String?        _foodName;
  bool           _isLoading   = true;
  String?        _error;
  String?        _warning;     // non-blocking "numbers look off" notice
  bool           _scaleActive = false;
  String         _displayUnit = 'g';   // g | oz | ml | lb

  // Serving options (branded / non-gram foods log by serving + quantity).
  List<FoodServing> _servings = [];
  FoodServing?      _serving;
  double            _quantity = 1;

  /// True when a FitDays scale is connected for this session. When connected we
  /// always use the scale's weight (grams) and hide the serving/cup picker.
  bool get _scaleConnected =>
      FitDaysService().activeScaleMac != null ||
      FitDaysService().connectedDeviceMac != null;

  /// MAC to send tare/unit commands to — prefer the device actively streaming
  /// weight (connectedDeviceMac can be wrongly cleared by a stale bound device).
  String? get _scaleMac =>
      FitDaysService().activeScaleMac ?? FitDaysService().connectedDeviceMac;

  /// Weight mode = grams/ml (scale-compatible). Serving mode = pick "1 grande" × qty.
  /// A connected scale forces weight mode so live readings always apply.
  bool get _isWeightMode =>
      _scaleConnected || _serving == null || _serving!.isWeightBased;

  late TextEditingController _weightCtrl;
  StreamSubscription?        _weightSub;
  Timer?                     _weightDebounce;
  Timer?                     _scaleFreshness; // drops "live" if readings stop

  // ── Unit conversion helpers ──────────────────────────────────────────────
  static const _units = ['g', 'oz', 'ml', 'lb'];
  static const _unitLabels = {'g': 'Grams', 'oz': 'Ounces', 'ml': 'Millilitres', 'lb': 'Pounds'};

  double _toGrams(double val) {
    switch (_displayUnit) {
      case 'oz': return val * 28.3495;
      case 'lb': return val * 453.592;
      default:   return val; // g and ml treated as grams
    }
  }

  double _fromGrams(double grams) {
    switch (_displayUnit) {
      case 'oz': return grams / 28.3495;
      case 'lb': return grams / 453.592;
      default:   return grams;
    }
  }

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.weight > 0 ? widget.weight.toStringAsFixed(1) : '100.0');
    _calculateNutrition();
    _loadServings();
    _setupScaleListener();
  }

  /// Load all serving options. If the food has no gram/ml serving (typical for
  /// branded foods), default to serving mode so the user logs by serving + qty.
  Future<void> _loadServings() async {
    try {
      final r = await widget.nutritionService.getFoodServings(widget.food.fdcId);
      final servings = (r['servings'] as List).cast<FoodServing>();
      if (!mounted || servings.isEmpty) return;
      // Prefer a weight-based serving (keeps grams default + scale working).
      FoodServing def = servings.firstWhere(
        (s) => s.isWeightBased,
        orElse: () => servings.first,
      );
      setState(() {
        _servings = servings;
        _serving = def;
        _foodName = r['foodName'] ?? _foodName;
        _applyWeightServingDefaults(def);
      });
      // Branded food (no weight serving) → compute from the serving immediately.
      if (def.isWeightBased) {
        _calculateNutrition();
      } else {
        _computeServing();
      }
    } catch (e) {
      debugPrint('FoodDetail: getFoodServings failed: $e'); // keep gram path
    }
  }

  void _setupScaleListener() {
    if (widget.weightStream == null) return;
    _weightSub = widget.weightStream!.listen((m) {
      if (!mounted) return;
      _applyScaleWeight(m);
    });

    // Seed the current reading: a broadcast stream only delivers events AFTER we
    // subscribe, so if the scale is idle (no new reading since the sheet opened)
    // we'd otherwise show "No scale". Replay the last cached reading immediately.
    final last = FitDaysService().lastWeight;
    if (last != null && last.source != WeightSource.bodyFatScale) {
      _applyScaleWeight(last);
    }
  }

  /// Mark the scale "live" and arm a freshness timer. A real scale streams
  /// continuously; a powered-off one goes silent — so if no reading arrives for
  /// a few seconds we drop the "live" state.
  void _markScaleLive() {
    _scaleActive = true;
    _scaleFreshness?.cancel();
    _scaleFreshness = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _scaleActive = false);
    });
  }

  void _applyScaleWeight(WeightMeasurement m) {
    // Ignore the scale entirely when logging by serving — only grams use it.
    if (!_isWeightMode) return;
    // Convert scale reading to grams first
    double grams = m.weight;
    switch (m.unit.toLowerCase()) {
      case 'kg': grams *= 1000;    break;
      case 'lb': grams *= 453.592; break;
      case 'oz': grams *= 28.3495; break;
    }
    final displayVal = _fromGrams(grams);
    _weightCtrl.text = displayVal.toStringAsFixed(displayVal >= 1 ? 1 : 0);
    if (grams <= 0) {
      // Scale connected but empty — show it's live and wait for food (no error).
      setState(() { _markScaleLive(); _nutrition = null; _error = null; });
      return;
    }
    setState(_markScaleLive);
    _calculateNutrition();
  }

  @override
  void dispose() {
    _scaleFreshness?.cancel();
    _weightDebounce?.cancel();
    _weightSub?.cancel();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculateNutrition() async {
    // Guard against non-positive weight from ANY source — typed input, paste, or
    // a negative scale reading after a tare. Negative weight => negative calories.
    final displayVal = double.tryParse(_weightCtrl.text) ?? 0;
    if (displayVal <= 0) {
      // Empty / zero / negative weight: show the gentle inline placeholder and
      // disable "Add to Log" — NOT the full-screen red error (too jarring while
      // the user is just clearing the field to type a new number).
      if (mounted) {
        setState(() {
          _error = null;
          _nutrition = null; // disables the "Add to Log" button + shows placeholder
          _isLoading = false;
        });
      }
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      // Always pass grams to the nutrition service
      final w = _toGrams(displayVal);
      final r = await widget.nutritionService.calculateNutrition(widget.food.fdcId, w);
      final nutrition = r['nutrition'] as NutritionData?;
      // Sanity-check the data (covers FatSecret search AND barcode, since both
      // flow through this modal). Surface a soft warning if it looks off.
      final check = nutrition != null
          ? NutritionValidator.validate(nutrition, w)
          : const NutritionCheck();
      if (mounted) setState(() {
        _foodName  = r['foodName'];
        _nutrition = nutrition;
        _warning   = check.warning;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to fetch nutrition data.'; _isLoading = false; });
    }
  }

  /// For a weight-based serving (e.g. "1 cup" = 244 ml), pre-fill the weight
  /// field with that serving's amount and unit so the input matches the label —
  /// instead of always defaulting to 100 g. Does not run while the scale drives.
  void _applyWeightServingDefaults(FoodServing s) {
    // When the scale is connected, leave the unit/amount alone — the scale
    // drives the weight in its own unit (grams).
    if (!s.isWeightBased || _scaleActive || _scaleConnected) return;
    final unit = s.metricUnit == 'ml' ? 'ml' : 'g';
    _displayUnit = unit;
    final amt = s.metricAmount;
    if (amt != null && amt > 0) {
      _weightCtrl.text = amt.toStringAsFixed(0);
    }
  }

  /// Serving-mode nutrition = chosen serving × quantity (no scale, no grams).
  void _computeServing() {
    final s = _serving;
    if (s == null) return;
    if (_quantity <= 0) {
      setState(() {
        _error = 'Quantity must be greater than 0.';
        _nutrition = null;
      });
      return;
    }
    final n = s.nutrition.scale(_quantity);
    final gramsEq = (s.metricAmount ?? 0) * _quantity;
    final check = gramsEq > 0
        ? NutritionValidator.validate(n, gramsEq)
        : const NutritionCheck();
    setState(() {
      _nutrition = n;
      _warning = check.warning;
      _error = null;
      _isLoading = false;
    });
  }

  void _save() {
    if (_nutrition == null || _foodName == null) return;

    if (_isWeightMode) {
      final displayVal = double.tryParse(_weightCtrl.text);
      if (displayVal == null || displayVal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Weight can\'t be negative or zero.'),
        ));
        return;
      }
      Navigator.pop(context, {
        'foodName': _foodName,
        'weight': _toGrams(displayVal), // always grams
        'nutrition': _nutrition,
      });
    } else {
      // Serving mode: quantity must be positive; store the grams-equivalent
      // (metricAmount × qty) when available so totals/display stay consistent.
      if (_quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quantity must be greater than 0.'),
        ));
        return;
      }
      final s = _serving!;
      final gramsEq = (s.metricAmount ?? 0) * _quantity;
      final qtyLabel = _quantity == _quantity.roundToDouble()
          ? _quantity.toInt().toString()
          : _quantity.toString();
      Navigator.pop(context, {
        'foodName': '$_foodName ($qtyLabel × ${s.description})',
        'weight': gramsEq,
        'nutrition': _nutrition,
      });
    }
  }

  void _showUnitSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl)),
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
            child: Text('Select unit', style: AppTheme.headingSM),
          ),
          ..._units.map((u) {
            final isSelected = u == _displayUnit;
            return ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.lime.withOpacity(0.12)
                      : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(u,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? AppTheme.lime
                              : AppTheme.textSecondary)),
                ),
              ),
              title: Text(_unitLabels[u]!, style: AppTheme.bodyLG),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded, color: AppTheme.lime, size: 18)
                  : null,
              onTap: () {
                // Convert current weight value to new unit
                final currentVal = double.tryParse(_weightCtrl.text) ?? 100.0;
                final inGrams    = _toGrams(currentVal);
                setState(() => _displayUnit = u);
                final newVal = _fromGrams(inGrams);
                _weightCtrl.text = newVal.toStringAsFixed(1);
                Navigator.pop(context);
                _calculateNutrition();

                // Send unit change command to the physical scale
                final mac = _scaleMac;
                if (mac != null) {
                  FitDaysService().sendUnitChangeCommand(mac, u);
                }
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _onTareTapped() {
    final mac = _scaleMac;
    if (mac == null) {
      // No scale connected — explain
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
          title: Row(children: [
            const Text('⚖️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('No scale connected', style: AppTheme.headingSM),
          ]),
          content: Text(
            'Connect your FitDays scale in the Scale tab to use tare.',
            style: AppTheme.bodyMD.copyWith(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: Colors.black),
              child: const Text('Got it',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    } else {
      // Send tare command directly to the connected scale
      FitDaysService().sendTareCommand(mac);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.lime, size: 16),
            const SizedBox(width: 8),
            const Text('Tare sent — scale reset to zero.'),
          ]),
          backgroundColor: AppTheme.surface2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXxl)),
      ),
      child: Column(children: [
        _buildHandle(),
        _buildTopBar(),
        const Divider(height: 1, color: AppTheme.divider),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.lime, strokeWidth: 2))
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ]),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      child: Row(children: [
        // Scale indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _scaleActive
                ? AppTheme.lime.withOpacity(0.12)
                : AppTheme.surface3,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: _scaleActive
                    ? AppTheme.lime.withOpacity(0.4)
                    : Colors.transparent),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scaleActive ? AppTheme.lime : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _scaleActive ? 'Scale live' : 'No scale',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _scaleActive ? AppTheme.lime : AppTheme.textTertiary,
              ),
            ),
          ]),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppTheme.textSecondary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: AppTheme.bodyMD, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _calculateNutrition,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text('Retry', style: AppTheme.labelLG),
          ),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 8),
        // Food image + name
        _buildFoodHeader(),
        const SizedBox(height: 28),
        // Weight input
        _buildWeightSection(),
        const SizedBox(height: 24),
        // Action buttons
        _buildActionButtons(),
        const SizedBox(height: 28),
        // Soft data-quality warning (e.g. calories don't match macros)
        if (_warning != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_warning!,
                    style: AppTheme.bodySM.copyWith(color: AppTheme.warning)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        // Calories + macros — only when we have a valid (positive) weight.
        // For zero/negative scale readings (e.g. right after tare) _nutrition is
        // null; show a placeholder instead of crashing, and keep Add disabled.
        if (_nutrition != null) ...[
          _buildNutritionSummary(),
          const SizedBox(height: 20),
          if (_hasDetailedNutrients()) _buildDetailedNutrients(),
        ] else
          _buildAwaitingWeightPlaceholder(),
      ]),
    );
  }

  Widget _buildAwaitingWeightPlaceholder() {
    final val = double.tryParse(_weightCtrl.text) ?? 0;
    final String msg;
    if (val < 0) {
      msg = 'Scale reads a negative value — place the item back on the scale.';
    } else if (_scaleConnected) {
      msg = 'Place food on the scale to see nutrition.';
    } else {
      msg = 'Enter a weight to see nutrition.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        const Icon(Icons.scale_outlined, color: AppTheme.textTertiary, size: 28),
        const SizedBox(height: 10),
        Text(msg, textAlign: TextAlign.center, style: AppTheme.bodyMD),
      ]),
    );
  }

  Widget _buildFoodHeader() {
    return Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: widget.food.imageUrl != null
            ? Image.network(
                widget.food.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(FoodEmojiHelper.get(widget.food.name),
                      style: const TextStyle(fontSize: 36))),
              )
            : Center(
                child: Text(FoodEmojiHelper.get(widget.food.name),
                    style: const TextStyle(fontSize: 36))),
      ),
      const SizedBox(height: 12),
      Text(
        _foodName ?? widget.food.name,
        style: AppTheme.headingMD,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }

  Widget _buildWeightSection() {
    return Column(children: [
      // Serving picker — only when NO scale is connected. With a scale we always
      // weigh in the scale's unit (no cup/serving options).
      if (!_scaleConnected && _servings.length > 1) _buildServingDropdown(),
      // Serving (quantity) mode — no scale, no grams.
      if (!_isWeightMode) _buildQuantityStepper(),
      // Weight mode — grams/ml, scale-driven (unchanged behaviour).
      if (_isWeightMode) ...[
      // Live scale badge
      if (_scaleActive)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.lime.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text('Place food on scale — weight updates live',
              style: AppTheme.bodySM.copyWith(color: AppTheme.lime)),
        ),
      // Weight input row
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 130,
          child: TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Block negative sign and stray characters — only positive decimals.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            textAlign: TextAlign.center,
            style: AppTheme.numericXL.copyWith(
                color: _scaleActive ? AppTheme.lime : AppTheme.textPrimary),
            cursorColor: AppTheme.lime,
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: AppTheme.lime.withOpacity(0.5), width: 1.5),
              ),
              hintText: '100',
              hintStyle: AppTheme.numericXL.copyWith(color: AppTheme.textTertiary),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (v.isNotEmpty && parsed != null && parsed > 0) {
                _weightDebounce?.cancel();
                _weightDebounce = Timer(
                  const Duration(milliseconds: 600),
                  _calculateNutrition,
                );
              }
            },
          ),
        ),
        Text(' $_displayUnit',
            style: AppTheme.numericMD.copyWith(
                color: AppTheme.textSecondary, fontSize: 28)),
      ]),
      ],
    ]);
  }

  Widget _buildServingDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FoodServing>(
          value: _serving,
          isExpanded: true,
          dropdownColor: AppTheme.surface2,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary),
          style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary),
          items: _servings
              .map((s) => DropdownMenuItem<FoodServing>(
                    value: s,
                    child: Text(s.description, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (s) {
            if (s == null) return;
            setState(() {
              _serving = s;
              if (s.isWeightBased) {
                _applyWeightServingDefaults(s); // prefill amount + unit
              } else {
                _quantity = 1; // reset qty when switching to a serving
              }
            });
            if (s.isWeightBased) {
              _calculateNutrition(); // grams path (scale-compatible)
            } else {
              _computeServing();
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuantityStepper() {
    Widget btn(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: AppTheme.lime, size: 22),
          ),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      btn(Icons.remove_rounded, () {
        if (_quantity > 1) { setState(() => _quantity -= 1); _computeServing(); }
      }),
      const SizedBox(width: 20),
      Column(children: [
        Text(_quantity == _quantity.roundToDouble()
            ? _quantity.toInt().toString()
            : _quantity.toString(),
            style: AppTheme.numericXL),
        Text('serving${_quantity > 1 ? 's' : ''}', style: AppTheme.labelSM),
      ]),
      const SizedBox(width: 20),
      btn(Icons.add_rounded, () {
        setState(() => _quantity += 1); _computeServing();
      }),
    ]);
  }

  Widget _buildActionButtons() {
    final addBtn = Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: _nutrition != null ? _save : null,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _nutrition != null ? AppTheme.lime : AppTheme.surface3,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: _nutrition != null
                ? [BoxShadow(color: AppTheme.lime.withOpacity(0.3),
                      blurRadius: 14, offset: const Offset(0, 5))]
                : [],
          ),
          child: Center(
            child: Text('Add to Log',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: _nutrition != null
                        ? Colors.black
                        : AppTheme.textTertiary)),
          ),
        ),
      ),
    );

    // Unit toggle + Tare only apply to weight (grams) mode. In serving mode
    // the dropdown handles units, so just show a full-width Add button.
    if (!_isWeightMode) {
      return Row(children: [addBtn]);
    }
    return Row(children: [
      Expanded(child: _outlineBtn('$_displayUnit ▾', _showUnitSelector)),
      const SizedBox(width: 10),
      addBtn,
      const SizedBox(width: 10),
      Expanded(child: _outlineBtn('□ Tare', _onTareTapped)),
    ]);
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Center(
          child: Text(label,
              style: AppTheme.labelLG.copyWith(color: AppTheme.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildNutritionSummary() {
    final n = _nutrition!;
    final total = n.fat + n.carbs + n.protein;
    final fatPct    = total > 0 ? ((n.fat     / total) * 100).round() : 0;
    final carbsPct  = total > 0 ? ((n.carbs   / total) * 100).round() : 0;
    final protPct   = total > 0 ? ((n.protein / total) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(children: [
        // Calorie ring
        SizedBox(
          width: 100, height: 100,
          child: Stack(children: [
            Center(
              child: SizedBox(
                width: 92, height: 92,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surface3,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.lime),
                ),
              ),
            ),
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${n.calories.round()}',
                    style: AppTheme.numericMD.copyWith(
                        color: AppTheme.lime, fontSize: 22)),
                Text('kcal', style: AppTheme.labelSM),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(children: [
            _macroRow('Fat',     n.fat,     fatPct,    const Color(0xFFFFD93D)),
            const SizedBox(height: 10),
            _macroRow('Carbs',  n.carbs,   carbsPct,  const Color(0xFF4ECDC4)),
            const SizedBox(height: 10),
            _macroRow('Protein',n.protein, protPct,   const Color(0xFFFF6B6B)),
          ]),
        ),
      ]),
    );
  }

  Widget _macroRow(String name, double val, int pct, Color color) {
    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(name, style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary)),
      const Spacer(),
      Text('${val.toStringAsFixed(1)}g',
          style: AppTheme.labelLG.copyWith(color: AppTheme.textPrimary)),
      const SizedBox(width: 6),
      Text('$pct%',
          style: AppTheme.labelMD.copyWith(color: color)),
    ]);
  }

  bool _hasDetailedNutrients() {
    final n = _nutrition!;
    return (n.fiber > 0) ||
           (n.cholesterol ?? 0) > 0 ||
           (n.sodium ?? 0) > 0 ||
           (n.potassium ?? 0) > 0 ||
           (n.calcium ?? 0) > 0 ||
           (n.vitaminC ?? 0) > 0;
  }

  Widget _buildDetailedNutrients() {
    final n = _nutrition!;
    final rows = <_NRow>[];

    void add(String name, double? val, String unit, Color color) {
      if (val != null && val > 0) rows.add(_NRow(name, val, unit, color));
    }

    add('Dietary Fiber',  n.fiber,        'g',  const Color(0xFF6BCB77));
    add('Cholesterol',    n.cholesterol,  'mg', const Color(0xFFFFD93D));
    add('Sodium',         n.sodium,       'mg', const Color(0xFFFF8C42));
    add('Potassium',      n.potassium,    'mg', const Color(0xFF3B9EFF));
    add('Calcium',        n.calcium,      'mg', const Color(0xFF4ECDC4));
    add('Vitamin C',      n.vitaminC,     'mg', const Color(0xFFFF6B6B));
    add('Vitamin A',      n.vitaminA,     'μg', const Color(0xFFFFAA00));
    add('Iron',           n.iron,         'mg', const Color(0xFFB06060));
    add('Magnesium',      n.magnesium,    'mg', const Color(0xFF8B5CF6));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DETAILED NUTRIENTS',
          style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: rows.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 4, height: 28,
                    decoration: BoxDecoration(
                      color: r.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(r.name,
                      style: AppTheme.bodyMD.copyWith(
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  Text(
                    '${r.val.toStringAsFixed(r.val < 10 ? 2 : 1)} ${r.unit}',
                    style: AppTheme.labelLG.copyWith(
                        color: AppTheme.textPrimary),
                  ),
                ]),
              ),
              if (i < rows.length - 1)
                Divider(height: 1, color: Colors.white.withOpacity(0.04),
                    indent: 32),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _NRow {
  final String name;
  final double val;
  final String unit;
  final Color  color;
  const _NRow(this.name, this.val, this.unit, this.color);
}
