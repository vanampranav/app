import {AiProvider} from "../ai/ai-provider";
import {InterpretedFood, MealType} from "../ai/types";
import {NutritionProvider} from "../nutrition/nutrition-provider";
import {
  FoodSearchResult,
  FoodServingResult,
  NutritionData,
} from "../nutrition/types";
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
  if (["tbsp", "tbsp.", "tablespoon", "tablespoons"].includes(u)) {
    return "tablespoon";
  }
  if (["tsp", "tsp.", "teaspoon", "teaspoons"].includes(u)) {
    return "teaspoon";
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
    return (
      normMetric === "g" ||
      normMetric === "gram" ||
      normMetric === "grams" ||
      /(?:\d+|\b)(?:g|gram|grams)\b/i.test(normDesc)
    );
  }

  if (normReqUnit === "piece") {
    return (
      /\b1?\s*piece\b/i.test(normDesc) ||
      /\b1?\s*pc\b/i.test(normDesc) ||
      /\b1?\s*idli\b/i.test(normDesc) ||
      /\b1?\s*dosa\b/i.test(normDesc) ||
      /\b1?\s*item\b/i.test(normDesc) ||
      /\b1?\s*slice\b/i.test(normDesc)
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

  if (normReqUnit === "tablespoon") {
    return (
      /\b1?\s*tbsp\b/i.test(normDesc) ||
      /\b1?\s*tablespoon\b/i.test(normDesc)
    );
  }

  if (normReqUnit === "teaspoon") {
    return (
      /\b1?\s*tsp\b/i.test(normDesc) ||
      /\b1?\s*teaspoon\b/i.test(normDesc)
    );
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

  // 1. Direct unit match
  for (const s of servings) {
    if (isUnitMatch(s, normReqUnit)) {
      return s;
    }
  }

  // 2. Fallback for volumetric or generic units if gram serving is available
  if (
    ["tablespoon", "teaspoon", "cup", "bowl", "serving", "piece"].includes(
      normReqUnit
    )
  ) {
    for (const s of servings) {
      if (getServingWeightInGrams(s) !== null) {
        return s;
      }
    }
    if (servings.length > 0) {
      return servings[0];
    }
  }

  return null;
}

/**
 * Extracts the weight in grams for 1 unit of a serving option.
 *
 * @param {FoodServingResult} serving - Serving option object.
 * @return {number | null} Weight in grams per serving unit, or null if unknown.
 */
function getServingWeightInGrams(serving: FoodServingResult): number | null {
  const normDesc = normalizeStr(serving.description);

  // 1. Check description for explicit gram patterns
  const descGramMatch = normDesc.match(
    /\b(\d+(?:\.\d+)?)\s*(?:g|gram|grams)\b/i
  );
  if (descGramMatch) {
    const descGrams = parseFloat(descGramMatch[1]);
    if (!isNaN(descGrams) && descGrams > 0) {
      return descGrams;
    }
  }

  // 2. Check metricAmount and metricUnit from provider
  if (typeof serving.metricAmount === "number" && serving.metricAmount > 0) {
    const normMetricUnit = serving.metricUnit ?
      normalizeStr(serving.metricUnit) :
      "";
    if (
      normMetricUnit === "g" ||
      normMetricUnit === "gram" ||
      normMetricUnit === "grams"
    ) {
      return serving.metricAmount;
    }
    if (normMetricUnit === "oz") {
      return Math.round(serving.metricAmount * 28.3495 * 100) / 100;
    }
    if (normMetricUnit === "kg") {
      return serving.metricAmount * 1000;
    }
  }

  return null;
}

/**
 * Validates structural safety invariants for a resolved proposal item.
 * Focuses on structural consistency (weight match, non-negativity,
 * valid numbers, non-corrupted calorie density) rather than arbitrary
 * calorie caps.
 *
 * @param {MealProposalItem} item - Proposal item to validate.
 * @return {Object} Validation result object.
 */
function validateItemSanity(
  item: MealProposalItem
): {isValid: boolean, reason?: string} {
  if (item.status !== "resolved") {
    return {isValid: true};
  }

  if (!item.nutrition) {
    return {isValid: false, reason: "Missing nutrition data"};
  }

  const c = item.nutrition.calories;
  const p = item.nutrition.protein;
  const carbs = item.nutrition.carbs;
  const f = item.nutrition.fat;

  // 1. Structural validity: NaN / Infinity / Negative values
  if (
    (c !== null && (isNaN(c) || !isFinite(c) || c < 0)) ||
    (p !== null && (isNaN(p) || !isFinite(p) || p < 0)) ||
    (carbs !== null && (isNaN(carbs) || !isFinite(carbs) || carbs < 0)) ||
    (f !== null && (isNaN(f) || !isFinite(f) || f < 0))
  ) {
    return {
      isValid: false,
      reason: "Invalid or negative nutrient value detected",
    };
  }

  // 2. Weight validity for resolved items
  if (
    item.weightGrams === null ||
    isNaN(item.weightGrams) ||
    !isFinite(item.weightGrams) ||
    item.weightGrams <= 0
  ) {
    return {
      isValid: false,
      reason: "Zero, negative, or NaN weight for resolved item",
    };
  }

  // 3. Structural Gram Mismatch:
  // For gram requests, resolved weightGrams must be consistent with requested
  const normReqUnit = normalizeUnit(item.requestedUnit);
  if (
    normReqUnit === "g" &&
    item.requestedQuantity !== null &&
    item.requestedQuantity > 0
  ) {
    const ratio = item.weightGrams / item.requestedQuantity;
    // Allow small rounding tolerance (0.75x to 1.25x)
    if (ratio > 1.25 || ratio < 0.75) {
      return {
        isValid: false,
        reason:
          "Structural weight mismatch for gram input: requested " +
          `${item.requestedQuantity}g but resolved weight is ` +
          `${item.weightGrams}g (ratio ${ratio.toFixed(2)})`,
      };
    }
  }

  // 4. Physical Calorie Density Check (max pure fat density ~9 kcal/g)
  if (c !== null && c > 0) {
    const calorieDensity = c / item.weightGrams;
    if (
      calorieDensity > 10.0 ||
      isNaN(calorieDensity) ||
      !isFinite(calorieDensity)
    ) {
      return {
        isValid: false,
        reason:
          `Corrupted calorie density (${calorieDensity.toFixed(2)} ` +
          "kcal/g) exceeds physical maximum (10 kcal/g)",
      };
    }
  }

  return {isValid: true};
}

/**
 * Validates total proposal nutrition structural sanity.
 *
 * @param {NutritionData | null} total - Total aggregated nutrition.
 * @return {boolean} True if total nutrition is structurally valid.
 */
function validateProposalNutritionSanity(
  total: NutritionData | null
): boolean {
  if (!total) {
    return true;
  }
  const c = total.calories;
  const p = total.protein;
  const carbs = total.carbs;
  const f = total.fat;

  if (c !== null && (isNaN(c) || !isFinite(c) || c < 0)) return false;
  if (p !== null && (isNaN(p) || !isFinite(p) || p < 0)) return false;
  if (carbs !== null && (isNaN(carbs) || !isFinite(carbs) || carbs < 0)) {
    return false;
  }
  if (f !== null && (isNaN(f) || !isFinite(f) || f < 0)) return false;

  return true;
}

/**
 * Calculates total nutrition summing ONLY resolved items.
 *
 * @param {MealProposalItem[]} items - Meal proposal items.
 * @return {NutritionData | null} Aggregated nutrition data or null.
 */
function calculateResolvedNutritionTotal(
  items: MealProposalItem[]
): NutritionData | null {
  const resolvedItems = items.filter(
    (item) => item.status === "resolved" && item.nutrition !== null
  );

  if (resolvedItems.length === 0) {
    return null;
  }

  const nutrientKeys: Array<keyof NutritionData> = [
    "calories",
    "fat",
    "carbs",
    "protein",
    "fiber",
    "sugar",
    "vitaminA",
    "vitaminB1",
    "vitaminB2",
    "vitaminC",
    "vitaminE",
    "calcium",
    "iron",
    "magnesium",
    "potassium",
    "sodium",
    "zinc",
    "cholesterol",
    "carotene",
    "retinol",
  ];

  const total: NutritionData = {
    calories: null,
    fat: null,
    carbs: null,
    protein: null,
    fiber: null,
    sugar: null,
    vitaminA: null,
    vitaminB1: null,
    vitaminB2: null,
    vitaminC: null,
    vitaminE: null,
    calcium: null,
    iron: null,
    magnesium: null,
    potassium: null,
    sodium: null,
    zinc: null,
    cholesterol: null,
    carotene: null,
    retinol: null,
  };

  let hasAnyNumericValue = false;

  for (const key of nutrientKeys) {
    let sum = 0;
    let count = 0;
    for (const item of resolvedItems) {
      if (item.nutrition) {
        const val = item.nutrition[key];
        if (val !== null && val !== undefined && !isNaN(val)) {
          sum += val;
          count++;
        }
      }
    }
    if (count > 0) {
      total[key] = Math.round(sum * 10) / 10;
      hasAnyNumericValue = true;
    }
  }

  return hasAnyNumericValue ? total : null;
}

/**
 * Normalizes English number words and quantity phrases into numeric values.
 *
 * @param {string} str - Raw word or phrase string.
 * @return {number | null} Parsed numeric quantity or null.
 */
function parseWordNumber(str: string): number | null {
  const norm = str.toLowerCase().trim().replace(/\s+/g, " ");

  const exactWords: Record<string, number> = {
    "zero": 0,
    "a": 1,
    "an": 1,
    "one": 1,
    "a single": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
    "twenty": 20,
    "thirty": 30,
    "forty": 40,
    "fifty": 50,
    "sixty": 60,
    "seventy": 70,
    "eighty": 80,
    "ninety": 90,
    "hundred": 100,
    "a hundred": 100,
    "one hundred": 100,
    "two hundred": 200,
    "three hundred": 300,
    "four hundred": 400,
    "five hundred": 500,
    "half": 0.5,
    "a half": 0.5,
    "one half": 0.5,
    "half a": 0.5,
    "quarter": 0.25,
    "a quarter": 0.25,
    "one quarter": 0.25,
    "quarter of a": 0.25,
    "three quarters": 0.75,
    "one and a half": 1.5,
    "one and half": 1.5,
    "1 and a half": 1.5,
    "1 and 1/2": 1.5,
    "two and a half": 2.5,
    "two and half": 2.5,
    "2 and a half": 2.5,
    "2 and 1/2": 2.5,
    "three and a half": 3.5,
  };

  if (exactWords[norm] !== undefined) {
    return exactWords[norm];
  }

  if (norm.startsWith("one hundred ") || norm.startsWith("hundred ")) {
    const rest = norm.replace(/^(one hundred|hundred)\s*(and\s*)?/, "");
    if (exactWords[rest] !== undefined) {
      return 100 + exactWords[rest];
    }
  }

  if (norm.includes("and a half") || norm.includes("and half")) {
    const wholePart = norm.replace(/\s*and\s*(a\s*)?half.*/, "");
    let wholeNum: number | null = null;
    if (/^\d+$/.test(wholePart)) {
      wholeNum = parseFloat(wholePart);
    } else if (exactWords[wholePart] !== undefined) {
      wholeNum = exactWords[wholePart];
    }
    if (wholeNum !== null && !isNaN(wholeNum)) {
      return wholeNum + 0.5;
    }
  }

  return null;
}

/**
 * Interprets a user's clarification answer string into quantity and unit.
 *
 * @param {string} answer - User's clarification answer text.
 * @param {MealProposalItem} targetItem - Unresolved target item.
 * @return {Object} Quantity and unit object.
 */
function interpretClarificationAnswer(
  answer: string,
  targetItem: MealProposalItem
): {quantity: number | null, unit: string | null} {
  const norm = normalizeStr(answer);

  const vaguePhrases = [
    "a little",
    "a bit",
    "some",
    "decent amount",
    "a decent amount",
    "good amount",
    "a lot",
    "plenty",
    "small portion",
    "large portion",
  ];
  if (vaguePhrases.includes(norm)) {
    return {quantity: null, unit: null};
  }

  const unitPatterns: Array<{regex: RegExp, unit: string}> = [
    {regex: /\b(g|grams|gram|gms)\b/i, unit: "g"},
    {regex: /\b(kg|kilograms|kilogram)\b/i, unit: "kg"},
    {regex: /\b(cup|cups)\b/i, unit: "cup"},
    {regex: /\b(bowl|bowls)\b/i, unit: "bowl"},
    {regex: /\b(tbsp|tbsp\.|tablespoon|tablespoons)\b/i, unit: "tablespoon"},
    {regex: /\b(tsp|tsp\.|teaspoon|teaspoons)\b/i, unit: "teaspoon"},
    {regex: /\b(piece|pieces|pc|pcs)\b/i, unit: "piece"},
    {regex: /\b(serving|servings)\b/i, unit: "serving"},
  ];

  let detectedUnit: string | null = null;
  for (const u of unitPatterns) {
    if (u.regex.test(norm)) {
      detectedUnit = u.unit;
      break;
    }
  }

  const numericMatch = norm.match(/(\d+(?:\.\d+)?|\d+\/\d+)/);
  if (numericMatch) {
    const rawVal = numericMatch[1];
    let qty: number | null = null;
    if (rawVal.includes("/")) {
      const parts = rawVal.split("/");
      const num = parseFloat(parts[0]);
      const den = parseFloat(parts[1]);
      if (den > 0) qty = num / den;
    } else {
      qty = parseFloat(rawVal);
    }

    if (
      qty !== null &&
      (norm.includes("and a half") || norm.includes("and half")) &&
      !norm.includes(".5")
    ) {
      qty += 0.5;
    }

    if (qty !== null && !isNaN(qty) && qty > 0) {
      return {
        quantity: qty,
        unit: normalizeUnit(detectedUnit || targetItem.requestedUnit),
      };
    }
  }

  const unitWordsRegex = new RegExp(
    "\\b(g|grams|gram|gms|kg|cup|cups|bowl|bowls|tbsp|tablespoon|" +
      "tablespoons|tsp|teaspoon|teaspoons|piece|pieces|pc|pcs|" +
      "serving|servings)\\b",
    "g"
  );
  const cleanTextForNum = norm.replace(unitWordsRegex, "").trim();

  const parsedWordQty =
    parseWordNumber(cleanTextForNum) ?? parseWordNumber(norm);
  if (parsedWordQty !== null && parsedWordQty > 0) {
    return {
      quantity: parsedWordQty,
      unit: normalizeUnit(detectedUnit || targetItem.requestedUnit),
    };
  }

  return {quantity: null, unit: null};
}

/**
 * Orchestrator class combining AI meal interpretation with deterministic
 * nutrition database resolution to create non-persisted MealProposals.
 */
export class MealOrchestrator {
  /**
   * Resolves a single food item independently.
   *
   * @param {InterpretedFood} food - Interpreted food item.
   * @param {NutritionProvider} nutritionProvider - Provider instance.
   * @return {Promise<MealProposalItem>} Resolved or unresolved item.
   */
  private static async resolveProposalItem(
    food: InterpretedFood,
    nutritionProvider: NutritionProvider
  ): Promise<MealProposalItem> {
    const interpretedName = food.name;
    const requestedQuantity = food.quantity;
    const requestedUnit = food.unit;

    try {
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
        return {
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
        return {
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
          clarificationQuestion: `How much ${interpretedName} did you have?`,
        };
      }

      // 3. Check quantity
      if (requestedQuantity === null || requestedQuantity <= 0) {
        const normUnit = normalizeUnit(requestedUnit);
        let question = `How much ${interpretedName} did you have?`;
        if (normUnit === "piece") {
          const endsWithS = interpretedName.toLowerCase().endsWith("s");
          const pluralName = endsWithS ?
            interpretedName :
            `${interpretedName}s`;
          question = `How many ${pluralName} did you have?`;
        }

        return {
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
          clarificationQuestion: question,
        };
      }

      // 4. Calculate provider quantity scaling
      const normUnit = normalizeUnit(requestedUnit);
      let providerQuantity = requestedQuantity;

      const servingGrams = getServingWeightInGrams(matchedServing);

      if (normUnit === "g") {
        if (servingGrams && servingGrams > 0) {
          providerQuantity = requestedQuantity / servingGrams;
        }
      } else if (
        normUnit === "tablespoon" &&
        !isUnitMatch(matchedServing, "tablespoon")
      ) {
        if (servingGrams && servingGrams > 0) {
          providerQuantity = (requestedQuantity * 15) / servingGrams;
        }
      } else if (
        normUnit === "teaspoon" &&
        !isUnitMatch(matchedServing, "teaspoon")
      ) {
        if (servingGrams && servingGrams > 0) {
          providerQuantity = (requestedQuantity * 5) / servingGrams;
        }
      } else if (
        normUnit === "cup" &&
        !isUnitMatch(matchedServing, "cup")
      ) {
        if (servingGrams && servingGrams > 0) {
          providerQuantity = (requestedQuantity * 240) / servingGrams;
        }
      }

      // Resolve food with provider scaling
      const resolved = await nutritionProvider.resolveFood(
        matchedFoodId,
        matchedServing.servingId,
        providerQuantity
      );

      const resolvedWeight =
        servingGrams !== null && servingGrams > 0 ?
          Math.round(
            (servingGrams * providerQuantity + Number.EPSILON) * 100
          ) / 100 :
          resolved.weightGrams ?? null;

      console.log(
        "[Gram-Scaling Resolution Trace]\n" +
        `  interpretedName: ${interpretedName}\n` +
        `  requestedQuantity: ${requestedQuantity}\n` +
        `  requestedUnit: ${requestedUnit}\n` +
        `  matchedFoodName: ${matchedFoodName}\n` +
        `  matchedServingId: ${matchedServing.servingId}\n` +
        `  matchedServingDescription: ${matchedServing.description}\n` +
        `  metricAmount: ${matchedServing.metricAmount}\n` +
        `  metricUnit: ${matchedServing.metricUnit}\n` +
        `  derivedServingGrams: ${servingGrams}\n` +
        `  providerQuantity: ${providerQuantity}\n` +
        `  resolved weightGrams: ${resolvedWeight}\n` +
        `  base serving calories: ${matchedServing.nutrition?.calories}\n` +
        `  resolved calories: ${resolved.nutrition?.calories}`
      );

      const candidateItem: MealProposalItem = {
        interpretedName,
        matchedFoodId,
        matchedFoodName,
        brandName,
        requestedQuantity,
        requestedUnit,
        matchedServingId: matchedServing.servingId,
        matchedServingDescription: matchedServing.description,
        resolvedQuantity: requestedQuantity,
        weightGrams: resolvedWeight,
        nutrition: resolved.nutrition,
        matchConfidence: bestScore,
        status: "resolved",
        clarificationQuestion: null,
      };

      const sanityCheck = validateItemSanity(candidateItem);
      if (!sanityCheck.isValid) {
        console.warn(
          `[Sanity FAILED] "${interpretedName}": ${sanityCheck.reason}\n` +
          `  food: ${interpretedName}\n` +
          `  requested quantity/unit: ${requestedQuantity} ${requestedUnit}\n` +
          `  serving: ${matchedServing.description}\n` +
          `  resolved quantity: ${requestedQuantity}\n` +
          `  weight grams: ${resolvedWeight}\n` +
          `  calories: ${resolved.nutrition?.calories}\n` +
          `  p/c/f: ${resolved.nutrition?.protein}g / ` +
          `${resolved.nutrition?.carbs}g / ${resolved.nutrition?.fat}g`
        );

        return {
          ...candidateItem,
          status: "needs_quantity",
          resolvedQuantity: null,
          weightGrams: null,
          nutrition: null,
          clarificationQuestion:
            "I couldn't confirm the exact quantity for " +
            `${interpretedName}. Could you clarify how much you had?`,
        };
      }

      return candidateItem;
    } catch (error) {
      console.error(
        `Error resolving food item "${interpretedName}":`,
        error
      );

      return {
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
        matchConfidence: 0.0,
        status: "needs_food_match",
        clarificationQuestion: `Which ${interpretedName} did you have?`,
      };
    }
  }

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
        resolvedItemCount: 0,
        unresolvedItemCount: 0,
        resolvedNutritionTotal: null,
      };
    }

    const items: MealProposalItem[] = [];
    for (const food of interpretation.foods) {
      const item = await MealOrchestrator.resolveProposalItem(
        food,
        nutritionProvider
      );
      items.push(item);
    }

    const resolvedItemCount = items.filter(
      (i) => i.status === "resolved"
    ).length;
    const unresolvedItemCount = items.length - resolvedItemCount;

    const hasUnresolvedItem = unresolvedItemCount > 0;
    const isMealTypeUnknown = mealType === null;
    const needsClarification =
      hasUnresolvedItem ||
      isMealTypeUnknown ||
      interpretation.needsClarification;

    let clarificationQuestion: string | null = null;

    if (needsClarification) {
      const itemNeedsFoodMatch = items.find(
        (i) => i.status === "needs_food_match"
      );
      if (itemNeedsFoodMatch) {
        clarificationQuestion = itemNeedsFoodMatch.clarificationQuestion;
      } else {
        const itemNeedsServing = items.find(
          (i) => i.status === "needs_serving"
        );
        if (itemNeedsServing) {
          clarificationQuestion = itemNeedsServing.clarificationQuestion;
        } else {
          const itemNeedsQuantity = items.find(
            (i) => i.status === "needs_quantity"
          );
          if (itemNeedsQuantity) {
            clarificationQuestion = itemNeedsQuantity.clarificationQuestion;
          } else if (
            interpretation.needsClarification &&
            interpretation.clarificationQuestion
          ) {
            clarificationQuestion = interpretation.clarificationQuestion;
          } else if (isMealTypeUnknown) {
            clarificationQuestion =
              "Was this breakfast, lunch, dinner, or a snack?";
          }
        }
      }
    }

    const resolvedNutritionTotal = calculateResolvedNutritionTotal(items);
    const isTotalPlausible =
      validateProposalNutritionSanity(resolvedNutritionTotal);

    const readyToLog =
      mealType !== null &&
      !needsClarification &&
      isTotalPlausible &&
      items.length > 0 &&
      items.every((i) => i.status === "resolved");

    return {
      originalText: input.text,
      mealType,
      mealTypeSource,
      interpretationConfidence,
      items,
      readyToLog,
      needsClarification,
      clarificationQuestion,
      resolvedItemCount,
      unresolvedItemCount,
      resolvedNutritionTotal,
    };
  }

  /**
   * Updates an existing MealProposal by re-resolving ONLY the target item.
   *
   * @param {MealProposal} proposal - Existing proposal object.
   * @param {number} itemIndex - Index of unresolved item to clarify.
   * @param {string} answer - Clarification answer text.
   * @param {NutritionProvider} nutritionProvider - Active nutrition provider.
   * @return {Promise<MealProposal>} Updated MealProposal object.
   */
  static async resolveMealClarification(
    proposal: MealProposal,
    itemIndex: number,
    answer: string,
    nutritionProvider: NutritionProvider
  ): Promise<MealProposal> {
    if (
      !proposal ||
      !Array.isArray(proposal.items) ||
      itemIndex < 0 ||
      itemIndex >= proposal.items.length
    ) {
      throw new Error("Invalid proposal or itemIndex");
    }

    const targetItem = proposal.items[itemIndex];
    const parsed = interpretClarificationAnswer(answer, targetItem);

    if (parsed.quantity === null) {
      const question =
        "About how much " +
        targetItem.interpretedName +
        " was that — grams, cups, or another serving size?";
      const updatedItem: MealProposalItem = {
        ...targetItem,
        status: "needs_quantity",
        clarificationQuestion: question,
      };
      const updatedItems = [...proposal.items];
      updatedItems[itemIndex] = updatedItem;

      const resolvedCount = updatedItems.filter(
        (i) => i.status === "resolved"
      ).length;
      const unresolvedCount = updatedItems.length - resolvedCount;

      return {
        originalText: proposal.originalText,
        mealType: proposal.mealType,
        mealTypeSource: proposal.mealTypeSource,
        interpretationConfidence: proposal.interpretationConfidence,
        items: updatedItems,
        readyToLog: false,
        needsClarification: true,
        clarificationQuestion: question,
        resolvedItemCount: resolvedCount,
        unresolvedItemCount: unresolvedCount,
        resolvedNutritionTotal: calculateResolvedNutritionTotal(updatedItems),
      };
    }

    const updatedQuantity = parsed.quantity;
    const updatedUnit = parsed.unit ?? targetItem.requestedUnit;

    const updatedFood: InterpretedFood = {
      name: targetItem.matchedFoodName || targetItem.interpretedName,
      quantity: updatedQuantity,
      unit: updatedUnit,
      modifiers: [],
    };

    const resolvedItem = await MealOrchestrator.resolveProposalItem(
      updatedFood,
      nutritionProvider
    );

    const updatedItems = [...proposal.items];
    updatedItems[itemIndex] = resolvedItem;

    const resolvedItemCount = updatedItems.filter(
      (i) => i.status === "resolved"
    ).length;
    const unresolvedItemCount = updatedItems.length - resolvedItemCount;

    const hasUnresolvedItem = unresolvedItemCount > 0;
    const isMealTypeUnknown = proposal.mealType === null;
    const needsClarification = hasUnresolvedItem || isMealTypeUnknown;

    let clarificationQuestion: string | null = null;

    if (needsClarification) {
      const itemNeedsFoodMatch = updatedItems.find(
        (i) => i.status === "needs_food_match"
      );
      if (itemNeedsFoodMatch) {
        clarificationQuestion = itemNeedsFoodMatch.clarificationQuestion;
      } else {
        const itemNeedsServing = updatedItems.find(
          (i) => i.status === "needs_serving"
        );
        if (itemNeedsServing) {
          clarificationQuestion = itemNeedsServing.clarificationQuestion;
        } else {
          const itemNeedsQuantity = updatedItems.find(
            (i) => i.status === "needs_quantity"
          );
          if (itemNeedsQuantity) {
            clarificationQuestion = itemNeedsQuantity.clarificationQuestion;
          } else if (isMealTypeUnknown) {
            clarificationQuestion =
              "Was this breakfast, lunch, dinner, or a snack?";
          }
        }
      }
    }

    const resolvedNutritionTotal =
      calculateResolvedNutritionTotal(updatedItems);
    const isTotalPlausible =
      validateProposalNutritionSanity(resolvedNutritionTotal);

    const readyToLog =
      proposal.mealType !== null &&
      !needsClarification &&
      isTotalPlausible &&
      updatedItems.length > 0 &&
      updatedItems.every((i) => i.status === "resolved");

    return {
      originalText: proposal.originalText,
      mealType: proposal.mealType,
      mealTypeSource: proposal.mealTypeSource,
      interpretationConfidence: proposal.interpretationConfidence,
      items: updatedItems,
      readyToLog,
      needsClarification,
      clarificationQuestion,
      resolvedItemCount,
      unresolvedItemCount,
      resolvedNutritionTotal,
    };
  }

  /**
   * Updates an existing MealProposal's mealType context.
   *
   * @param {MealProposal} proposal - Existing proposal object.
   * @param {string} mealType - New meal type
   *     ("breakfast"|"lunch"|"dinner"|"snacks").
   * @return {MealProposal} Updated MealProposal object.
   */
  static updateMealProposalContext(
    proposal: MealProposal,
    mealType: string
  ): MealProposal {
    if (!proposal || !Array.isArray(proposal.items)) {
      throw new Error("Invalid proposal object");
    }

    const validMealTypes = ["breakfast", "lunch", "dinner", "snacks"];
    const normType = mealType.toLowerCase().trim();
    if (!validMealTypes.includes(normType)) {
      throw new Error(`Invalid mealType: ${mealType}`);
    }

    const updatedMealType = normType as MealType;
    const resolvedItemCount = proposal.items.filter(
      (i) => i.status === "resolved"
    ).length;
    const unresolvedItemCount = proposal.items.length - resolvedItemCount;

    const hasUnresolvedItem = unresolvedItemCount > 0;
    const needsClarification = hasUnresolvedItem;

    let clarificationQuestion: string | null = null;

    if (needsClarification) {
      const itemNeedsFoodMatch = proposal.items.find(
        (i) => i.status === "needs_food_match"
      );
      if (itemNeedsFoodMatch) {
        clarificationQuestion = itemNeedsFoodMatch.clarificationQuestion;
      } else {
        const itemNeedsServing = proposal.items.find(
          (i) => i.status === "needs_serving"
        );
        if (itemNeedsServing) {
          clarificationQuestion = itemNeedsServing.clarificationQuestion;
        } else {
          const itemNeedsQuantity = proposal.items.find(
            (i) => i.status === "needs_quantity"
          );
          if (itemNeedsQuantity) {
            clarificationQuestion = itemNeedsQuantity.clarificationQuestion;
          }
        }
      }
    }

    const readyToLog =
      !needsClarification &&
      proposal.items.length > 0 &&
      proposal.items.every((i) => i.status === "resolved");

    return {
      originalText: proposal.originalText,
      mealType: updatedMealType,
      mealTypeSource: "context",
      interpretationConfidence: proposal.interpretationConfidence,
      items: proposal.items,
      readyToLog,
      needsClarification,
      clarificationQuestion,
      resolvedItemCount,
      unresolvedItemCount,
      resolvedNutritionTotal: proposal.resolvedNutritionTotal,
    };
  }
}
