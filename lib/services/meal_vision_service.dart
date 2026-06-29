import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/food_models.dart';
import '../utils/nutrition_validator.dart';
import 'nutrition_service.dart';

/// Calls the FastAPI `/analyze-meal` endpoint, which uses an OpenAI Vision
/// model to identify food in a photo and estimate weight + nutrition.
///
/// Backend response shape:
/// {
///   "foods": [
///     {"foodName": "Apple", "weight": 150,
///      "nutrition": {"calories":95,"protein":0.5,"carbs":25,"fat":0.3,
///                    "fiber":4,"sugar":19,"sodium":2}}
///   ]
/// }
class MealVisionService {
  static const String _baseUrl = 'https://yantraprise.com';

  // Shared secret the backend validates (X-API-Key). Keep in sync with the
  // backend's ELEFIT_API_KEY. Blocks casual direct abuse of the public endpoint.
  static const String _apiKey = 'elefit_flutter_secure_key_2025';

  // Render's free tier cold-starts (~30–60s) and the Vision call adds a few
  // seconds, so allow a generous timeout before giving up.
  static const Duration _timeout = Duration(seconds: 90);

  /// Analyzes a meal image and returns a list of identified foods, each as
  /// {foodName, weight, nutrition: {...}}. Throws on failure so the caller can
  /// show a real error instead of logging fabricated data.
  ///
  /// [userId] (Firebase UID) is sent as X-User-Id so the backend can apply a
  /// per-user daily quota; omit it to fall back to IP-based limiting only.
  Future<List<Map<String, dynamic>>> analyzeMealImage(File imageFile, {String? userId}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/analyze-meal'),
    );
    request.headers['X-API-Key'] = _apiKey;
    if (userId != null && userId.isNotEmpty) {
      request.headers['X-User-Id'] = userId;
    }
    // Upload as bytes (not a file path) to avoid iOS permission issues when the
    // image picker hands the file off across processes.
    final bytes = await imageFile.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: 'meal_image.jpg'),
    );

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 429) {
        throw Exception('Daily scan limit reached. Please try again later.');
      }
      if (response.statusCode != 200) {
        debugPrint('Meal Vision API error: ${response.statusCode} - ${response.body}');
        throw Exception('Server returned ${response.statusCode}. Please try again.');
      }

      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('foods')) {
        return (data['foods'] as List).cast<Map<String, dynamic>>();
      }
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('Meal Vision network error: $e');
      throw Exception('Could not reach the meal-analysis service. Check your connection and try again.');
    }
  }

  /// Upgrades vision results with verified FatSecret nutrition where possible.
  ///
  /// For each detected food we keep the AI's name + weight, then try to look the
  /// food up in FatSecret and replace the AI's *nutrition estimate* with verified
  /// data scaled to that weight. If FatSecret has no confident match (common for
  /// non-US / regional foods on the free tier) we keep the AI estimate — so we
  /// never end up worse than before.
  ///
  /// Each returned food gets a `source`: 'verified' (FatSecret) or 'estimate' (AI),
  /// and verified foods get the FatSecret `fdcId`.
  Future<List<Map<String, dynamic>>> enrichWithFatSecret(
    List<Map<String, dynamic>> visionFoods,
    NutritionService nutrition,
  ) async {
    return Future.wait(visionFoods.map((food) => _enrichOne(food, nutrition)));
  }

  Future<Map<String, dynamic>> _enrichOne(
    Map<String, dynamic> food,
    NutritionService nutrition,
  ) async {
    final name = (food['foodName'] ?? food['name'] ?? '').toString();
    final weight = (food['weight'] ?? 100.0).toDouble();
    food['source'] = 'estimate'; // default — AI estimate

    if (name.trim().isEmpty || weight <= 0) return food;

    try {
      final matches = await nutrition.searchFood(name);
      // Pick the first result whose name reasonably overlaps the AI's name.
      FoodItem? best;
      for (final m in matches) {
        if (_nameMatches(name, m.name)) {
          best = m;
          break;
        }
      }
      if (best == null) return food; // no confident match → keep AI estimate

      final calc = await nutrition.calculateNutrition(best.fdcId, weight);
      final fs = calc['nutrition'] as NutritionData?;
      if (fs == null) return food;

      // Full plausibility check (NOT just macro-consistency): a wrong FatSecret
      // match can be internally consistent yet physically impossible — e.g.
      // 5400 kcal / 300g = 1800 kcal/100g. The per-100g guard in validate()
      // catches that; on any warning we discard FatSecret and keep the AI estimate.
      final check = NutritionValidator.validate(fs, weight);
      if (!check.usable || check.hasWarning) return food;

      food['nutrition'] = fs.toJson();
      food['fdcId'] = best.fdcId;
      food['source'] = 'verified';
      return food;
    } catch (e) {
      debugPrint('MealVision: FatSecret enrich failed for "$name": $e');
      return food; // any failure → keep AI estimate
    }
  }

  /// True when at least half of the AI name's meaningful tokens appear in the
  /// FatSecret name — guards against fuzzy mismatches (e.g. "dosa" → "Dr Pepper").
  bool _nameMatches(String aiName, String fsName) {
    final a = _tokens(aiName);
    final b = _tokens(fsName);
    if (a.isEmpty || b.isEmpty) return false;
    final overlap = a.where(b.contains).length;
    return overlap / a.length >= 0.5;
  }

  Set<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(' ')
      .where((t) => t.length > 2)
      .toSet();
}
