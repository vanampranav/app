import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/food_models.dart';

/// Backend Service for communicating with EleFit Firebase Cloud Functions
class BackendService {
  final FirebaseFunctions _functions;

  BackendService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Recursively normalizes Firebase Callable Maps and Lists to [Map<String, dynamic>]
  /// and [List<dynamic>] to avoid runtime '_Map<Object?, Object?>' type errors.
  dynamic _normalizeFirebaseValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(
          key.toString(),
          _normalizeFirebaseValue(val),
        ),
      );
    }
    if (value is List) {
      return value.map(_normalizeFirebaseValue).toList();
    }
    return value;
  }

  /// Calls the `helloEleFit` v2 callable function.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> helloEleFit() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('helloEleFit');
      final HttpsCallableResult result = await callable.call();

      final normalized = _normalizeFirebaseValue(result.data);
      if (normalized is Map<String, dynamic>) {
        return normalized;
      }
      return {'data': normalized};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in helloEleFit: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling helloEleFit: $e');
      rethrow;
    }
  }

  /// Calls the `interpretMeal` v2 Cloud Function to parse natural language text into structured meal intent.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> interpretMeal(
    String text, {
    String? suggestedMealType,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('interpretMeal');
      final Map<String, dynamic> payload = {
        'text': text,
        'localHour': DateTime.now().hour,
      };
      if (suggestedMealType != null && suggestedMealType.isNotEmpty) {
        payload['suggestedMealType'] = suggestedMealType;
      }

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final interpretation = normalized['interpretation'];
      if (interpretation is Map<String, dynamic>) {
        return interpretation;
      }
      return {'data': interpretation};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in interpretMeal: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling interpretMeal: $e');
      rethrow;
    }
  }

  /// Calls the `prepareMeal` v2 Cloud Function to orchestrate interpretation, search, and resolution into a MealProposal.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> prepareMeal(
    String text, {
    String? suggestedMealType,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('prepareMeal');
      final Map<String, dynamic> payload = {
        'text': text,
        'localHour': DateTime.now().hour,
      };
      if (suggestedMealType != null && suggestedMealType.isNotEmpty) {
        payload['suggestedMealType'] = suggestedMealType;
      }

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final proposal = normalized['proposal'];
      if (proposal is Map<String, dynamic>) {
        return proposal;
      }
      return {'data': proposal};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in prepareMeal: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling prepareMeal: $e');
      rethrow;
    }
  }

  /// Calls the `resolveMealClarification` Cloud Function to update an existing proposal item.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> resolveMealClarification({
    required Map<String, dynamic> proposal,
    required int itemIndex,
    required String answer,
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('resolveMealClarification');
      final Map<String, dynamic> payload = {
        'proposal': proposal,
        'itemIndex': itemIndex,
        'answer': answer,
        'localHour': DateTime.now().hour,
      };

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final updatedProposal = normalized['proposal'];
      if (updatedProposal is Map<String, dynamic>) {
        return updatedProposal;
      }
      return {'data': updatedProposal};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in resolveMealClarification: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling resolveMealClarification: $e');
      rethrow;
    }
  }

  /// Calls the `updateMealProposalContext` Cloud Function to update mealType context.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> updateMealProposalContext({
    required Map<String, dynamic> proposal,
    required String mealType,
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('updateMealProposalContext');
      final Map<String, dynamic> payload = {
        'proposal': proposal,
        'mealType': mealType,
      };

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final updatedProposal = normalized['proposal'];
      if (updatedProposal is Map<String, dynamic>) {
        return updatedProposal;
      }
      return {'data': updatedProposal};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in updateMealProposalContext: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling updateMealProposalContext: $e');
      rethrow;
    }
  }

  /// Calls the `getAskEleGuidance` Cloud Function to generate contextual guidance & recommendations.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> getAskEleGuidance({
    required String message,
    required Map<String, dynamic> todayContext,
    Map<String, dynamic>? recommendationContext,
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('getAskEleGuidance');
      final Map<String, dynamic> payload = {
        'message': message,
        'todayContext': todayContext,
      };
      if (recommendationContext != null) {
        payload['recommendationContext'] = recommendationContext;
      }

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      return normalized;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in getAskEleGuidance: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling getAskEleGuidance: $e');
      rethrow;
    }
  }

  /// Saves recommendation feedback (liked, disliked, refreshed, selected) to Firestore.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> saveRecommendationFeedback({
    required String action,
    String? recommendationId,
    String? optionId,
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('saveRecommendationFeedback');
      final Map<String, dynamic> payload = {
        'action': action,
        if (recommendationId != null) 'recommendationId': recommendationId,
        if (optionId != null) 'optionId': optionId,
      };

      final HttpsCallableResult result = await callable.call(payload);

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      return normalized;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in saveRecommendationFeedback: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling saveRecommendationFeedback: $e');
      rethrow;
    }
  }

  /// Calls the `searchFoods` v2 Cloud Function to query backend nutrition providers.
  /// Relies on Firebase Authentication context (request.auth).
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('searchFoods');
      final HttpsCallableResult result = await callable.call({
        'query': query,
        'page': 0,
        'maxResults': 10,
      });

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final rawFoods = normalized['foods'] as List<dynamic>? ?? [];

      return rawFoods.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in searchFoods: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling searchFoods: $e');
      rethrow;
    }
  }

  /// Calls the `getFoodDetails` v2 Cloud Function to fetch full details and serving options.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> getFoodDetails(String foodId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getFoodDetails');
      final HttpsCallableResult result = await callable.call({'foodId': foodId});

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final food = normalized['food'];
      if (food is Map<String, dynamic>) {
        return food;
      }
      return {'data': food};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in getFoodDetails: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling getFoodDetails: $e');
      rethrow;
    }
  }

  /// Calls the `resolveFood` v2 Cloud Function to calculate scaled nutrition for a specific serving.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> resolveFood({
    required String foodId,
    required String servingId,
    required double quantity,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('resolveFood');
      final HttpsCallableResult result = await callable.call({
        'foodId': foodId,
        'servingId': servingId,
        'quantity': quantity,
      });

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final food = normalized['food'];
      if (food is Map<String, dynamic>) {
        return food;
      }
      return {'data': food};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in resolveFood: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling resolveFood: $e');
      rethrow;
    }
  }

  /// Saves a [MealEntry] to the backend Firestore via the `saveMeal` Cloud Function.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> saveMeal(
    MealEntry entry, {
    String source = 'manual',
    String? nutritionSource,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('saveMeal');

      final String resolvedNutritionSource = nutritionSource ?? 'unknown';

      final payload = {
        'entryId': entry.id,
        'foodName': entry.foodName,
        'fdcId': entry.fdcId,
        'weight': entry.weight,
        'meal': entry.meal.toString().split('.').last,
        'timestamp': entry.timestamp.toUtc().toIso8601String(),
        'imageUrl': entry.imageUrl,
        'nutrition': entry.nutrition.toJson(),
        'source': source,
        'nutritionSource': resolvedNutritionSource,
      };

      final HttpsCallableResult result = await callable.call(payload);

      final normalized = _normalizeFirebaseValue(result.data);
      if (normalized is Map<String, dynamic>) {
        return normalized;
      }
      return {'data': normalized};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in saveMeal: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling saveMeal: $e');
      rethrow;
    }
  }

  /// Fetches saved [MealEntry] items for a specific local calendar date.
  /// Relies on Firebase Authentication context (request.auth).
  Future<List<MealEntry>> getMealsForDate(DateTime date) async {
    try {
      final String dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final int offsetMinutes = date.timeZoneOffset.inMinutes;

      final HttpsCallable callable = _functions.httpsCallable('getMealsForDate');
      final HttpsCallableResult result = await callable.call({
        'date': dateStr,
        'timezoneOffsetMinutes': offsetMinutes,
      });

      final normalized =
          _normalizeFirebaseValue(result.data) as Map<String, dynamic>;

      final rawEntries = normalized['entries'] as List<dynamic>? ?? [];

      return rawEntries.map((entry) {
        return MealEntry.fromJson(
          entry as Map<String, dynamic>,
        );
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in getMealsForDate: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling getMealsForDate: $e');
      rethrow;
    }
  }

  /// Calls the `saveMeal` v2 callable function with a hardcoded test payload.
  /// Relies on Firebase Authentication context (request.auth).
  Future<Map<String, dynamic>> saveTestMeal() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('saveMeal');
      final HttpsCallableResult result = await callable.call({
        "entryId": "test_meal_${DateTime.now().millisecondsSinceEpoch}",
        "foodName": "Test Idli",
        "fdcId": "test-001",
        "weight": 100,
        "meal": "lunch",
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "nutrition": {
          "calories": 150,
          "fat": 2,
          "carbs": 30,
          "protein": 5,
          "fiber": 2,
          "sugar": 1,
        },
        "source": "manual_test",
        "nutritionSource": "test",
      });

      final normalized = _normalizeFirebaseValue(result.data);
      if (normalized is Map<String, dynamic>) {
        return normalized;
      }
      return {'data': normalized};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException in saveMeal: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling saveMeal: $e');
      rethrow;
    }
  }
}
