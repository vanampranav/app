import 'package:flutter/foundation.dart';
import 'food_models.dart';

class FoodResolutionOption {
  final String optionId;
  final String label;
  final String providerFoodId;
  final String semanticFoodName;
  final String? brandName;

  FoodResolutionOption({
    required this.optionId,
    required this.label,
    required this.providerFoodId,
    required this.semanticFoodName,
    this.brandName,
  });

  factory FoodResolutionOption.fromJson(Map<String, dynamic> json) {
    return FoodResolutionOption(
      optionId: json['optionId'] as String? ?? 'opt_1',
      label: json['label'] as String? ?? 'Option',
      providerFoodId: json['providerFoodId'] as String? ?? '',
      semanticFoodName: json['semanticFoodName'] as String? ?? '',
      brandName: json['brandName'] as String?,
    );
  }
}

class MealProposalItem {
  final String? itemId;
  final String interpretedName;
  final String? matchedFoodId;
  final String? matchedFoodName;
  final String? brandName;
  final double? requestedQuantity;
  final String? requestedUnit;
  final String? matchedServingId;
  final String? matchedServingDescription;
  final double? resolvedQuantity;
  final double? weightGrams;
  final NutritionData? nutrition;
  final double matchConfidence;
  final String status;
  final String? clarificationQuestion;
  final List<FoodResolutionOption>? resolutionOptions;

  bool get isResolved => status == 'resolved';

  MealProposalItem({
    this.itemId,
    required this.interpretedName,
    this.matchedFoodId,
    this.matchedFoodName,
    this.brandName,
    this.requestedQuantity,
    this.requestedUnit,
    this.matchedServingId,
    this.matchedServingDescription,
    this.resolvedQuantity,
    this.weightGrams,
    this.nutrition,
    required this.matchConfidence,
    required this.status,
    this.clarificationQuestion,
    this.resolutionOptions,
  });

  factory MealProposalItem.fromJson(Map<String, dynamic> json) {
    NutritionData? nutr;
    if (json['nutrition'] is Map<String, dynamic>) {
      nutr = NutritionData.fromJson(
        Map<String, dynamic>.from(json['nutrition'] as Map),
      );
    }

    List<FoodResolutionOption>? opts;
    if (json['resolutionOptions'] is List) {
      opts = (json['resolutionOptions'] as List)
          .map((e) => FoodResolutionOption.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return MealProposalItem(
      itemId: json['itemId'] as String?,
      interpretedName: json['interpretedName'] as String? ?? 'Unknown Food',
      matchedFoodId: json['matchedFoodId'] as String?,
      matchedFoodName: json['matchedFoodName'] as String?,
      brandName: json['brandName'] as String?,
      requestedQuantity: (json['requestedQuantity'] as num?)?.toDouble(),
      requestedUnit: json['requestedUnit'] as String?,
      matchedServingId: json['matchedServingId'] as String?,
      matchedServingDescription: json['matchedServingDescription'] as String?,
      resolvedQuantity: (json['resolvedQuantity'] as num?)?.toDouble(),
      weightGrams: (json['weightGrams'] as num?)?.toDouble(),
      nutrition: nutr,
      matchConfidence: (json['matchConfidence'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'needs_food_match',
      clarificationQuestion: json['clarificationQuestion'] as String?,
      resolutionOptions: opts,
    );
  }
}

class MealProposal {
  final String originalText;
  final String? mealType;
  final String mealTypeSource;
  final double interpretationConfidence;
  final List<MealProposalItem> items;
  final bool readyToLog;
  final bool needsClarification;
  final String? clarificationQuestion;
  final int resolvedItemCount;
  final int unresolvedItemCount;
  final NutritionData? resolvedNutritionTotal;

  MealProposal({
    required this.originalText,
    this.mealType,
    required this.mealTypeSource,
    required this.interpretationConfidence,
    required this.items,
    required this.readyToLog,
    required this.needsClarification,
    this.clarificationQuestion,
    required this.resolvedItemCount,
    required this.unresolvedItemCount,
    this.resolvedNutritionTotal,
  });

  factory MealProposal.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) =>
            MealProposalItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    debugPrint('[FLUTTER DIAGNOSTIC 3] Inside MealProposal.fromJson():');
    debugPrint('  - rawItems runtimeType: ${json['items']?.runtimeType}');
    debugPrint('  - rawItems.length: ${rawItems.length}');
    debugPrint('  - resulting itemsList.length: ${itemsList.length}');
    debugPrint(
        '  - resulting interpretedName values: ${itemsList.map((i) => i.interpretedName).toList()}');

    NutritionData? totalNutr;
    if (json['resolvedNutritionTotal'] is Map<String, dynamic>) {
      totalNutr = NutritionData.fromJson(
        Map<String, dynamic>.from(json['resolvedNutritionTotal'] as Map),
      );
    }

    bool readyToLog = json['readyToLog'] as bool? ?? false;

    // Safety invariant check on client
    if (readyToLog) {
      for (final item in itemsList) {
        if (item.isResolved) {
          final wg = item.weightGrams;
          if (wg == null || wg <= 0) {
            readyToLog = false;
            break;
          }
          final c = item.nutrition?.calories ?? 0;
          final p = item.nutrition?.protein ?? 0;
          final carbs = item.nutrition?.carbs ?? 0;
          final f = item.nutrition?.fat ?? 0;
          if (c < 0 || p < 0 || carbs < 0 || f < 0 || c > 3500) {
            readyToLog = false;
            break;
          }
          if (c / wg > 10.0) {
            readyToLog = false;
            break;
          }
        }
      }
      if (totalNutr != null) {
        final totalCal = totalNutr.calories ?? 0;
        final totalP = totalNutr.protein ?? 0;
        if (totalCal > 4000 || totalP > 350 || totalCal < 0 || totalP < 0) {
          readyToLog = false;
        }
      }
    }

    return MealProposal(
      originalText: json['originalText'] as String? ?? '',
      mealType: json['mealType'] as String?,
      mealTypeSource: json['mealTypeSource'] as String? ?? 'unknown',
      interpretationConfidence:
          (json['interpretationConfidence'] as num?)?.toDouble() ?? 0.0,
      items: itemsList,
      readyToLog: readyToLog,
      needsClarification: json['needsClarification'] as bool? ?? false,
      clarificationQuestion: json['clarificationQuestion'] as String?,
      resolvedItemCount: (json['resolvedItemCount'] as num?)?.toInt() ?? 0,
      unresolvedItemCount: (json['unresolvedItemCount'] as num?)?.toInt() ?? 0,
      resolvedNutritionTotal: totalNutr,
    );
  }
}
