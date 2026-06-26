import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_models.dart';
import '../config/secrets.dart';

/// Service for FatSecret API integration
/// Handles food search and nutrition calculation directly from Flutter
class NutritionService {
  // FatSecret API credentials
  static const String _consumerKey = Secrets.fatSecretConsumerKey;
  static const String _consumerSecret = Secrets.fatSecretConsumerSecret;
  
  // FatSecret API endpoints
  static const String _baseUrl = 'https://platform.fatsecret.com/rest/server.api';
  
  // Cache for recently searched foods
  final Map<String, FoodItem> _foodCache = {};
  
  /// Generate OAuth 1.0a signature for FatSecret API
  String _generateOAuthSignature(
    String method,
    String url,
    Map<String, String> params,
    String consumerSecret,
  ) {
    // Sort parameters alphabetically
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${Uri.encodeComponent(params[k]!)}').join('&');
    
    // Create signature base string
    final signatureBaseString = '${method.toUpperCase()}&${Uri.encodeComponent(url)}&${Uri.encodeComponent(paramString)}';
    
    // Create signing key (consumer secret + & + token secret, token secret is empty for 2-legged OAuth)
    final signingKey = '${Uri.encodeComponent(consumerSecret)}&';
    
    // Generate HMAC-SHA1 signature
    final hmac = Hmac(sha1, utf8.encode(signingKey));
    final digest = hmac.convert(utf8.encode(signatureBaseString));
    
    return base64.encode(digest.bytes);
  }
  
