import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_theme.dart';
import '../services/shopify_service.dart';
import '../services/health_service.dart';
import '../services/backend_service.dart';
import 'add_member_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailMarketing = false;
  String? _userEmail;
  bool _healthConnected = false;
  bool _healthLoading   = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    final email = await secureStorage.read(key: 'user_email');
    final healthConnected = await HealthService().isConnected;
    final lastSync = await HealthService().lastSyncTime;
    if (mounted) {
      setState(() {
        _userEmail = email;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _emailMarketing = prefs.getBool('email_marketing') ?? false;
        _healthConnected = healthConnected;
        _lastSyncTime = lastSync;
      });
    }
  }

  String get _platformName => defaultTargetPlatform == TargetPlatform.iOS
      ? 'Apple Health'
      : 'Health Connect';

  String _formatSyncTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _toggleHealthConnection() async {
    setState(() => _healthLoading = true);
    if (_healthConnected) {
      await HealthService().disconnect();
      setState(() { _healthConnected = false; _healthLoading = false; });
    } else {
      final granted = await HealthService().requestPermissions();
      final lastSync = await HealthService().lastSyncTime;
      setState(() {
        _healthConnected = granted;
        _lastSyncTime = lastSync;
        _healthLoading = false;
      });
      if (!granted && mounted) {
        _showHealthConnectionError();
      }
    }
  }

  void _showHealthConnectionError() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Could not connect to $_platformName'),
        content: Text(isIos
            ? 'Go to Settings > Privacy & Security > Health > EleFit and enable all permissions.'
            : 'Make sure Health Connect is installed and grant EleFit access inside the Health Connect app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await HealthService().openHealthApp();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lime),
            child: Text(isIos ? 'Open Settings' : 'Open Health Connect'),
          ),
        ],
      ),
    );
  }

  Widget _syncChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.lime.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.lime.withOpacity(0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.green[700],
                fontWeight: FontWeight.w500)),
      );

  Future<void> _recheckHealthConnection() async {
    setState(() => _healthLoading = true);
    final connected = await HealthService().checkPermissions();
    final lastSync  = await HealthService().lastSyncTime;
    if (mounted) {
      setState(() {
        _healthConnected = connected;
        _lastSyncTime    = lastSync;
        _healthLoading   = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('email_marketing', _emailMarketing);
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Your profile information'),
            const Text('• Order history'),
            const Text('• Saved addresses'),
            const Text('• Wishlist items'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account deletion may take up to 30 days to complete.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No account found to delete'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Note: Shopify doesn't have a direct customer deletion API
      // This is a placeholder for the deletion request
      // In a real app, you would:
      // 1. Call your backend API to initiate deletion
      // 2. Your backend would handle the Shopify customer deletion
      // 3. Or redirect to a web page where users can request deletion

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (!mounted) return;

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion request submitted. You will receive a confirmation email at $_userEmail within 24 hours.',
            style: TextStyle(fontFamily: "Helvetica", ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate back to login
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit deletion request. Please try again or contact support.',
            style: TextStyle(fontFamily: "Helvetica", ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testBackend() async {
    try {
      final result = await BackendService().helloEleFit();
      debugPrint('helloEleFit response: $result');
      if (!mounted) return;
      final uid = result['uid'] ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend connected: $uid'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('helloEleFit error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Unauthenticated or server error'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveTestMeal() async {
    try {
      final result = await BackendService().saveTestMeal();
      debugPrint('saveTestMeal response: $result');
      if (!mounted) return;
      final docId = result['id'] ?? result['data']?['id'] ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test meal saved: $docId'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('saveTestMeal error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Failed to save test meal'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTodayMeals() async {
    try {
      final entries = await BackendService().getMealsForDate(DateTime.now());
      debugPrint('getMealsForDate loaded ${entries.length} entries:');
      for (final e in entries) {
        debugPrint('  - ${e.foodName} (${e.meal}) | ${e.weight}g | ${e.nutrition.calories} kcal');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${entries.length} meals from backend'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('getMealsForDate error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Failed to load meals'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testBackendFoodSearch() async {
    try {
      final foods = await BackendService().searchFoods('idli');
      debugPrint('searchFoods returned ${foods.length} results:');
      for (final item in foods) {
        debugPrint('  - foodId: ${item['foodId']}');
        debugPrint('    name: ${item['name']}');
        debugPrint('    brandName: ${item['brandName']}');
        debugPrint('    description: ${item['description']}');
        debugPrint('    caloriesPer100g: ${item['caloriesPer100g']}');
        debugPrint('    defaultServing: ${item['defaultServing']}');
        debugPrint('    provider: ${item['provider']}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend search returned ${foods.length} foods'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('searchFoods error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Food search failed'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testFoodDetails() async {
    try {
      final food = await BackendService().getFoodDetails('5702429');
      final servings = food['servings'] as List<dynamic>? ?? [];
      debugPrint('getFoodDetails returned:');
      debugPrint('  foodId: ${food['foodId']}');
      debugPrint('  name: ${food['name']}');
      debugPrint('  brandName: ${food['brandName']}');
      debugPrint('  provider: ${food['provider']}');
      debugPrint('  number of servings: ${servings.length}');

      for (final s in servings) {
        if (s is Map<String, dynamic>) {
          final n = s['nutrition'] as Map<String, dynamic>? ?? {};
          debugPrint('    - servingId: ${s['servingId']} | description: ${s['description']} | '
              'metricAmount: ${s['metricAmount']} | metricUnit: ${s['metricUnit']} | '
              'calories: ${n['calories']} | protein: ${n['protein']} | carbs: ${n['carbs']} | fat: ${n['fat']}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${servings.length} serving options'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('getFoodDetails error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Food details failed'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testResolveFood() async {
    try {
      final food = await BackendService().resolveFood(
        foodId: '5702429',
        servingId: '5537175',
        quantity: 4.0,
      );

      final String name = food['name'] ?? 'Unknown';
      final String servingDesc = food['servingDescription'] ?? '';
      final double qty = (food['quantity'] ?? 0.0).toDouble();
      final num? weightGrams = food['weightGrams'];
      final Map<String, dynamic> n =
          food['nutrition'] as Map<String, dynamic>? ?? {};

      debugPrint('resolveFood response:');
      debugPrint('  full object: $food');
      debugPrint('  foodId: ${food['foodId']}');
      debugPrint('  name: $name');
      debugPrint('  servingId: ${food['servingId']}');
      debugPrint('  servingDescription: $servingDesc');
      debugPrint('  quantity: $qty');
      debugPrint('  weightGrams: $weightGrams');
      debugPrint('  calories: ${n['calories']}');
      debugPrint('  protein: ${n['protein']}');
      debugPrint('  carbs: ${n['carbs']}');
      debugPrint('  fat: ${n['fat']}');

      if (!mounted) return;
      final cal = n['calories'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resolved ${qty.toStringAsFixed(0)} × $name = $cal kcal'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('resolveFood error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Food resolution failed'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testInterpretMeal() async {
    try {
      const String sampleInput = "I had 4 idlis for lunch";
      final interpretation = await BackendService().interpretMeal(sampleInput);

      final foods = interpretation['foods'] as List<dynamic>? ?? [];
      final String? mealType = interpretation['mealType'];
      final String mealTypeSource = interpretation['mealTypeSource'] ?? 'unknown';
      final double confidence = (interpretation['confidence'] ?? 0.0).toDouble();
      final bool needsClarification = interpretation['needsClarification'] ?? false;
      final String? clarificationQuestion = interpretation['clarificationQuestion'];

      debugPrint('interpretMeal response for "$sampleInput":');
      debugPrint('  mealType: $mealType ($mealTypeSource)');
      debugPrint('  confidence: $confidence');
      debugPrint('  needsClarification: $needsClarification');
      debugPrint('  clarificationQuestion: $clarificationQuestion');
      debugPrint('  foods (${foods.length}):');

      String summaryFoodText = 'no food';
      for (final f in foods) {
        if (f is Map<String, dynamic>) {
          final name = f['name'] ?? 'unknown';
          final qty = f['quantity'];
          final unit = f['unit'];
          final mods = f['modifiers'] as List<dynamic>? ?? [];
          summaryFoodText = '${qty ?? ''} × $name'.trim();
          debugPrint('    - name: "$name" | quantity: $qty | unit: "$unit" | modifiers: $mods');
        }
      }

      if (!mounted) return;
      final String snackText = 'Understood: $summaryFoodText • ${mealType ?? 'unspecified'}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackText),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('interpretMeal error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Meal interpretation failed'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testPrepareMeal() async {
    try {
      const String sampleInput = "I had 4 idlis for lunch";
      final proposal = await BackendService().prepareMeal(sampleInput);

      final String originalText = proposal['originalText'] ?? sampleInput;
      final String? mealType = proposal['mealType'];
      final String mealTypeSource = proposal['mealTypeSource'] ?? 'unknown';
      final double interpConf = (proposal['interpretationConfidence'] ?? 0.0).toDouble();
      final bool readyToLog = proposal['readyToLog'] ?? false;
      final bool needsClarification = proposal['needsClarification'] ?? false;
      final String? clarificationQuestion = proposal['clarificationQuestion'];
      final items = proposal['items'] as List<dynamic>? ?? [];

      debugPrint('prepareMeal response for "$originalText":');
      debugPrint('  mealType: $mealType ($mealTypeSource)');
      debugPrint('  interpretationConfidence: $interpConf');
      debugPrint('  readyToLog: $readyToLog');
      debugPrint('  needsClarification: $needsClarification');
      debugPrint('  clarificationQuestion: $clarificationQuestion');
      debugPrint('  items (${items.length}):');

      num calories = 0;
      String matchedFoodName = 'Idli';

      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final String interpName = item['interpretedName'] ?? '';
          final String? foodId = item['matchedFoodId'];
          final String? foodName = item['matchedFoodName'];
          final String? brandName = item['brandName'];
          final num? reqQty = item['requestedQuantity'];
          final String? reqUnit = item['requestedUnit'];
          final String? servingId = item['matchedServingId'];
          final String? servingDesc = item['matchedServingDescription'];
          final num? resolvedQty = item['resolvedQuantity'];
          final num? weightGrams = item['weightGrams'];
          final double matchConf = (item['matchConfidence'] ?? 0.0).toDouble();
          final String status = item['status'] ?? 'unknown';
          final Map<String, dynamic>? nutrition =
              item['nutrition'] as Map<String, dynamic>?;

          if (foodName != null) {
            matchedFoodName = foodName;
          }
          if (nutrition != null && nutrition['calories'] != null) {
            calories = nutrition['calories'];
          }

          debugPrint('    - interpretedName: "$interpName"');
          debugPrint('      matchedFoodId: $foodId');
          debugPrint('      matchedFoodName: $foodName');
          debugPrint('      brandName: $brandName');
          debugPrint('      requestedQuantity: $reqQty');
          debugPrint('      requestedUnit: $reqUnit');
          debugPrint('      matchedServingId: $servingId');
          debugPrint('      matchedServingDescription: $servingDesc');
          debugPrint('      resolvedQuantity: $resolvedQty');
          debugPrint('      weightGrams: $weightGrams');
          debugPrint('      matchConfidence: $matchConf');
          debugPrint('      status: $status');
          debugPrint('      nutrition: $nutrition');
        }
      }

      if (!mounted) return;
      final String snackText =
          'Prepared: 4 × $matchedFoodName • $calories kcal';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackText),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('prepareMeal error: $e');
      if (!mounted) return;
      String errorMsg = e.toString();
      if (e is FirebaseFunctionsException) {
        errorMsg = '[${e.code}] ${e.message ?? 'Meal preparation failed'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.bg,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Members ──────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Members',
                      style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage profiles for body composition tracking.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_outline_rounded,
                          color: AppTheme.purple, size: 22),
                    ),
                    title: const Text('Manage Members'),
                    subtitle: const Text('Add or edit scale profiles'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textTertiary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddMemberScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Connected Apps ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connected Apps',
                      style: const TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Sync your health data automatically.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // ── Health platform tile ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _healthConnected
                          ? AppTheme.lime.withOpacity(0.06)
                          : AppTheme.surface3.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _healthConnected
                            ? AppTheme.lime.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: _healthConnected
                                    ? AppTheme.lime.withOpacity(0.15)
                                    : Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                defaultTargetPlatform == TargetPlatform.iOS
                                    ? Icons.favorite_rounded
                                    : Icons.monitor_heart_outlined,
                                color: _healthConnected
                                    ? AppTheme.lime
                                    : Colors.grey[400],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _platformName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7, height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _healthConnected
                                              ? Colors.green
                                              : Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _healthConnected
                                            ? 'Connected'
                                            : 'Not connected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _healthConnected
                                              ? Colors.green[700]
                                              : Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_healthLoading)
                              const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: AppTheme.lime, strokeWidth: 2),
                              )
                            else
                              TextButton(
                                onPressed: _toggleHealthConnection,
                                style: TextButton.styleFrom(
                                  foregroundColor: _healthConnected
                                      ? Colors.red[400]
                                      : AppTheme.lime,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _healthConnected ? 'Disconnect' : 'Connect',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                          ],
                        ),

                        // ── Connected details ─────────────────────────────
                        if (_healthConnected) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Last sync row
                          Row(
                            children: [
                              Icon(Icons.sync_rounded,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 6),
                              Text(
                                _lastSyncTime != null
                                    ? 'Last synced ${_formatSyncTime(_lastSyncTime!)}'
                                    : 'Not yet synced — connect your scale or log a meal',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // What's syncing
                          Text('Syncing:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _syncChip('Weight & Body Fat'),
                              _syncChip('Steps'),
                              _syncChip('Heart Rate'),
                              _syncChip('Sleep'),
                              _syncChip('Nutrition'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _recheckHealthConnection,
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 16),
                                  label: const Text('Re-check',
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.lime,
                                    side: BorderSide(
                                        color: AppTheme.lime.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      HealthService().openHealthApp(),
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 16),
                                  label: Text(
                                    defaultTargetPlatform ==
                                            TargetPlatform.iOS
                                        ? 'Apple Health'
                                        : 'Health Connect',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textSecondary,
                                    side: BorderSide(
                                        color: Colors.grey.withOpacity(0.3)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notifications Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive notifications about orders and promotions'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Email Marketing'),
                    subtitle: const Text('Receive promotional emails and newsletters'),
                    value: _emailMarketing,
                    onChanged: (value) {
                      setState(() {
                        _emailMarketing = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Privacy Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & Data',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to privacy policy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy Policy - Coming Soon'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to terms of service
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terms of Service - Coming Soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Account Management Section
          if (_userEmail != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Management',
                      style: TextStyle(fontFamily: "Helvetica", 
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red.shade600),
                      title: Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      subtitle: const Text('Permanently delete your account and all data'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // TEMPORARY: Developer Test Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Developer Options',
                    style: TextStyle(
                      fontFamily: "Helvetica",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testBackend,
                    icon: const Icon(Icons.cloud_done_rounded),
                    label: const Text('Test EleFit Backend'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lime,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saveTestMeal,
                    icon: const Icon(Icons.restaurant_rounded),
                    label: const Text('Save Test Meal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface3,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadTodayMeals,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text("Load Today's Meals"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testBackendFoodSearch,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Test Backend Food Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface2,
                      foregroundColor: AppTheme.lime,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testFoodDetails,
                    icon: const Icon(Icons.fastfood_rounded),
                    label: const Text('Test Food Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface2,
                      foregroundColor: AppTheme.lime,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testResolveFood,
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('Test Resolve Food'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface2,
                      foregroundColor: AppTheme.lime,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testInterpretMeal,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Test Interpret Meal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface2,
                      foregroundColor: AppTheme.lime,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _testPrepareMeal,
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('Test Prepare Meal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface2,
                      foregroundColor: AppTheme.lime,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Information',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    trailing: Text('1.0.0'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Report a Bug'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bug reporting - Coming Soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
