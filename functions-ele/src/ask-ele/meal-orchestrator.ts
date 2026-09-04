import {AiProvider} from "../ai/ai-provider";
import {NutritionProvider} from "../nutrition/nutrition-provider";
import {FoodSearchResult, FoodServingResult} from "../nutrition/types";
import {
  MealProposal,
  MealProposalItem,
  PrepareMealInput,
} from "./types";

/**
 * Normalizes a string by trimming, lowercasing, and collapsing spaces.
 *
 * @param {string} str - Raw input string.
 * @return {string} Normalized string.
 */
function normalizeStr(str: string): string {
  return str.toLowerCase().trim().replace(/\s+/g, " ");
}

/**
 * Normalizes food unit aliases to standard unit categories.
 *
 * @param {string | null} unit - Raw unit string or null.
 * @return {string | null} Standardized unit string or null.
 */
function normalizeUnit(unit: string | null): string | null {
  if (!unit) {
    return null;
  }
  const u = normalizeStr(unit);
  if (["piece", "pieces", "pc", "pcs", "idli", "idlis"].includes(u)) {
    return "piece";
  }
  if (["cup", "cups"].includes(u)) {
    return "cup";
  }
  if (["bowl", "bowls"].includes(u)) {
    return "bowl";
  }
  if (["g", "gram", "grams"].includes(u)) {
    return "g";
  }
  if (["serving", "servings"].includes(u)) {
    return "serving";
  }
  return u;
}

/**
 * Scores a candidate search result against an interpreted food name.
 *
 * @param {string} interpretedName - Name from AI interpretation.
 * @param {FoodSearchResult} candidate - Candidate search result item.
 * @return {number} Deterministic match confidence score (0.0 to 1.0).
 */
function scoreFoodMatch(
  interpretedName: string,
  candidate: FoodSearchResult
): number {
  const normInterpreted = normalizeStr(interpretedName);
  const normCandidate = normalizeStr(candidate.name);

  if (normCandidate === normInterpreted && !candidate.brandName) {
    return 1.0;
  }
  if (normCandidate === normInterpreted) {
    return 0.95;
  }
  if (
    normCandidate.includes(normInterpreted) ||
    normInterpreted.includes(normCandidate)
  ) {
    return candidate.brandName ? 0.8 : 0.85;
  }
  return 0.0;
}

/**
 * Checks whether a serving option explicitly matches a normalized unit.
 *
 * @param {FoodServingResult} serving - Serving object to check.
 * @param {string} normReqUnit - Normalized requested unit string.
 * @return {boolean} True if serving matches unit deterministically.
 */
function isUnitMatch(
  serving: FoodServingResult,
  normReqUnit: string
): boolean {
  const normDesc = normalizeStr(serving.description);
  const normMetric = serving.metricUnit ?
    normalizeStr(serving.metricUnit) :
    "";

  if (normReqUnit === "g") {
    return normMetric === "g";
  }

  if (normReqUnit === "piece") {
    return (
      /\b1?\s*piece\b/i.test(normDesc) ||
      /\b1?\s*pc\b/i.test(normDesc)
    );
  }

  if (normReqUnit === "cup") {
    return /\b1?\s*cup\b/i.test(normDesc);
  }

  if (normReqUnit === "bowl") {
    return /\b1?\s*bowl\b/i.test(normDesc);
  }

  if (normReqUnit === "serving") {
    return /\b1?\s*serving\b/i.test(normDesc);
  }

  return (
    normDesc.includes(normReqUnit) ||
    normMetric === normReqUnit
  );
}

/**
 * Finds the best serving option matching a requested unit safely.
 *
 * @param {string | null} requestedUnit - Unit requested in user text.
 * @param {FoodServingResult[]} servings - Available food servings.
 * @return {FoodServingResult | null} Matching serving or null.
 */
function findBestServing(
  requestedUnit: string | null,
  servings: FoodServingResult[]
): FoodServingResult | null {
  const normReqUnit = normalizeUnit(requestedUnit);
  if (!normReqUnit) {
    return null;
  }

  for (const s of servings) {
    if (isUnitMatch(s, normReqUnit)) {
      return s;
    }
  }

  return null;
}

/**
 * Orchestrator class combining AI meal interpretation with deterministic
 * nutrition database resolution to create non-persisted MealProposals.
 */
