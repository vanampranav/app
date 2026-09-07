class MealRecommendationOption {
  final String optionId;
  final String title;
  final List<String> foods;
  final String rationale;
  final int? estimatedCalories;
  final int? estimatedProtein;
  final int? estimatedCarbs;
  final int? estimatedFat;
  final double confidence;

  MealRecommendationOption({
    required this.optionId,
    required this.title,
    required this.foods,
    required this.rationale,
    this.estimatedCalories,
    this.estimatedProtein,
    this.estimatedCarbs,
    this.estimatedFat,
    required this.confidence,
  });

  factory MealRecommendationOption.fromJson(Map<String, dynamic> json) {
    final rawFoods = json['foods'] as List<dynamic>? ?? [];
    return MealRecommendationOption(
      optionId: json['optionId'] as String? ?? 'opt_1',
      title: json['title'] as String? ?? 'Meal Option',
      foods: rawFoods.map((e) => e.toString()).toList(),
      rationale: json['rationale'] as String? ?? '',
      estimatedCalories: (json['estimatedCalories'] as num?)?.toInt(),
      estimatedProtein: (json['estimatedProtein'] as num?)?.toInt(),
      estimatedCarbs: (json['estimatedCarbs'] as num?)?.toInt(),
      estimatedFat: (json['estimatedFat'] as num?)?.toInt(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
    );
  }

  Map<String, dynamic> toJson() => {
        'optionId': optionId,
        'title': title,
        'foods': foods,
        'rationale': rationale,
        if (estimatedCalories != null) 'estimatedCalories': estimatedCalories,
        if (estimatedProtein != null) 'estimatedProtein': estimatedProtein,
        if (estimatedCarbs != null) 'estimatedCarbs': estimatedCarbs,
        if (estimatedFat != null) 'estimatedFat': estimatedFat,
        'confidence': confidence,
      };
}

class MealRecommendationResponse {
  final String recommendationId;
  final String mealType;
  final List<MealRecommendationOption> options;

  MealRecommendationResponse({
    required this.recommendationId,
    required this.mealType,
    required this.options,
  });

  factory MealRecommendationResponse.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return MealRecommendationResponse(
      recommendationId: json['recommendationId'] as String? ??
          'rec_${DateTime.now().millisecondsSinceEpoch}',
      mealType: json['mealType'] as String? ?? 'dinner',
      options: rawOptions
          .map((e) => MealRecommendationOption.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'recommendationId': recommendationId,
        'mealType': mealType,
        'options': options.map((o) => o.toJson()).toList(),
      };
}

class RecommendationFeedback {
  final String feedbackId;
  final String? recommendationId;
  final String? optionId;
  final String action; // 'liked', 'disliked', 'refreshed', 'selected'
  final DateTime timestamp;

  RecommendationFeedback({
    required this.feedbackId,
    this.recommendationId,
    this.optionId,
    required this.action,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'feedbackId': feedbackId,
        'recommendationId': recommendationId,
        'optionId': optionId,
        'action': action,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}