  /// Generate random nonce for OAuth
  String _generateNonce() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }
  
  /// Make authenticated request to FatSecret API
  Future<Map<String, dynamic>> _makeRequest(Map<String, String> methodParams) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _generateNonce();
    
    // OAuth parameters
    final oauthParams = {
      'oauth_consumer_key': _consumerKey,
      'oauth_signature_method': 'HMAC-SHA1',
      'oauth_timestamp': timestamp,
      'oauth_nonce': nonce,
      'oauth_version': '1.0',
      'format': 'json',
    };
    
    // Combine OAuth params with method-specific params
    final allParams = {...oauthParams, ...methodParams};
    
    // Generate signature
    final signature = _generateOAuthSignature('GET', _baseUrl, allParams, _consumerSecret);
    allParams['oauth_signature'] = signature;
    
    // Build URL with all parameters
    final uri = Uri.parse(_baseUrl).replace(queryParameters: allParams);
    
    try {
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('FatSecret API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Search for foods by query
  Future<List<FoodItem>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _makeRequest({
        'method': 'foods.search.v3',
        'search_expression': query,
        'max_results': '20',
        'include_food_images': '1',
      });

      // v3 uses foods_search.results.food (different from v1 foods.food)
      final foods = response['foods_search']?['results']?['food'];
      if (foods == null) return [];

      // Handle single result (FatSecret returns object instead of array)
      final foodList = foods is List ? foods : [foods];

      return foodList.map<FoodItem>((food) {
        double caloriesPer100g = 0;
        String servingSize = '100g';

        // foods.search.v3 returns STRUCTURED servings — prefer that over text.
        final servingsData = food['servings']?['serving'];
        if (servingsData != null) {
          final servings = servingsData is List ? servingsData : [servingsData];
          // Prefer a gram/ml metric serving so we can normalise to per-100.
          Map? chosen;
          for (final s in servings) {
            if (s is Map &&
                (s['metric_serving_unit'] == 'g' || s['metric_serving_unit'] == 'ml')) {
              chosen = s;
              break;
            }
          }
          chosen ??= servings.first is Map ? servings.first as Map : null;
          if (chosen != null) {
            final cal = double.tryParse(chosen['calories']?.toString() ?? '') ?? 0;
            final amt = double.tryParse(chosen['metric_serving_amount']?.toString() ?? '') ?? 0;
            final unit = (chosen['metric_serving_unit'] ?? '').toString();
            if (cal > 0 && amt > 0 && (unit == 'g' || unit == 'ml')) {
              caloriesPer100g = (cal / amt * 100);
              servingSize = '100$unit';
            } else if (cal > 0) {
              // Non-metric serving (e.g. branded "1 latte") — show per serving.
              caloriesPer100g = cal;
              servingSize = (chosen['serving_description'] ?? '1 serving').toString();
            }
          }
        }

        // Fallback: parse the description text only if structured data missing.
        if (caloriesPer100g == 0) {
          final description = food['food_description'] as String? ?? '';
          final calorieMatch =
              RegExp(r'Cal(?:ories)?:\s*([\d.,]+)', caseSensitive: false)
                  .firstMatch(description);
          if (calorieMatch != null) {
            final raw = (calorieMatch.group(1) ?? '0').replaceAll(',', '');
            caloriesPer100g = double.tryParse(raw) ?? 0;
          }
          final servingMatch = RegExp(r'Per\s+(.+?)\s*-').firstMatch(description);
          if (servingMatch != null) {
            servingSize = servingMatch.group(1) ?? servingSize;
          }
        }

        final foodItem = FoodItem(
          fdcId: food['food_id'].toString(),
          name: food['food_name'] ?? 'Unknown Food',
          caloriesPer100g: double.parse(caloriesPer100g.toStringAsFixed(0)),
          servingSize: servingSize,
        );

        _foodCache[foodItem.fdcId] = foodItem;
        return foodItem;
      }).toList();
    } catch (e) {
      debugPrint('Error searching food: $e');
      throw Exception('Failed to search food: $e');
    }
  }
  
  /// Get detailed food information by ID
  Future<Map<String, dynamic>> _getFoodDetails(String foodId) async {
    try {
      final response = await _makeRequest({
        'method': 'food.get.v4',
        'food_id': foodId,
      });
      
      return response['food'] ?? {};
    } catch (e) {
      debugPrint('Error getting food details: $e');
      throw Exception('Failed to get food details: $e');
    }
  }
  
  /// Returns all serving options for a food so the UI can let the user log by
  /// serving (e.g. "1 grande") + quantity, not just grams. Returns
  /// {foodName, servings: List<FoodServing>}.
  Future<Map<String, dynamic>> getFoodServings(String foodId) async {
    final food = await _getFoodDetails(foodId);
    final foodName = food['food_name'] ?? 'Unknown Food';
    final servingsData = food['servings']?['serving'];
    final raw = servingsData == null
        ? <dynamic>[]
        : (servingsData is List ? servingsData : [servingsData]);

    final servings = <FoodServing>[];
    for (final s in raw) {
      if (s is! Map) continue;
      double v(String k) => double.tryParse(s[k]?.toString() ?? '0') ?? 0;
      double? vn(String k) => s[k] == null ? null : double.tryParse(s[k].toString());
      servings.add(FoodServing(
        id: s['serving_id']?.toString() ?? '',
        description: (s['serving_description'] ?? 'serving').toString(),
        metricAmount: vn('metric_serving_amount'),
        metricUnit: s['metric_serving_unit']?.toString(),
        nutrition: NutritionData(
          calories: v('calories'),
          fat: v('fat'),
          carbs: v('carbohydrate'),
          protein: v('protein'),
          fiber: v('fiber'),
          sugar: v('sugar'),
          cholesterol: vn('cholesterol'),
          sodium: vn('sodium'),
          potassium: vn('potassium'),
          calcium: vn('calcium'),
          iron: vn('iron'),
          vitaminA: vn('vitamin_a'),
          vitaminC: vn('vitamin_c'),
        ),
      ));
    }
    return {'foodName': foodName, 'servings': servings};
  }

  /// Calculate nutrition for a specific food and weight
  Future<Map<String, dynamic>> calculateNutrition(String foodId, double weightGrams) async {
    try {
      final food = await _getFoodDetails(foodId);
      
      // Get food name
      final foodName = food['food_name'] ?? 'Unknown Food';
      
      // Get servings
      final servingsData = food['servings']?['serving'];
      if (servingsData == null) {
        throw Exception('No serving information available');
      }
      
      // Handle single serving (FatSecret returns object instead of array)
      final servings = servingsData is List ? servingsData : [servingsData];
      
      // Find best serving to use (preferably metric/grams)
      Map<String, dynamic>? selectedServing;
      for (final serving in servings) {
        if (serving['metric_serving_unit'] == 'g') {
          selectedServing = serving;
          break;
        }
      }
      selectedServing ??= servings.first;
      
      // Ensure we have a valid serving
      final serving = selectedServing!;
      
      // Calculate scale factor
      final metricAmount = double.tryParse(serving['metric_serving_amount']?.toString() ?? '100') ?? 100;
      final scaleFactor = weightGrams / metricAmount;
      
      // Extract and scale nutrients
      double getScaledValue(String key) {
        final value = double.tryParse(serving[key]?.toString() ?? '0') ?? 0;
        return double.parse((value * scaleFactor).toStringAsFixed(2));
      }
      
      final nutrition = NutritionData(
        calories: getScaledValue('calories'),
        fat: getScaledValue('fat'),
        carbs: getScaledValue('carbohydrate'),
        protein: getScaledValue('protein'),
        fiber: getScaledValue('fiber'),
        sugar: getScaledValue('sugar'),
        cholesterol: getScaledValue('cholesterol'),
        sodium: getScaledValue('sodium'),
        potassium: getScaledValue('potassium'),
        calcium: getScaledValue('calcium'),
        iron: getScaledValue('iron'),
        vitaminA: getScaledValue('vitamin_a'),
        vitaminC: getScaledValue('vitamin_c'),
      );
      
      return {
        'foodName': foodName,
        'weight': weightGrams,
        'nutrition': nutrition,
        'source': 'FatSecret',
      };
    } catch (e) {
      debugPrint('Error calculating nutrition: $e');
      throw Exception('Failed to calculate nutrition: $e');
    }
  }
  
  /// Autocomplete suggestions for a partial query (Premier feature)
  Future<List<String>> searchAutocomplete(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final response = await _makeRequest({
        'method': 'foods.autocomplete',
        'expression': query.trim(),
        'max_results': '6',
      });
      final suggestions = response['suggestions']?['suggestion'];
      if (suggestions == null) return [];
      if (suggestions is List) return suggestions.cast<String>();
      return [suggestions.toString()];
    } catch (e) {
      debugPrint('Autocomplete error: $e');
      return [];
    }
  }

  /// Look up a food by barcode (Premier feature)
  Future<FoodItem?> searchByBarcode(String barcode) async {
    try {
      final idResponse = await _makeRequest({
        'method': 'food.find_id_for_barcode',
        'barcode': barcode,
      });
      final foodId = idResponse['food_id']?['value']?.toString();
      if (foodId == null) return null;

      final detailResponse = await _makeRequest({
        'method': 'food.get.v4',
        'food_id': foodId,
      });
      final food = detailResponse['food'];
      if (food == null) return null;

      final servingsData = food['servings']?['serving'];
      final servings = servingsData is List ? servingsData : [servingsData];
      final serving = servings.firstWhere(
        (s) => s['metric_serving_unit'] == 'g',
        orElse: () => servings.first,
      );

      double calories = 0;
      String servingSize = '100g';
      if (serving != null) {
        calories = double.tryParse(serving['calories']?.toString() ?? '0') ?? 0;
        final amount = serving['metric_serving_amount']?.toString() ?? '100';
        final unit = serving['metric_serving_unit']?.toString() ?? 'g';
        servingSize = '$amount$unit';
        final metricAmount = double.tryParse(amount) ?? 100;
        if (metricAmount > 0) calories = calories / metricAmount * 100;
      }

      // Fetch product image from Open Food Facts (free, great coverage for barcodes)
      String? imageUrl = await _getOpenFoodFactsImage(barcode);

      final item = FoodItem(
        fdcId: foodId,
        name: food['food_name'] ?? 'Unknown Food',
        caloriesPer100g: calories,
        servingSize: servingSize,
        imageUrl: imageUrl,
      );
      _foodCache[item.fdcId] = item;
      return item;
    } catch (e) {
      debugPrint('Barcode search error: $e');
      return null;
    }
  }

  /// Fetch product image from Open Food Facts by barcode (free, no API key needed)
  Future<String?> _getOpenFoodFactsImage(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json?fields=image_front_small_url',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['status'] != 1) return null;
      final url = data['product']?['image_front_small_url'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Get recently used foods from local storage
  Future<List<FoodItem>> getRecentlyUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentJson = prefs.getString('recently_used_foods');
      
      if (recentJson == null) return [];
      
      final List<dynamic> recentList = jsonDecode(recentJson);
      return recentList.map((e) => FoodItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading recently used: $e');
      return [];
    }
  }
  
  /// Save food to recently used list
  Future<void> saveToRecentlyUsed(FoodItem food) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentJson = prefs.getString('recently_used_foods');
      
      List<Map<String, dynamic>> recentList = [];
      if (recentJson != null) {
        recentList = List<Map<String, dynamic>>.from(jsonDecode(recentJson));
      }
      
      // Remove if already exists (to move to top)
      recentList.removeWhere((item) => item['fdcId'] == food.fdcId);
      
      // Add to beginning
      recentList.insert(0, food.toJson());
      
      // Keep only last 20 items
      if (recentList.length > 20) {
        recentList = recentList.sublist(0, 20);
      }
      
      await prefs.setString('recently_used_foods', jsonEncode(recentList));
    } catch (e) {
      debugPrint('Error saving to recently used: $e');
    }
  }
  
  /// Clear the food cache
  void clearCache() {
    _foodCache.clear();
  }
}