export class MealOrchestrator {
  /**
   * Prepares a non-persisted MealProposal for user review.
   *
   * @param {PrepareMealInput} input - Text and context parameters.
   * @param {AiProvider} aiProvider - Active AI provider instance.
   * @param {NutritionProvider} nutritionProvider - Active nutrition provider.
   * @return {Promise<MealProposal>} Standardized MealProposal object.
   */
  static async prepareMeal(
    input: PrepareMealInput,
    aiProvider: AiProvider,
    nutritionProvider: NutritionProvider
  ): Promise<MealProposal> {
    const interpretation = await aiProvider.interpretMeal({
      text: input.text,
      context: {
        localHour: input.localHour,
        suggestedMealType: input.suggestedMealType,
      },
    });

    const mealType = interpretation.mealType;
    const mealTypeSource = interpretation.mealTypeSource;
    const interpretationConfidence = interpretation.confidence;

    // Multi-food handling for v0.1
    if (interpretation.foods.length > 1) {
      const items: MealProposalItem[] = interpretation.foods.map((f) => ({
        interpretedName: f.name,
        matchedFoodId: null,
        matchedFoodName: null,
        brandName: null,
        requestedQuantity: f.quantity,
        requestedUnit: f.unit,
        matchedServingId: null,
        matchedServingDescription: null,
        resolvedQuantity: null,
        weightGrams: null,
        nutrition: null,
        matchConfidence: 0.0,
        status: "needs_food_match",
      }));

      return {
        originalText: input.text,
        mealType,
        mealTypeSource,
        interpretationConfidence,
        items,
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion:
          "Multi-item logging is not supported in this version. " +
          "Please log one food at a time.",
      };
    }

    if (interpretation.foods.length === 0) {
      return {
        originalText: input.text,
        mealType,
        mealTypeSource,
        interpretationConfidence,
        items: [],
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion:
          interpretation.clarificationQuestion ||
          "What did you have?",
      };
    }

    const food0 = interpretation.foods[0];
    const interpretedName = food0.name;
    const requestedQuantity = food0.quantity;
    const requestedUnit = food0.unit;

    // 1. Search for matching food
    const searchResults = await nutritionProvider.searchFoods(
      interpretedName,
      {maxResults: 10}
    );

    let bestCandidate: FoodSearchResult | null = null;
    let bestScore = 0.0;

    for (const candidate of searchResults) {
      const score = scoreFoodMatch(interpretedName, candidate);
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    if (!bestCandidate || bestScore < 0.85) {
      const item: MealProposalItem = {
        interpretedName,
        matchedFoodId: null,
        matchedFoodName: null,
        brandName: null,
        requestedQuantity,
        requestedUnit,
        matchedServingId: null,
        matchedServingDescription: null,
        resolvedQuantity: null,
        weightGrams: null,
        nutrition: null,
        matchConfidence: bestScore,
        status: "needs_food_match",
      };

      return {
        originalText: input.text,
        mealType,
        mealTypeSource,
        interpretationConfidence,
        items: [item],
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion: `Which ${interpretedName} did you have?`,
      };
    }

    const matchedFoodId = bestCandidate.foodId;
    const matchedFoodName = bestCandidate.name;
    const brandName = bestCandidate.brandName || null;

    // 2. Fetch food details & match serving
    const details = await nutritionProvider.getFoodDetails(matchedFoodId);
    const matchedServing = findBestServing(requestedUnit, details.servings);

    if (!matchedServing) {
      const item: MealProposalItem = {
        interpretedName,
        matchedFoodId,
        matchedFoodName,
        brandName,
        requestedQuantity,
        requestedUnit,
        matchedServingId: null,
        matchedServingDescription: null,
        resolvedQuantity: null,
        weightGrams: null,
        nutrition: null,
        matchConfidence: bestScore,
        status: "needs_serving",
      };

      return {
        originalText: input.text,
        mealType,
        mealTypeSource,
        interpretationConfidence,
        items: [item],
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion:
          `Which serving size of ${matchedFoodName} did you have?`,
      };
    }

    // 3. Check quantity
    if (requestedQuantity === null || requestedQuantity <= 0) {
      const item: MealProposalItem = {
        interpretedName,
        matchedFoodId,
        matchedFoodName,
        brandName,
        requestedQuantity: null,
        requestedUnit,
        matchedServingId: matchedServing.servingId,
        matchedServingDescription: matchedServing.description,
        resolvedQuantity: null,
        weightGrams: null,
        nutrition: null,
        matchConfidence: bestScore,
        status: "needs_quantity",
      };

      return {
        originalText: input.text,
        mealType,
        mealTypeSource,
        interpretationConfidence,
        items: [item],
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion:
          `How many ${interpretedName}s did you have?`,
      };
    }

    // 4. Resolve food with provider scaling
    const resolved = await nutritionProvider.resolveFood(
      matchedFoodId,
      matchedServing.servingId,
      requestedQuantity
    );

    const item: MealProposalItem = {
      interpretedName,
      matchedFoodId,
      matchedFoodName,
      brandName,
      requestedQuantity,
      requestedUnit,
      matchedServingId: matchedServing.servingId,
      matchedServingDescription: matchedServing.description,
      resolvedQuantity: requestedQuantity,
      weightGrams: resolved.weightGrams ?? null,
      nutrition: resolved.nutrition,
      matchConfidence: bestScore,
      status: "resolved",
    };

    let needsClarification = interpretation.needsClarification;
    let clarificationQuestion = needsClarification ?
      interpretation.clarificationQuestion :
      null;

    if (
      item.status === "resolved" &&
      mealType === null &&
      !needsClarification
    ) {
      needsClarification = true;
      clarificationQuestion = "Was this breakfast, lunch, dinner, or a snack?";
    }

    const readyToLog =
      !needsClarification && mealType !== null && item.status === "resolved";

    return {
      originalText: input.text,
      mealType,
      mealTypeSource,
      interpretationConfidence,
      items: [item],
      readyToLog,
      needsClarification,
      clarificationQuestion,
    };
  }
}
