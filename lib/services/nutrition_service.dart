import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_models.dart';

/// Service for FatSecret API integration
/// Handles food search and nutrition calculation directly from Flutter
class NutritionService {
  // FatSecret API credentials
  static const String _consumerKey = 'e34aca171b2345e4bc3ef171ce2dd8f1';
  static const String _consumerSecret = 'b096e2108d51498cb9c99792b52db841';
  
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
        'method': 'foods.search',
        'search_expression': query,
        'max_results': '20',
      });
      
      final foods = response['foods']?['food'];
      if (foods == null) return [];
      
      // Handle single result (FatSecret returns object instead of array)
      final foodList = foods is List ? foods : [foods];
      
      return foodList.map<FoodItem>((food) {
        // Parse calories from food_description
        double caloriesPer100g = 0;
        String servingSize = '100g';
        
        final description = food['food_description'] as String? ?? '';
        // Example: "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g"
        final calorieMatch = RegExp(r'Calories:\s*(\d+(?:\.\d+)?)\s*kcal').firstMatch(description);
        if (calorieMatch != null) {
          caloriesPer100g = double.tryParse(calorieMatch.group(1) ?? '0') ?? 0;
        }
        
        // Extract serving info
        final servingMatch = RegExp(r'Per\s+(.+?)\s*-').firstMatch(description);
        if (servingMatch != null) {
          servingSize = servingMatch.group(1) ?? '100g';
        }
        
        final foodItem = FoodItem(
          fdcId: food['food_id'].toString(),
          name: food['food_name'] ?? 'Unknown Food',
          caloriesPer100g: caloriesPer100g,
          servingSize: servingSize,
        );
        
        // Cache the food item
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
