import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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
  static const String _baseUrl = 'https://elefit-app.onrender.com';

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
}
