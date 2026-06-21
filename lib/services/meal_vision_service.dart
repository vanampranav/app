import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/food_models.dart';
import 'package:flutter/foundation.dart';

class MealVisionService {
  static const String _baseUrl = 'https://elefit-app.onrender.com';

  /// Analyzes a meal image and returns nutritional information.
  /// This calls the backend which is expected to use a Vision model (like Gemini)
  /// to identify the food and estimate portions/nutrients.
  Future<List<Map<String, dynamic>>> analyzeMealImage(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze-meal'));
      request.headers['X-API-Key'] = 'elefit_flutter_secure_key_2025';

      // Use bytes instead of path to avoid iOS permission issues during multi-process handoff
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'meal_image.jpg',
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data.containsKey('foods')) {
          return (data['foods'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        debugPrint('Meal Vision API error: ${response.statusCode} - ${response.body}');
        // Fallback to a mock response for testing if the endpoint is not yet ready
        return _getMockResponse();
      }
    } catch (e) {
      debugPrint('Meal Vision network error: $e');
      return _getMockResponse();
    }
  }

  /// Mock response for development when backend is not yet fully implemented
  List<Map<String, dynamic>> _getMockResponse() {
    return [
      {
        'foodName': 'Grilled Chicken Salad',
        'weight': 350.0,
        'nutrition': {
          'calories': 420.0,
          'protein': 35.0,
          'carbs': 12.0,
          'fat': 24.0,
          'fiber': 6.0,
          'sugar': 4.0,
          'sodium': 580.0,
        }
      }
    ];
  }
}
