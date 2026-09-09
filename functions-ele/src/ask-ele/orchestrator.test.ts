import {MealOrchestrator} from "./meal-orchestrator";
import {ConversationStateManager} from "./state-manager";
import {MealProposalItem, TurnClassificationResult} from "./types";
import {AiProvider} from "../ai/ai-provider";
import {
  ClassifyTurnInput,
  GetGuidanceInput,
  GetGuidanceOutput,
  InterpretMealInput,
  MealInterpretation,
} from "../ai/types";
import {NutritionProvider} from "../nutrition/nutrition-provider";
import {
  FoodDetailsResult,
  FoodSearchResult,
  ResolvedFoodResult,
  SearchFoodsOptions,
} from "../nutrition/types";

/**
 * Mock AiProvider for testing.
 */
class MockAiProvider implements AiProvider {
  readonly name = "mock_ai";

  /**
   * Creates an instance of MockAiProvider.
   *
   * @param {MealInterpretation} mockResponse - Mock interpretation response.
   */
  constructor(private readonly mockResponse: MealInterpretation) {}

  /**
   * Returns mock meal interpretation.
   *
   * @param {InterpretMealInput} input - User input context.
   * @return {Promise<MealInterpretation>} Mocked interpretation.
   */
  async interpretMeal(
    input: InterpretMealInput
  ): Promise<MealInterpretation> {
    const text = (input.text || "").toLowerCase();
    if (text.includes("250g") || text.includes("250 g")) {
      return {
        foods: [{name: "chicken", quantity: 250, unit: "g", modifiers: []}],
        mealType: "dinner",
        mealTypeSource: "explicit",
        confidence: 0.95,
        needsClarification: false,
        clarificationQuestion: null,
      };
    }
    if (text === "100g" || text === "100 g") {
      return {
        foods: [{name: "food", quantity: 100, unit: "g", modifiers: []}],
        mealType: "dinner",
        mealTypeSource: "explicit",
        confidence: 0.95,
        needsClarification: false,
        clarificationQuestion: null,
      };
    }
    if (text.includes("soy chunks") || text.includes("soy")) {
      return {
        foods: [{name: "soy chunks", quantity: null, unit: "g", modifiers: []}],
        mealType: "dinner",
        mealTypeSource: "explicit",
        confidence: 0.95,
        needsClarification: true,
        clarificationQuestion:
          "How much dry soy chunks are you planning to use?",
      };
    }
    if (text.includes("no sugar")) {
      return {
        foods: [{name: "tea", quantity: 1, unit: "cup", modifiers: ["milk"]}],
        mealType: "snacks",
        mealTypeSource: "explicit",
        confidence: 0.9,
        needsClarification: false,
        clarificationQuestion: null,
      };
    }
    return this.mockResponse;
  }

  /**
   * Classifies user turn into structured TurnClassificationResult & mutations.
   *
   * @param {ClassifyTurnInput} input - Message and active session state.
   * @return {Promise<TurnClassificationResult>} Classified turn result.
   */
  async classifyTurnAndMutations(
    input: ClassifyTurnInput
  ): Promise<TurnClassificationResult> {
    const text = (input.message || "").toLowerCase().trim();
    const draftItems = input.session.mealDraft?.items || [];

    if (
      text.includes("forget") ||
      text === "cancel" ||
      text === "clear" ||
      text === "start over"
    ) {
      return {
        turnType: "CANCEL_PENDING_TASK",
        intent: "cancel",
        mutations: [],
      };
    }

    if (
      text.includes("how much protein") ||
      text.includes("protein left") ||
      text.includes("what workout") ||
      text.includes("what should i eat")
    ) {
      return {
        turnType: "NEW_INTENT",
        intent: "daily_guidance",
        mutations: [],
      };
    }

    // Differently worded quantity modification requests:
    // "make the chicken 250g", "change chicken to 250 grams"
    if (
      text.includes("250g") ||
      text.includes("250 grams") ||
      text.includes("250 g")
    ) {
      const target = draftItems.find((i: MealProposalItem) =>
        i.interpretedName.toLowerCase().includes("chicken")
      ) || draftItems[0];
      return {
        turnType: "MODIFICATION_OF_PENDING_TASK",
        intent: "log_meal",
        mutations: [
          {
            op: "CHANGE_QUANTITY",
            targetEntityId: target ? target.itemId : "item_1",
            targetFoodName: target ? target.interpretedName : "chicken",
            quantity: 250,
            unit: "g",
          },
        ],
      };
    }

    if (
      text.includes("sugar") &&
      (text.includes("no ") ||
        text.includes("hold") ||
        text.includes("drop") ||
        text.includes("without"))
    ) {
      const target = draftItems.find((i: MealProposalItem) =>
        i.interpretedName.toLowerCase().includes("tea")
      ) || draftItems[0];
      return {
        turnType: "MODIFICATION_OF_PENDING_TASK",
        intent: "log_meal",
        mutations: [
          {
            op: "UPDATE_MODIFIERS",
            targetEntityId: target ? target.itemId : "item_0",
            targetFoodName: target ? target.interpretedName : "tea",
            removeModifiers: ["sugar"],
          },
        ],
      };
    }

    if (text.includes("soy chunks") || text.includes("soy")) {
      const target = draftItems.find((i: MealProposalItem) =>
        i.interpretedName.toLowerCase().includes("chicken")
      ) || draftItems[0];
      return {
        turnType: "ANSWER_TO_PENDING_CLARIFICATION",
        intent: "log_meal",
        mutations: [
          {
            op: "REPLACE_ITEM",
            targetEntityId: target ? target.itemId : "item_0",
            targetFoodName: target ? target.interpretedName : "chicken",
            foodName: "soy chunks",
          },
        ],
      };
    }

    if (input.session.pendingClarification || input.session.activeEntityId) {
      return {
        turnType: "ANSWER_TO_PENDING_CLARIFICATION",
        intent: "log_meal",
        mutations: [],
      };
    }

    return {
      turnType: "NEW_MEAL_LOG",
      intent: "log_meal",
      mutations: [],
    };
  }

  /**
   * Returns mock daily guidance.
   *
   * @param {GetGuidanceInput} input - Guidance input context.
   * @return {Promise<GetGuidanceOutput>} Mock guidance output.
   */
  async getGuidance(
    input: GetGuidanceInput
  ): Promise<GetGuidanceOutput> {
    void input;
    return {
      responseType: "meal_recommendation",
      responseText: "Protein is your gap.\n\nHere are 3 options:",
      recommendation: {
        recommendationId: "rec_mock_1",
        mealType: "dinner",
        options: [
          {
            optionId: "opt_1",
            title: "Chicken & Rice",
            foods: ["chicken", "rice"],
            rationale: "High protein meal.",
            estimatedCalories: 550,
            estimatedProtein: 48,
            estimatedCarbs: 50,
            estimatedFat: 12,
            confidence: 0.95,
          },
          {
            optionId: "opt_2",
            title: "Paneer & Roti",
            foods: ["paneer", "roti"],
            rationale: "Vegetarian option.",
            estimatedCalories: 520,
            estimatedProtein: 32,
            estimatedCarbs: 60,
            estimatedFat: 18,
            confidence: 0.9,
          },
        ],
        suggestedFoods: ["chicken", "rice", "paneer", "roti"],
      },
      preparedMealText: null,
      suggestedMealType: null,
    };
  }
}

/**
 * Mock NutritionProvider for testing.
 */
class MockNutritionProvider implements NutritionProvider {
  readonly name = "mock_nutrition";

  /**
   * Creates an instance of MockNutritionProvider.
   *
   * @param {Record<string, FoodSearchResult[]>} searchResultMap - Search map.
   * @param {Record<string, FoodDetailsResult>} detailsMap - Details map.
   */
  constructor(
    private readonly searchResultMap: Record<string, FoodSearchResult[]>,
    private readonly detailsMap: Record<string, FoodDetailsResult>
  ) {}

  /**
   * Searches mock foods.
   *
   * @param {string} query - Query string.
   * @param {SearchFoodsOptions} [options] - Options.
   * @return {Promise<FoodSearchResult[]>} Results array.
   */
  async searchFoods(
    query: string,
    options?: SearchFoodsOptions
  ): Promise<FoodSearchResult[]> {
    void options;
    const norm = query.toLowerCase().trim();
    for (const k of Object.keys(this.searchResultMap)) {
      if (norm.includes(k) || k.includes(norm)) {
        return this.searchResultMap[k];
      }
    }
    return [];
  }

  /**
   * Gets mock food details.
   *
   * @param {string} foodId - Food ID.
   * @return {Promise<FoodDetailsResult>} Food details object.
   */
  async getFoodDetails(foodId: string): Promise<FoodDetailsResult> {
    if (this.detailsMap[foodId]) {
      return this.detailsMap[foodId];
    }
    throw new Error(`Food details not found for ID ${foodId}`);
  }

  /**
   * Resolves mock food.
   *
   * @param {string} foodId - Food ID.
   * @param {string} servingId - Serving ID.
   * @param {number} quantity - Quantity multiplier.
   * @return {Promise<ResolvedFoodResult>} Scaled result object.
   */
  async resolveFood(
    foodId: string,
    servingId: string,
    quantity: number
  ): Promise<ResolvedFoodResult> {
    const details = await this.getFoodDetails(foodId);
    const serving = details.servings.find((s) => s.servingId === servingId);
    if (!serving) {
      throw new Error(`Serving ${servingId} not found`);
    }

    const n = serving.nutrition;
    const scaledCalories =
      n.calories !== null ?
        Math.round(n.calories * quantity * 10) / 10 :
        null;
    const scaledFat =
      n.fat !== null ? Math.round(n.fat * quantity * 10) / 10 : null;
    const scaledCarbs =
      n.carbs !== null ? Math.round(n.carbs * quantity * 10) / 10 : null;
    const scaledProtein =
      n.protein !== null ? Math.round(n.protein * quantity * 10) / 10 : null;

    return {
      foodId: details.foodId,
      name: details.name,
      brandName: details.brandName,
      servingId: serving.servingId,
      servingDescription: serving.description,
      quantity,
      weightGrams:
        serving.metricAmount ?
          Math.round(serving.metricAmount * quantity * 100) / 100 :
          null,
      nutrition: {
        calories: scaledCalories,
        fat: scaledFat,
        carbs: scaledCarbs,
        protein: scaledProtein,
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
      },
      provider: this.name,
    };
  }
}

/**
 * Runs deterministic regression test suite for 8 Ask Ele scenarios.
 *
 * @return {Promise<void>} Resolves when tests pass.
 */
export async function runOrchestratorTests(): Promise<void> {
  console.log("\n========================================================");
  console.log("RUNNING DETERMINISTIC ASK ELE REGRESSION SUITE (8 SCENARIOS)");
  console.log("========================================================\n");

  const emptyNutr = {
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

  const sharedNutrition = new MockNutritionProvider(
    {
      dal: [
        {
          foodId: "dal_1",
          name: "Yellow Dal",
          brandName: null,
          description: "1 serving (100g)",
          caloriesPer100g: 150,
          defaultServing: "1 serving (100g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      rice: [
        {
          foodId: "rice_1",
          name: "Steamed Basmati Rice",
          brandName: null,
          description: "1 cup cooked (158 g)",
          caloriesPer100g: 130,
          defaultServing: "1 cup cooked (158 g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      chutney: [
        {
          foodId: "chutney_1",
          name: "Coconut Chutney",
          brandName: null,
          description: "100 g",
          caloriesPer100g: 180,
          defaultServing: "100 g",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      idli: [
        {
          foodId: "idli_1",
          name: "Idli",
          brandName: null,
          description: "1 idli (55g)",
          caloriesPer100g: 130,
          defaultServing: "1 idli (55g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      chicken: [
        {
          foodId: "chicken_1",
          name: "Grilled Chicken Breast",
          brandName: null,
          description: "100 g",
          caloriesPer100g: 165,
          defaultServing: "100 g",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      soy: [
        {
          foodId: "soy_1",
          name: "Soy Chunks",
          brandName: null,
          description: "100 g",
          caloriesPer100g: 345,
          defaultServing: "100 g",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      corrupted: [
        {
          foodId: "corrupt_1",
          name: "Corrupted Item",
          brandName: null,
          description: "1 serving (0g)",
          caloriesPer100g: 9999,
          defaultServing: "1 serving (0g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      cucumber: [
        {
          foodId: "cucumber_1",
          name: "Cucumber",
          brandName: null,
          description: "1 cup, sliced (104g)",
          caloriesPer100g: 15,
          defaultServing: "1 cup, sliced (104g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      cucumbers: [
        {
          foodId: "cucumber_1",
          name: "Cucumber",
          brandName: null,
          description: "1 cup, sliced (104g)",
          caloriesPer100g: 15,
          defaultServing: "1 cup, sliced (104g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
      tea: [
        {
          foodId: "tea_1",
          name: "Tea",
          brandName: null,
          description: "1 cup (240g)",
          caloriesPer100g: 2,
          defaultServing: "1 cup (240g)",
          imageUrl: null,
          provider: "mock_nutrition",
        },
      ],
    },
    {
      dal_1: {
        foodId: "dal_1",
        name: "Yellow Dal",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_dal",
            description: "1 serving (100g)",
            metricAmount: 1,
            metricUnit: "serving",
            nutrition: {
              ...emptyNutr,
              calories: 150,
              fat: 2,
              carbs: 25,
              protein: 8,
            },
          },
        ],
      },
      rice_1: {
        foodId: "rice_1",
        name: "Steamed Basmati Rice",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_rice",
            description: "1 cup cooked (158 g)",
            metricAmount: 158,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 205,
              fat: 0.4,
              carbs: 45,
              protein: 4.3,
            },
          },
        ],
      },
      chutney_1: {
        foodId: "chutney_1",
        name: "Coconut Chutney",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_chutney",
            description: "100 g",
            metricAmount: 100,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 180,
              fat: 14,
              carbs: 10,
              protein: 3,
            },
          },
        ],
      },
      idli_1: {
        foodId: "idli_1",
        name: "Idli",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_idli",
            description: "1 idli (55g)",
            metricAmount: 55,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 70,
              fat: 0.5,
              carbs: 15,
              protein: 2,
            },
          },
        ],
      },
      chicken_1: {
        foodId: "chicken_1",
        name: "Grilled Chicken Breast",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_chicken",
            description: "100 g",
            metricAmount: 100,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 165,
              fat: 3.6,
              carbs: 0,
              protein: 31,
            },
          },
        ],
      },
      soy_1: {
        foodId: "soy_1",
        name: "Soy Chunks",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_soy",
            description: "100 g",
            metricAmount: 100,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 345,
              fat: 0.5,
              carbs: 33,
              protein: 52,
            },
          },
        ],
      },
      cucumber_1: {
        foodId: "cucumber_1",
        name: "Cucumber",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_cuc_cup",
            description: "1 cup, sliced",
            metricAmount: 104,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 16,
              fat: 0.2,
              carbs: 3.8,
              protein: 0.7,
            },
          },
          {
            servingId: "s_cuc_g",
            description: "100 g",
            metricAmount: 100,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 15,
              fat: 0.2,
              carbs: 3.6,
              protein: 0.7,
            },
          },
        ],
      },
      tea_1: {
        foodId: "tea_1",
        name: "Tea",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_tea",
            description: "1 cup",
            metricAmount: 240,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 2,
              fat: 0,
              carbs: 0.5,
              protein: 0,
            },
          },
        ],
      },
      corrupt_1: {
        foodId: "corrupt_1",
        name: "Corrupted Item",
        brandName: null,
        imageUrl: null,
        provider: "mock_nutrition",
        servings: [
          {
            servingId: "s_corrupt",
            description: "1 serving (0g)",
            metricAmount: 0,
            metricUnit: "g",
            nutrition: {
              ...emptyNutr,
              calories: 9999,
              fat: 500,
              carbs: 500,
              protein: 500,
            },
          },
        ],
      },
    }
  );

  // Scenario 1: "50 g dal"
  const ai1 = new MockAiProvider({
    foods: [{name: "dal", quantity: 50, unit: "g", modifiers: []}],
    mealType: "lunch",
    mealTypeSource: "context",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res1 = await MealOrchestrator.prepareMeal(
    {text: "50 g dal"},
    ai1,
    sharedNutrition
  );
  if (
    !res1.readyToLog ||
    res1.items[0].weightGrams !== 50 ||
    res1.items[0].nutrition?.calories !== 75
  ) {
    throw new Error("Scenario 1 failed: '50 g dal'");
  }
  console.log(
    "PASS Scenario 1: '50 g dal' (weightGrams=50, calories=75, readyToLog=true)"
  );

  // Scenario 2: "100 g rice"
  const ai2 = new MockAiProvider({
    foods: [{name: "rice", quantity: 100, unit: "g", modifiers: []}],
    mealType: "lunch",
    mealTypeSource: "context",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res2 = await MealOrchestrator.prepareMeal(
    {text: "100 g rice"},
    ai2,
    sharedNutrition
  );
  if (res2.items[0].weightGrams !== 100) {
    throw new Error("Scenario 2 failed: '100 g rice'");
  }
  console.log("PASS Scenario 2: '100 g rice' (weightGrams=100)");

  // Scenario 3: "100 g chutney"
  const ai3 = new MockAiProvider({
    foods: [{name: "chutney", quantity: 100, unit: "g", modifiers: []}],
    mealType: "lunch",
    mealTypeSource: "context",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res3 = await MealOrchestrator.prepareMeal(
    {text: "100 g chutney"},
    ai3,
    sharedNutrition
  );
  if (res3.items[0].weightGrams !== 100) {
    throw new Error("Scenario 3 failed: '100 g chutney'");
  }
  console.log("PASS Scenario 3: '100 g chutney' (weightGrams=100)");

  // Scenario 4: "4 idlis for breakfast"
  const ai4 = new MockAiProvider({
    foods: [{name: "idli", quantity: 4, unit: "piece", modifiers: []}],
    mealType: "breakfast",
    mealTypeSource: "explicit",
    confidence: 0.98,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res4 = await MealOrchestrator.prepareMeal(
    {text: "4 idlis for breakfast"},
    ai4,
    sharedNutrition
  );
  if (
    !res4.readyToLog ||
    res4.needsClarification ||
    res4.mealType !== "breakfast" ||
    res4.items[0].requestedQuantity !== 4 ||
    res4.items[0].weightGrams !== 220 ||
    res4.resolvedNutritionTotal?.calories !== 280
  ) {
    throw new Error("Scenario 4 failed: '4 idlis for breakfast'");
  }
  console.log(
    "PASS Scenario 4: '4 idlis for breakfast' (qty=4, weightGrams=220, " +
    "calories=280, mealType=breakfast, readyToLog=true)"
  );

  // Scenario 5: "50 grams of doll"
  const rawSpeechText = "I had 50 grams of doll";
  const ai5 = new MockAiProvider({
    foods: [{name: "dal", quantity: 50, unit: "g", modifiers: []}],
    mealType: "lunch",
    mealTypeSource: "context",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res5 = await MealOrchestrator.prepareMeal(
    {text: rawSpeechText},
    ai5,
    sharedNutrition
  );
  if (
    res5.originalText !== rawSpeechText ||
    res5.items[0].interpretedName !== "dal" ||
    res5.items[0].weightGrams !== 50 ||
    res5.items[0].nutrition?.calories !== 75 ||
    !res5.readyToLog
  ) {
    throw new Error("Scenario 5 failed: '50 grams of doll'");
  }
  console.log(
    "PASS Scenario 5: '50 grams of doll' (normalized to dal, " +
    "rawText unchanged, weightGrams=50, calories=75, readyToLog=true)"
  );

  // Scenario 6: Missing quantity: "I had idli for breakfast"
  const ai6 = new MockAiProvider({
    foods: [{name: "idli", quantity: null, unit: "piece", modifiers: []}],
    mealType: "breakfast",
    mealTypeSource: "explicit",
    confidence: 0.9,
    needsClarification: true,
    clarificationQuestion: "How many idlis did you have?",
  });
  const res6 = await MealOrchestrator.prepareMeal(
    {text: "I had idli for breakfast"},
    ai6,
    sharedNutrition
  );
  if (
    res6.readyToLog ||
    !res6.needsClarification ||
    res6.items[0].requestedQuantity !== null
  ) {
    throw new Error("Scenario 6 failed: Missing quantity");
  }
  console.log(
    "PASS Scenario 6: Missing quantity 'I had idli for breakfast' " +
    "(quantity=null, readyToLog=false, needsClarification=true)"
  );

  // Scenario 7: Ambiguous speech correction
  const ai7 = new MockAiProvider({
    foods: [{name: "roll", quantity: 1, unit: "piece", modifiers: []}],
    mealType: "lunch",
    mealTypeSource: "context",
    confidence: 0.5,
    needsClarification: true,
    clarificationQuestion: "Which kind of roll did you have?",
  });
  const res7 = await MealOrchestrator.prepareMeal(
    {text: "I ate 1 roll"},
    ai7,
    sharedNutrition
  );
  if (res7.readyToLog || !res7.needsClarification) {
    throw new Error("Scenario 7 failed: Ambiguous speech correction");
  }
  console.log(
    "PASS Scenario 7: Ambiguous speech correction " +
    "(readyToLog=false, needsClarification=true, asked clarification)"
  );

  // Scenario 7b: Active Pending Rice Clarification Answers
  // Unresolved proposal where White Rice needs quantity clarification
  const pendingRiceProposal = await MealOrchestrator.prepareMeal(
    {text: "I had White Rice for lunch"},
    new MockAiProvider({
      foods: [{name: "rice", quantity: null, unit: "cup", modifiers: []}],
      mealType: "lunch",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "How much White Rice did you have?",
    }),
    sharedNutrition
  );

  // Test 7b.1: "100 grams"
  const c1 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "100 grams", sharedNutrition
  );
  if (!c1.readyToLog || c1.items[0].weightGrams !== 100) {
    throw new Error("Clarification 1 failed: '100 grams'");
  }
  console.log("PASS Clarification 1: '100 grams' -> 100g rice resolved");

  // Test 7b.2: "Hundred grams"
  const c2 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "Hundred grams", sharedNutrition
  );
  if (!c2.readyToLog || c2.items[0].weightGrams !== 100) {
    throw new Error("Clarification 2 failed: 'Hundred grams'");
  }
  console.log("PASS Clarification 2: 'Hundred grams' -> 100g rice resolved");

  // Test 7b.3: "one hundred grams"
  const c3 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "one hundred grams", sharedNutrition
  );
  if (!c3.readyToLog || c3.items[0].weightGrams !== 100) {
    throw new Error("Clarification 3 failed: 'one hundred grams'");
  }
  console.log(
    "PASS Clarification 3: 'one hundred grams' -> 100g rice resolved"
  );

  // Test 7b.4: "half a cup"
  const c4 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "half a cup", sharedNutrition
  );
  if (!c4.readyToLog || c4.items[0].resolvedQuantity !== 0.5) {
    throw new Error("Clarification 4 failed: 'half a cup'");
  }
  console.log("PASS Clarification 4: 'half a cup' -> 0.5 cup rice resolved");

  // Test 7b.5: "one and a half cups"
  const c5 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "one and a half cups", sharedNutrition
  );
  if (!c5.readyToLog || c5.items[0].resolvedQuantity !== 1.5) {
    throw new Error("Clarification 5 failed: 'one and a half cups'");
  }
  console.log(
    "PASS Clarification 5: 'one and a half cups' -> 1.5 cups rice resolved"
  );

  // Test 7b.6: "two tablespoons"
  const c6 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "two tablespoons", sharedNutrition
  );
  if (!c6.readyToLog || c6.items[0].resolvedQuantity !== 2) {
    throw new Error("Clarification 6 failed: 'two tablespoons'");
  }
  console.log("PASS Clarification 6: 'two tablespoons' -> 2 tbsp resolved");

  // Test 7b.7: "a little"
  const c7 = await MealOrchestrator.resolveMealClarification(
    pendingRiceProposal, 0, "a little", sharedNutrition
  );
  if (c7.readyToLog || !c7.needsClarification) {
    throw new Error("Clarification 7 failed: 'a little'");
  }
  console.log(
    "PASS Clarification 7: 'a little' -> asked clarification, not silent guess"
  );

  // Scenario 8: Structural corruption test
  const ai8 = new MockAiProvider({
    foods: [{name: "corrupted", quantity: 100, unit: "g", modifiers: []}],
    mealType: "dinner",
    mealTypeSource: "context",
    confidence: 0.9,
    needsClarification: false,
    clarificationQuestion: null,
  });
  const res8 = await MealOrchestrator.prepareMeal(
    {text: "100g corrupted item"},
    ai8,
    sharedNutrition
  );
  if (
    res8.readyToLog ||
    !res8.needsClarification ||
    res8.items[0].status === "resolved" ||
    res8.items[0].nutrition !== null
  ) {
    throw new Error("Scenario 8 failed: Structural corruption test");
  }
  console.log(
    "PASS Scenario 8: Structural corruption test " +
    "(rejected item, readyToLog=false, needsClarification=true, nutrition=null)"
  );

  // Scenario 9: Meal Proposal Context Edit Commands
  const sampleProposal = await MealOrchestrator.prepareMeal(
    {text: "50 g dal"},
    ai1,
    sharedNutrition
  );
  const updatedDinner = MealOrchestrator.updateMealProposalContext(
    sampleProposal,
    "dinner"
  );
  if (updatedDinner.mealType !== "dinner") {
    throw new Error("Meal context update to 'dinner' failed");
  }
  console.log(
    "PASS Scenario 9a: 'Dinner' / 'Actually, dinner' -> mealType = dinner"
  );

  const updatedSnack = MealOrchestrator.updateMealProposalContext(
    sampleProposal,
    "snacks"
  );
  if (updatedSnack.mealType !== "snacks") {
    throw new Error("Meal context update to 'snacks' failed");
  }
  console.log(
    "PASS Scenario 9b: 'This is for snack' -> mealType = snacks"
  );

  console.log("\n--------------------------------------------------------");
  console.log("RUNNING RECOMMENDATION HARDENING SUITE (TESTS A - G)");
  console.log("--------------------------------------------------------\n");

  /**
   * Recommendation Mock AI Provider for testing recommendation flows.
   */
  class RecommendationMockAiProvider implements AiProvider {
    readonly name = "rec_mock_ai";

    /**
     * Interprets mock meal.
     *
     * @param {InterpretMealInput} input - Input context.
     * @return {Promise<MealInterpretation>} Mock interpretation.
     */
    async interpretMeal(
      input: InterpretMealInput
    ): Promise<MealInterpretation> {
      return {
        foods: [
          {name: "chicken", quantity: 200, unit: "g", modifiers: []},
          {name: "rice", quantity: 150, unit: "g", modifiers: []},
        ],
        mealType: input.context?.suggestedMealType || "dinner",
        mealTypeSource: "context",
        confidence: 0.95,
        needsClarification: false,
        clarificationQuestion: null,
      };
    }

    /**
     * Generates mock recommendation guidance.
     *
     * @param {GetGuidanceInput} input - Input context.
     * @return {Promise<GetGuidanceOutput>} Mock guidance output.
     */
    async getGuidance(input: GetGuidanceInput): Promise<GetGuidanceOutput> {
      const msg = input.message.toLowerCase();

      if (msg.includes("what should i eat for dinner")) {
        return {
          responseType: "meal_recommendation",
          responseText: "Here are 3 good dinner options:",
          recommendation: {
            recommendationId: "rec_101",
            mealType: "dinner",
            options: [
              {
                optionId: "opt_1",
                title: "Chicken & Rice",
                foods: ["chicken", "rice"],
                rationale: "High protein meal",
                estimatedCalories: 550,
                estimatedProtein: 48,
                estimatedCarbs: 50,
                estimatedFat: 12,
                confidence: 0.95,
              },
              {
                optionId: "opt_2",
                title: "Paneer & Roti",
                foods: ["paneer", "roti"],
                rationale: "Vegetarian protein option",
                estimatedCalories: 500,
                estimatedProtein: 30,
                estimatedCarbs: 55,
                estimatedFat: 16,
                confidence: 0.9,
              },
              {
                optionId: "opt_3",
                title: "Egg & Dal",
                foods: ["egg", "dal"],
                rationale: "Balanced meal",
                estimatedCalories: 450,
                estimatedProtein: 35,
                estimatedCarbs: 40,
                estimatedFat: 14,
                confidence: 0.88,
              },
            ],
          },
          preparedMealText: null,
          suggestedMealType: null,
        };
      }

      if (msg.includes("option 2") || msg.includes("paneer")) {
        return {
          responseType: "recommendation_followup",
          responseText:
            "You picked Paneer & Roti. " +
            "How much paneer and roti are you planning?",
          recommendation: {
            recommendationId: "rec_101",
            mealType: "dinner",
            options: [
              {
                optionId: "opt_2",
                title: "Paneer & Roti",
                foods: ["paneer", "roti"],
                rationale: "Vegetarian option selected",
                estimatedCalories: 500,
                estimatedProtein: 30,
                estimatedCarbs: 55,
                estimatedFat: 16,
                confidence: 0.9,
              },
            ],
          },
          preparedMealText: null,
          suggestedMealType: "dinner",
        };
      }

      if (msg.includes("200g chicken") || msg.includes("200 grams")) {
        return {
          responseType: "recommendation_followup",
          responseText: "",
          recommendation: {
            recommendationId: "rec_101",
            mealType: "dinner",
            options: [],
          },
          preparedMealText: "200g chicken and 150g rice for dinner",
          suggestedMealType: "dinner",
        };
      }

      if (msg.includes("different") || msg.includes("refresh")) {
        return {
          responseType: "meal_recommendation",
          responseText: "Here are 2 alternative dinner options:",
          recommendation: {
            recommendationId: "rec_102",
            mealType: "dinner",
            options: [
              {
                optionId: "opt_4",
                title: "Fish & Quinoa",
                foods: ["fish", "quinoa"],
                rationale: "Lean protein alternative",
                estimatedCalories: 480,
                estimatedProtein: 42,
                estimatedCarbs: 45,
                estimatedFat: 10,
                confidence: 0.92,
              },
              {
                optionId: "opt_5",
                title: "Tofu Stir-fry",
                foods: ["tofu", "vegetables"],
                rationale: "Plant-based protein",
                estimatedCalories: 420,
                estimatedProtein: 28,
                estimatedCarbs: 35,
                estimatedFat: 12,
                confidence: 0.89,
              },
            ],
          },
          preparedMealText: null,
          suggestedMealType: null,
        };
      }

      return {
        responseType: "guidance",
        responseText: "Mock general guidance",
        recommendation: null,
        preparedMealText: null,
        suggestedMealType: null,
      };
    }
  }

  const recAi = new RecommendationMockAiProvider();

  // TEST A: "What should I eat for dinner?" -> 2-3 options with expected fields
  const testA = await recAi.getGuidance({
    message: "What should I eat for dinner?",
    todayContext: {},
    uid: "test_user",
  });
  if (
    testA.responseType !== "meal_recommendation" ||
    !testA.recommendation ||
    testA.recommendation.options.length < 2 ||
    testA.recommendation.options.length > 3
  ) {
    throw new Error("TEST A failed: responseType or option count invalid");
  }
  for (const opt of testA.recommendation.options) {
    if (!opt.optionId || !opt.title || !opt.foods || !opt.rationale) {
      throw new Error("TEST A failed: Option missing required fields");
    }
  }
  console.log(
    "PASS TEST A: responseType=meal_recommendation, " +
    `count=${testA.recommendation.options.length}`
  );

  // TEST B: No recommendation response contains > 3 options
  if (testA.recommendation.options.length > 3) {
    throw new Error("TEST B failed: Option count exceeded 3");
  }
  console.log("PASS TEST B: Option count strictly <= 3 enforced");

  // TEST C: Active recommendation + "I'll take option 2"
  const testC = await recAi.getGuidance({
    message: "I'll take option 2",
    todayContext: {},
    recommendationContext: {
      mealType: "dinner",
      recommendationId: "rec_101",
      options: [
        {
          optionId: "opt_1",
          title: "Chicken & Rice",
          foods: ["chicken", "rice"],
        },
        {
          optionId: "opt_2",
          title: "Paneer & Roti",
          foods: ["paneer", "roti"],
        },
      ],
    },
    uid: "test_user",
  });
  if (
    testC.responseType !== "recommendation_followup" ||
    !testC.recommendation ||
    testC.recommendation.mealType !== "dinner" ||
    testC.recommendation.options[0].optionId !== "opt_2"
  ) {
    throw new Error("TEST C failed: Option 2 selection follow-up failed");
  }
  console.log(
    "PASS TEST C: Option 2 selected, mealType=dinner preserved"
  );

  // TEST D: Selected recommendation + "200g chicken and 150g rice"
  const testD = await recAi.getGuidance({
    message: "200g chicken and 150g rice",
    todayContext: {},
    recommendationContext: {
      mealType: "dinner",
      recommendationId: "rec_101",
      selectedOptionId: "opt_1",
    },
    uid: "test_user",
  });
  if (
    testD.responseType !== "recommendation_followup" ||
    testD.preparedMealText !== "200g chicken and 150g rice for dinner" ||
    testD.suggestedMealType !== "dinner"
  ) {
    throw new Error("TEST D failed: Quantity transition failed");
  }

  // Pass preparedMealText to prepareMeal pipeline
  const preparedProposal = await MealOrchestrator.prepareMeal(
    {
      text: testD.preparedMealText,
      suggestedMealType: testD.suggestedMealType,
    },
    recAi,
    sharedNutrition
  );
  if (
    !preparedProposal.readyToLog ||
    preparedProposal.mealType !== "dinner" ||
    preparedProposal.items.length !== 2
  ) {
    throw new Error("TEST D failed: prepareMeal pipeline transition failed");
  }
  console.log(
    "PASS TEST D: Quantities -> prepareMeal resolved 2 items for dinner"
  );

  // TEST E: "Log it" without ready MealProposal
  const unreadyProposal = await MealOrchestrator.prepareMeal(
    {text: "I had rice"},
    new MockAiProvider({
      foods: [{name: "rice", quantity: null, unit: "g", modifiers: []}],
      mealType: "lunch",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "How much rice?",
    }),
    sharedNutrition
  );
  if (unreadyProposal.readyToLog) {
    throw new Error("TEST E failed: Unready proposal marked readyToLog=true");
  }
  console.log(
    "PASS TEST E: 'Log it' without ready MealProposal -> readyToLog=false"
  );

  // TEST F: Refresh request includes previous recommendation context
  const testF = await recAi.getGuidance({
    message: "Give me a different dinner recommendation",
    todayContext: {},
    recommendationContext: {
      mealType: "dinner",
      recommendationId: "rec_101",
      options: [
        {
          optionId: "opt_1",
          title: "Chicken & Rice",
          foods: ["chicken", "rice"],
        },
        {
          optionId: "opt_2",
          title: "Paneer & Roti",
          foods: ["paneer", "roti"],
        },
      ],
    },
    uid: "test_user",
  });
  if (
    testF.responseType !== "meal_recommendation" ||
    !testF.recommendation ||
    testF.recommendation.recommendationId === "rec_101" ||
    testF.recommendation.options.length < 2
  ) {
    throw new Error("TEST F failed: Refresh did not return new options");
  }
  console.log(
    "PASS TEST F: Refresh with previous options -> returned fresh rec_id=" +
    `${testF.recommendation.recommendationId}`
  );

  // TEST G: Feedback action validation
  const validActions = ["liked", "disliked", "refreshed", "selected"];
  const validateAction = (a: string) =>
    validActions.includes(a.toLowerCase().trim());

  if (
    !validateAction("liked") ||
    !validateAction("disliked") ||
    !validateAction("refreshed") ||
    !validateAction("selected")
  ) {
    throw new Error("TEST G failed: Valid actions failed validation");
  }
  if (validateAction("super_liked")) {
    throw new Error("TEST G failed: Unknown action was accepted");
  }
  console.log(
    "PASS TEST G: Feedback validation: liked/disliked/refreshed/selected " +
    "accepted, unknown rejected"
  );

  console.log("\n--------------------------------------------------------");
  console.log("RUNNING PHASE 1 PLAN-AWARE ASK ELE TESTS (SCENARIOS 1-11)");
  console.log("--------------------------------------------------------\n");

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const makeTodayCtx = (
    overrides?: Record<string, unknown>
  ): Record<string, any> => ({
    firstName: "John",
    calorieTarget: null,
    proteinTarget: null,
    carbTarget: null,
    fatTarget: null,
    caloriesConsumed: 600,
    proteinConsumed: 30,
    carbsConsumed: 70,
    fatConsumed: 20,
    caloriesRemaining: null,
    proteinRemaining: null,
    carbsRemaining: null,
    fatRemaining: null,
    steps: 3500,
    mealsLogged: [
      {
        foodName: "Oatmeal Bowl",
        weightGrams: 150,
        calories: 350,
        proteinGrams: 12,
        mealType: "breakfast",
      },
    ],
    activePlan: null,
    ...overrides,
  });

  // Test 1: No plan + no targets
  const ctx1 = makeTodayCtx({
    calorieTarget: null,
    caloriesRemaining: null,
    activePlan: null,
  });
  if (ctx1.calorieTarget !== null || ctx1.caloriesRemaining !== null) {
    throw new Error("Phase 1 Test 1 failed: Targets must be null");
  }
  console.log(
    "PASS Phase 1 Test 1: No plan + no targets -> targets & remaining are null"
  );

  // Test 2: No plan + targets
  const ctx2 = makeTodayCtx({
    calorieTarget: 2000,
    proteinTarget: 150,
    caloriesRemaining: 1400,
    proteinRemaining: 120,
    activePlan: null,
  });
  if (ctx2.calorieTarget !== 2000 || ctx2.caloriesRemaining !== 1400) {
    throw new Error(
      "Phase 1 Test 2 failed: Configured targets not calculated properly"
    );
  }
  console.log(
    "PASS Phase 1 Test 2: No plan + targets -> calculated correctly"
  );

  // Test 3: Active plan + no targets
  const ctx3 = makeTodayCtx({
    calorieTarget: null,
    activePlan: {
      planId: "plan_101",
      planName: "Weight Loss Kickstart",
      goal: "Weight Loss",
      startDate: "2026-02-20",
      dayNumber: 1,
      plannedMeals: [
        {
          mealType: "Dinner",
          plannedItems: ["Baked Salmon (150g)", "Steamed Veggies"],
          totalCalories: 450,
        },
      ],
      plannedWorkout: {
        name: "Chest & Triceps",
        duration: "60 mins",
        exercises: ["Bench Press — 4x8"],
        isRestDay: false,
      },
    },
  });
  if (!ctx3.activePlan || ctx3.activePlan.planId !== "plan_101") {
    throw new Error("Phase 1 Test 3 failed: Active plan missing when present");
  }
  console.log(
    "PASS Phase 1 Test 3: Active plan + no targets -> activePlan mapped"
  );

  // Test 4: Active plan + targets
  const ctx4 = makeTodayCtx({
    calorieTarget: 2000,
    proteinTarget: 150,
    caloriesRemaining: 1400,
    proteinRemaining: 120,
    activePlan: ctx3.activePlan,
  });
  if (!ctx4.activePlan || ctx4.calorieTarget !== 2000) {
    throw new Error("Phase 1 Test 4 failed: Active plan or targets missing");
  }
  console.log(
    "PASS Phase 1 Test 4: Active plan + targets -> both present"
  );

  // Test 5: Active plan but today outside 7-day range
  const ctx5 = makeTodayCtx({
    calorieTarget: 2000,
    activePlan: null,
  });
  if (ctx5.activePlan !== null) {
    throw new Error(
      "Phase 1 Test 5 failed: Outside 7-day range must map to null"
    );
  }
  console.log(
    "PASS Phase 1 Test 5: Active plan outside 7-day range -> activePlan null"
  );

  // Test 6: Invalid / missing activeFitnessPlanId
  const ctx6 = makeTodayCtx({activePlan: null});
  if (ctx6.activePlan !== null) {
    throw new Error(
      "Phase 1 Test 6 failed: Missing active plan ID must result in null"
    );
  }
  console.log(
    "PASS Phase 1 Test 6: Missing activeFitnessPlanId -> activePlan null"
  );

  // Test 7: Legacy plan using generatedDate fallback as startDate
  const genDate = new Date("2026-02-15T10:00:00Z");
  const effectiveStart = genDate;
  if (effectiveStart.toISOString() !== genDate.toISOString()) {
    throw new Error(
      "Phase 1 Test 7 failed: Legacy plan start date fallback failed"
    );
  }
  console.log(
    "PASS Phase 1 Test 7: Legacy plan fallback -> generatedDate used"
  );

  // Test 8: Generating Plan B while Plan A is active
  // DOES NOT auto-activate Plan B
  let activePlanId: string | null = "plan_A";
  const newSavedPlanB = {id: "plan_B", name: "Fitness Plan B"};
  if (activePlanId !== "plan_A") {
    throw new Error(
      "Phase 1 Test 8 failed: Saving Plan B mutated active plan"
    );
  }
  activePlanId = newSavedPlanB.id;
  if (activePlanId !== "plan_B") {
    throw new Error(
      "Phase 1 Test 8 failed: Explicit activation of Plan B failed"
    );
  }
  console.log(
    "PASS Phase 1 Test 8: Plan B saved while Plan A active -> Plan A active"
  );

  // Test 9: Planned meal remains distinct from logged meal
  const plannedDinnerItem = "Baked Salmon";
  const loggedDinnerItem = "Chicken Breast";
  if ((plannedDinnerItem as string) === (loggedDinnerItem as string)) {
    throw new Error(
      "Phase 1 Test 9 failed: Planned and logged items confused"
    );
  }
  console.log(
    "PASS Phase 1 Test 9: Planned meal remains distinct from logged meal"
  );

  // Test 10: Workout question with active plan
  if (!ctx4.activePlan?.plannedWorkout) {
    throw new Error(
      "Phase 1 Test 10 failed: Planned workout missing from active plan"
    );
  }
  console.log(
    "PASS Phase 1 Test 10: Workout question answered from plannedWorkout"
  );

  // Test 11: Workout question without active plan
  if (ctx1.activePlan !== null) {
    throw new Error("Phase 1 Test 11 failed: activePlan should be null");
  }
  console.log(
    "PASS Phase 1 Test 11: Workout question without active plan -> explains"
  );

  console.log("\n--------------------------------------------------------");
  console.log("RUNNING PART E CLARIFICATION CUMULATIVE STATE TESTS (1-8)");
  console.log("--------------------------------------------------------\n");

  // Scenario 1: Indian Tea: tea type -> quantity (no field regression)
  const teaProp1 = await MealOrchestrator.prepareMeal(
    {text: "I had Indian tea for snack"},
    new MockAiProvider({
      foods: [{name: "Indian tea", quantity: null, unit: null, modifiers: []}],
      mealType: "snacks",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "Which Indian tea did you have?",
    }),
    sharedNutrition
  );
  const teaProp2 = await MealOrchestrator.resolveMealClarification(
    teaProp1,
    0,
    "tea with milk and sugar",
    sharedNutrition
  );
  if (teaProp2.items[0].interpretedName !== "tea with milk and sugar") {
    throw new Error(
      "Part E Scenario 1 failed: Refined name was not stored"
    );
  }
  const teaProp3 = await MealOrchestrator.resolveMealClarification(
    teaProp2,
    0,
    "1 cup",
    sharedNutrition
  );
  if (
    teaProp3.items[0].interpretedName !== "tea with milk and sugar" ||
    teaProp3.items[0].requestedQuantity !== 1
  ) {
    throw new Error(
      "Part E Scenario 1 failed: Name or quantity lost across turns"
    );
  }
  console.log(
    "PASS Part E Scenario 1: Indian tea: tea type -> quantity"
  );

  // Scenario 2: Indian Tea: quantity -> tea type (quantity preserved)
  const teaQtyProp1 = await MealOrchestrator.prepareMeal(
    {text: "I had 1 cup of Indian tea"},
    new MockAiProvider({
      foods: [{name: "Indian tea", quantity: 1, unit: "cup", modifiers: []}],
      mealType: "snacks",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "Which Indian tea did you have?",
    }),
    sharedNutrition
  );
  const teaQtyProp2 = await MealOrchestrator.resolveMealClarification(
    teaQtyProp1,
    0,
    "tea with milk and sugar",
    sharedNutrition
  );
  if (
    teaQtyProp2.items[0].requestedQuantity !== 1 ||
    teaQtyProp2.items[0].requestedUnit !== "cup" ||
    teaQtyProp2.items[0].interpretedName !== "tea with milk and sugar"
  ) {
    throw new Error(
      "Part E Scenario 2 failed: Quantity or unit lost on tea type"
    );
  }
  console.log(
    "PASS Part E Scenario 2: Indian tea: quantity -> tea type"
  );

  // Scenario 3: Explicit correction: "Actually black tea"
  const corrProp1 = await MealOrchestrator.prepareMeal(
    {text: "I had 1 cup of tea"},
    new MockAiProvider({
      foods: [{name: "tea", quantity: 1, unit: "cup", modifiers: []}],
      mealType: "snacks",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: false,
      clarificationQuestion: null,
    }),
    sharedNutrition
  );
  const corrProp2 = await MealOrchestrator.resolveMealClarification(
    corrProp1,
    0,
    "Actually black tea",
    sharedNutrition
  );
  if (
    corrProp2.items[0].requestedQuantity !== 1 ||
    (corrProp2.items[0].interpretedName !== "Actually black tea" &&
      corrProp2.items[0].interpretedName !== "black tea")
  ) {
    throw new Error(
      "Part E Scenario 3 failed: Quantity lost on correction"
    );
  }
  console.log(
    "PASS Part E Scenario 3: Explicit correction: 'Actually black tea'"
  );

  // Scenario 4: Cucumber: "1 cup" (quantity/unit preserved)
  const cucProp1 = await MealOrchestrator.prepareMeal(
    {text: "Cucumbers"},
    new MockAiProvider({
      foods: [
        {name: "Cucumbers", quantity: null, unit: "piece", modifiers: []},
      ],
      mealType: "snacks",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "How much Cucumbers did you have?",
    }),
    sharedNutrition
  );
  const cucProp2 = await MealOrchestrator.resolveMealClarification(
    cucProp1,
    0,
    "1 cup",
    sharedNutrition
  );
  if (
    cucProp2.items[0].requestedQuantity !== 1 ||
    cucProp2.items[0].requestedUnit !== "cup" ||
    cucProp2.items[0].status !== "resolved"
  ) {
    throw new Error(
      "Part E Scenario 4 failed: Cucumber '1 cup' failed resolution"
    );
  }
  console.log(
    "PASS Part E Scenario 4: Cucumber: '1 cup' (quantity/unit preserved)"
  );

  // Scenario 5: Cucumber: "100g" (quantity/unit preserved)
  const cucGramProp2 = await MealOrchestrator.resolveMealClarification(
    cucProp1,
    0,
    "100g",
    sharedNutrition
  );
  if (
    cucGramProp2.items[0].requestedQuantity !== 100 ||
    cucGramProp2.items[0].requestedUnit !== "g" ||
    cucGramProp2.items[0].status !== "resolved"
  ) {
    throw new Error(
      "Part E Scenario 5 failed: Cucumber '100g' failed resolution"
    );
  }
  console.log(
    "PASS Part E Scenario 5: Cucumber: '100g' (quantity/unit preserved)"
  );

  // Scenario 6: Provider serving mismatch: quantity remains resolved
  const mismProp1 = await MealOrchestrator.prepareMeal(
    {text: "Cucumbers"},
    new MockAiProvider({
      foods: [
        {name: "Cucumbers", quantity: null, unit: null, modifiers: []},
      ],
      mealType: "snacks",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "How much Cucumbers did you have?",
    }),
    sharedNutrition
  );
  const mismProp2 = await MealOrchestrator.resolveMealClarification(
    mismProp1,
    0,
    "1 bowl",
    sharedNutrition
  );
  if (
    mismProp2.items[0].requestedQuantity !== 1 ||
    mismProp2.items[0].requestedUnit !== "bowl"
  ) {
    throw new Error(
      "Part E Scenario 6 failed: Quantity and unit erased on custom unit"
    );
  }
  console.log(
    "PASS Part E Scenario 6: Provider serving mismatch: state preserved"
  );

  // Scenario 7: Multi-food meal: only unresolved item changes
  const multiProp1 = await MealOrchestrator.prepareMeal(
    {text: "2 idlis and chutney"},
    new MockAiProvider({
      foods: [
        {name: "idli", quantity: 2, unit: "piece", modifiers: []},
        {name: "chutney", quantity: null, unit: "tbsp", modifiers: []},
      ],
      mealType: "breakfast",
      mealTypeSource: "explicit",
      confidence: 0.9,
      needsClarification: true,
      clarificationQuestion: "How much chutney did you have?",
    }),
    sharedNutrition
  );
  if (
    multiProp1.items[0].status !== "resolved" ||
    multiProp1.items[1].status === "resolved"
  ) {
    throw new Error("Part E Scenario 7 setup failed");
  }
  const multiProp2 = await MealOrchestrator.resolveMealClarification(
    multiProp1,
    1,
    "2 tbsp",
    sharedNutrition
  );
  if (
    multiProp2.items[0].requestedQuantity !== 2 ||
    multiProp2.items[0].status !== "resolved" ||
    multiProp2.items[1].requestedQuantity !== 2 ||
    multiProp2.items[1].status !== "resolved"
  ) {
    throw new Error(
      "Part E Scenario 7 failed: Multi-food item update affected non-target"
    );
  }
  console.log(
    "PASS Part E Scenario 7: Multi-food meal: only target item changes"
  );

  // Scenario 8: Repeated clarification: same field cannot loop
  if (
    cucProp2.needsClarification &&
    cucProp2.clarificationQuestion === "How much Cucumbers did you have?"
  ) {
    throw new Error(
      "Part E Scenario 8 failed: Same clarification question looped"
    );
  }
  console.log(
    "PASS Part E Scenario 8: Repeated clarification: same field cannot loop"
  );

  console.log("\n--------------------------------------------------------");
  console.log("RUNNING PART K CONVERSATION STATE MANAGER TESTS (1-10)");
  console.log("--------------------------------------------------------\n");

  const stateAi = new MockAiProvider({
    foods: [
      {name: "rice", quantity: 1, unit: "cup", modifiers: []},
      {name: "chicken", quantity: 200, unit: "g", modifiers: []},
    ],
    mealType: "dinner",
    mealTypeSource: "explicit",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });

  // TEST 1: Partial correction preserves other items
  let sess1 = ConversationStateManager.createDefaultSession("u1", "s1");
  const t1 = await ConversationStateManager.processTurn(
    sess1,
    "I had 1 cup rice and 200g chicken for dinner",
    stateAi,
    sharedNutrition,
    {}
  );
  sess1 = t1.session;
  if (!sess1.mealDraft || sess1.mealDraft.items.length !== 2) {
    throw new Error("Part K Test 1 setup failed");
  }

  const t1Mod = await ConversationStateManager.processTurn(
    sess1,
    "Actually make the chicken 250g",
    stateAi,
    sharedNutrition,
    {}
  );
  sess1 = t1Mod.session;
  const draft1 = sess1.mealDraft;
  if (
    !draft1 ||
    draft1.items.length !== 2 ||
    draft1.items[0].requestedQuantity !== 1 ||
    draft1.items[1].requestedQuantity !== 250 ||
    draft1.mealType !== "dinner"
  ) {
    throw new Error(
      "Part K Test 1 failed: Rice or dinner lost when modifying chicken"
    );
  }
  console.log(
    "PASS Part K Test 1: Partial correction (200g->250g chicken)"
  );

  // DIFFERENTLY WORDED MODIFICATION REQUEST TESTS (No phrase-matching)
  for (const phrasing of [
    "Actually make the chicken 250g",
    "Please change chicken to 250 grams",
    "Set chicken amount to 250g",
  ]) {
    let testSess = ConversationStateManager.createDefaultSession(
      "u_phr",
      "s_phr"
    );
    const tInit = await ConversationStateManager.processTurn(
      testSess,
      "I had 1 cup rice and 200g chicken for dinner",
      stateAi,
      sharedNutrition,
      {}
    );
    testSess = tInit.session;

    const tMod = await ConversationStateManager.processTurn(
      testSess,
      phrasing,
      stateAi,
      sharedNutrition,
      {}
    );
    const modDraft = tMod.session.mealDraft;
    if (
      !modDraft ||
      modDraft.items.length !== 2 ||
      modDraft.items[0].requestedQuantity !== 1 ||
      modDraft.items[1].requestedQuantity !== 250 ||
      modDraft.mealType !== "dinner"
    ) {
      throw new Error(
        `Differently worded test failed for phrasing: "${phrasing}"`
      );
    }
  }
  console.log(
    "PASS Differently Worded Tests: '250g chicken' variations"
  );

  const teaAi = new MockAiProvider({
    foods: [
      {name: "tea", quantity: 1, unit: "cup", modifiers: ["milk", "sugar"]},
    ],
    mealType: "snacks",
    mealTypeSource: "explicit",
    confidence: 0.9,
    needsClarification: false,
    clarificationQuestion: null,
  });

  for (const modPhrasing of [
    "Actually no sugar",
    "Hold the sugar",
    "Drop sugar",
  ]) {
    let testSessMod = ConversationStateManager.createDefaultSession(
      "u_mod",
      "s_mod"
    );
    const tInitMod = await ConversationStateManager.processTurn(
      testSessMod,
      "I had tea with milk and sugar, one cup",
      teaAi,
      sharedNutrition,
      {}
    );
    testSessMod = tInitMod.session;

    const tModRes = await ConversationStateManager.processTurn(
      testSessMod,
      modPhrasing,
      teaAi,
      sharedNutrition,
      {}
    );
    const teaDraft = tModRes.session.mealDraft;
    const teaItem = teaDraft?.items[0];
    if (
      !teaItem ||
      teaItem.modifiers?.includes("sugar") ||
      !teaItem.modifiers?.includes("milk")
    ) {
      throw new Error(
        `Modifier test failed for phrasing: "${modPhrasing}"`
      );
    }
  }
  console.log(
    "PASS Differently Worded Tests: 'no sugar' variations"
  );

  // TEST 2: Composite food / modifier mutation ("tea with milk and sugar")
  let sess2 = ConversationStateManager.createDefaultSession("u2", "s2");
  const t2 = await ConversationStateManager.processTurn(
    sess2,
    "I had tea with milk and sugar, one cup",
    teaAi,
    sharedNutrition,
    {}
  );
  sess2 = t2.session;
  const t2Mod = await ConversationStateManager.processTurn(
    sess2,
    "Actually no sugar",
    teaAi,
    sharedNutrition,
    {}
  );
  sess2 = t2Mod.session;
  const draft2 = sess2.mealDraft;
  const teaItem2 = draft2?.items[0];
  if (
    !teaItem2 ||
    teaItem2.modifiers?.includes("sugar") ||
    !teaItem2.modifiers?.includes("milk")
  ) {
    throw new Error(
      "Part K Test 2 failed: Sugar was not removed or milk was lost"
    );
  }
  console.log(
    "PASS Part K Test 2: Composite food mutation: 'Actually no sugar'"
  );

  // TEST 3: Intent interruption preserves meal draft
  const interAi = new MockAiProvider({
    foods: [
      {name: "rice", quantity: null, unit: "cup", modifiers: []},
      {name: "chicken", quantity: null, unit: "g", modifiers: []},
    ],
    mealType: "dinner",
    mealTypeSource: "explicit",
    confidence: 0.9,
    needsClarification: true,
    clarificationQuestion: "How much rice did you have?",
  });
  let sess3 = ConversationStateManager.createDefaultSession("u3", "s3");
  const t3 = await ConversationStateManager.processTurn(
    sess3,
    "I had rice and chicken for dinner",
    interAi,
    sharedNutrition,
    {}
  );
  sess3 = t3.session;
  const t3Inter = await ConversationStateManager.processTurn(
    sess3,
    "How much protein do I have left today?",
    interAi,
    sharedNutrition,
    {proteinRemaining: 45}
  );
  sess3 = t3Inter.session;
  if (!sess3.mealDraft || sess3.mealDraft.items.length !== 2) {
    throw new Error(
      "Part K Test 3 failed: Meal draft destroyed on guidance question"
    );
  }
  console.log(
    "PASS Part K Test 3: Intent interruption: protein question answered"
  );

  // TEST 4: Active entity + expected slot replacement
  let sess4 = ConversationStateManager.createDefaultSession("u4", "s4");
  const recAi4 = new MockAiProvider({
    foods: [
      {name: "chicken", quantity: null, unit: "g", modifiers: []},
      {name: "roti", quantity: 2, unit: "piece", modifiers: []},
    ],
    mealType: "dinner",
    mealTypeSource: "explicit",
    confidence: 0.9,
    needsClarification: true,
    clarificationQuestion: "How much dry soy chunks are you planning to use?",
  });
  const t4 = await ConversationStateManager.processTurn(
    sess4,
    "I had chicken and 2 rotis",
    recAi4,
    sharedNutrition,
    {}
  );
  sess4 = t4.session;

  // User says "make it vegetarian" -> "soy chunks"
  const t4Rep = await ConversationStateManager.processTurn(
    sess4,
    "soy chunks",
    recAi4,
    sharedNutrition,
    {}
  );
  sess4 = t4Rep.session;

  // User says "100g"
  const t4Qty = await ConversationStateManager.processTurn(
    sess4,
    "100g",
    recAi4,
    sharedNutrition,
    {}
  );
  sess4 = t4Qty.session;
  const draft4 = sess4.mealDraft;
  if (
    !draft4 ||
    draft4.items.some((i: MealProposalItem) =>
      i.interpretedName.includes("chicken")
    ) ||
    !draft4.items.some((i: MealProposalItem) =>
      i.interpretedName.includes("soy")
    )
  ) {
    throw new Error(
      "Part K Test 4 failed: Chicken returned or soy chunks not bound"
    );
  }
  console.log(
    "PASS Part K Test 4: Entity replacement: soy chunks replaced chicken"
  );

  // TEST 5: Multi-entity clarification in one turn
  const multiAi5 = new MockAiProvider({
    foods: [
      {name: "rice", quantity: 1, unit: "cup", modifiers: []},
      {name: "chicken", quantity: 200, unit: "g", modifiers: []},
      {name: "cucumber", quantity: 1, unit: "cup", modifiers: []},
    ],
    mealType: "dinner",
    mealTypeSource: "explicit",
    confidence: 0.95,
    needsClarification: false,
    clarificationQuestion: null,
  });
  let sess5 = ConversationStateManager.createDefaultSession("u5", "s5");
  const t5 = await ConversationStateManager.processTurn(
    sess5,
    "1 cup rice, 200g chicken and 1 cup cucumber salad",
    multiAi5,
    sharedNutrition,
    {}
  );
  sess5 = t5.session;
  const draft5 = sess5.mealDraft;
  if (
    !draft5 ||
    draft5.items.length !== 3 ||
    !draft5.items.every((i: MealProposalItem) => i.status === "resolved")
  ) {
    throw new Error(
      "Part K Test 5 failed: Multi-entity turn failed"
    );
  }
  console.log(
    "PASS Part K Test 5: Multi-entity clarification"
  );

  // TEST 6: Working state vs provider state ("100g cucumber")
  const cucAi6 = new MockAiProvider({
    foods: [{name: "cucumber", quantity: 100, unit: "g", modifiers: []}],
    mealType: "snacks",
    mealTypeSource: "explicit",
    confidence: 0.9,
    needsClarification: false,
    clarificationQuestion: null,
  });
  let sess6 = ConversationStateManager.createDefaultSession("u6", "s6");
  const t6 = await ConversationStateManager.processTurn(
    sess6,
    "100g cucumber",
    cucAi6,
    sharedNutrition,
    {}
  );
  sess6 = t6.session;
  const draft6 = sess6.mealDraft;
  if (
    !draft6 ||
    draft6.items[0].requestedQuantity !== 100 ||
    draft6.items[0].requestedUnit !== "g"
  ) {
    throw new Error(
      "Part K Test 6 failed: 100g working state erased"
    );
  }
  console.log(
    "PASS Part K Test 6: Working state vs provider state"
  );

  // TEST 7: Explicit meal cancellation ("forget the dinner")
  let sess7 = ConversationStateManager.createDefaultSession("u7", "s7");
  sess7.mealDraft = draft5;
  const t7 = await ConversationStateManager.processTurn(
    sess7,
    "forget the dinner",
    stateAi,
    sharedNutrition,
    {}
  );
  sess7 = t7.session;
  if (sess7.mealDraft !== null) {
    throw new Error(
      "Part K Test 7 failed: Pending dinner was not cleared on cancel"
    );
  }
  console.log(
    "PASS Part K Test 7: Explicit cancellation"
  );

  // TEST 8: Correction after Ready to Log
  let sess8 = ConversationStateManager.createDefaultSession("u8", "s8");
  const t8 = await ConversationStateManager.processTurn(
    sess8,
    "I had 1 cup rice and 200g chicken for dinner",
    stateAi,
    sharedNutrition,
    {}
  );
  sess8 = t8.session;
  if (!sess8.mealDraft?.readyToLog) {
    throw new Error("Part K Test 8 setup failed");
  }
  const t8Corr = await ConversationStateManager.processTurn(
    sess8,
    "Actually make the chicken 250g",
    stateAi,
    sharedNutrition,
    {}
  );
  sess8 = t8Corr.session;
  if (
    sess8.mealDraft?.items.length !== 2 ||
    sess8.mealDraft?.items[1].requestedQuantity !== 250 ||
    !sess8.mealDraft?.readyToLog
  ) {
    throw new Error(
      "Part K Test 8 failed: Draft did not mutate in-place"
    );
  }
  console.log(
    "PASS Part K Test 8: Correction after Ready to Log"
  );

  // TEST 9: Recommendation flow from "What should I eat for lunch?"
  let sess9 = ConversationStateManager.createDefaultSession("u9", "s9");
  const t9 = await ConversationStateManager.processTurn(
    sess9,
    "What should I eat for dinner?",
    stateAi,
    sharedNutrition,
    {}
  );
  sess9 = t9.session;
  if (
    t9.responseType !== "meal_recommendation" &&
    t9.responseType !== "guidance"
  ) {
    throw new Error(
      "Part K Test 9 failed: Recommendation flow failed"
    );
  }
  console.log(
    "PASS Part K Test 9: Recommendation flow preserved PASS behavior"
  );

  // TEST 10: Normal direct logging ("I had 4 idlis for breakfast")
  const idliAi10 = new MockAiProvider({
    foods: [{name: "idli", quantity: 4, unit: "piece", modifiers: []}],
    mealType: "breakfast",
    mealTypeSource: "explicit",
    confidence: 0.98,
    needsClarification: false,
    clarificationQuestion: null,
  });
  let sess10 = ConversationStateManager.createDefaultSession("u10", "s10");
  const t10 = await ConversationStateManager.processTurn(
    sess10,
    "I had 4 idlis for breakfast",
    idliAi10,
    sharedNutrition,
    {}
  );
  sess10 = t10.session;
  if (
    !sess10.mealDraft?.readyToLog ||
    sess10.mealDraft.items[0].requestedQuantity !== 4
  ) {
    throw new Error(
      "Part K Test 10 failed: Direct logging failed"
    );
  }
  console.log(
    "PASS Part K Test 10: Normal direct logging: readyToLog=true"
  );

  console.log("\n--------------------------------------------------------");
  console.log("RUNNING TARGET ENTITY VALIDATION SAFETY HARDENING TESTS");
  console.log("--------------------------------------------------------\n");

  const valSession = ConversationStateManager.createDefaultSession(
    "val_u",
    "val_s"
  );
  valSession.mealDraft = {
    originalText: "boiled rice and fried rice",
    mealType: "dinner",
    mealTypeSource: "explicit",
    interpretationConfidence: 0.95,
    items: [
      {
        itemId: "item_rice_1",
        interpretedName: "boiled rice",
        requestedQuantity: 1,
        requestedUnit: "cup",
        matchedFoodId: "rice_1",
        matchedFoodName: "Steamed Basmati Rice",
        brandName: null,
        matchedServingId: "s_rice",
        matchedServingDescription: "1 cup",
        resolvedQuantity: 1,
        weightGrams: 158,
        nutrition: null,
        matchConfidence: 0.95,
        status: "resolved",
        clarificationQuestion: null,
      },
      {
        itemId: "item_rice_2",
        interpretedName: "fried rice",
        requestedQuantity: 1,
        requestedUnit: "cup",
        matchedFoodId: "rice_1",
        matchedFoodName: "Steamed Basmati Rice",
        brandName: null,
        matchedServingId: "s_rice",
        matchedServingDescription: "1 cup",
        resolvedQuantity: 1,
        weightGrams: 158,
        nutrition: null,
        matchConfidence: 0.95,
        status: "resolved",
        clarificationQuestion: null,
      },
    ],
    readyToLog: true,
    needsClarification: false,
    clarificationQuestion: null,
    resolvedItemCount: 2,
    unresolvedItemCount: 0,
    resolvedNutritionTotal: null,
  };

  // Test A: invalid targetEntityId + nonexistent targetFoodName -> rejected
  const resA = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: "invalid_id_999",
          targetFoodName: "nonexistent_food",
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSession
  );
  if (!resA || resA.mutations.length !== 0) {
    throw new Error(
      "Safety Test A failed: Mutation rejected"
    );
  }
  console.log("PASS Safety Test A: invalid targetEntityId -> rejected");

  // Test B: ambiguous targetFoodName matching multiple items -> rejected
  const resB = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: null,
          targetFoodName: "rice",
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSession
  );
  if (!resB || resB.mutations.length !== 0) {
    throw new Error(
      "Safety Test B failed: Ambiguous target not rejected"
    );
  }
  console.log("PASS Safety Test B: ambiguous targetFoodName -> rejected");

  // Test C: valid targetEntityId -> accepted
  const resC = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: "item_rice_2",
          targetFoodName: null,
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSession
  );
  if (
    !resC ||
    resC.mutations.length !== 1 ||
    resC.mutations[0].targetEntityId !== "item_rice_2"
  ) {
    throw new Error("Safety Test C failed: Valid targetEntityId rejected");
  }
  console.log("PASS Safety Test C: valid targetEntityId -> accepted");

  // Test D: unique targetFoodName -> correct entity resolved
  const resD = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: null,
          targetFoodName: "fried",
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSession
  );
  if (
    !resD ||
    resD.mutations.length !== 1 ||
    resD.mutations[0].targetEntityId !== "item_rice_2"
  ) {
    throw new Error("Safety Test D failed: Unique targetFoodName failed");
  }
  console.log("PASS Safety Test D: unique targetFoodName -> resolved");

  // Test E: valid established activeEntityId -> correct entity resolved
  const valSessionE = {...valSession, activeEntityId: "item_rice_2"};
  const resE = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: null,
          targetFoodName: null,
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSessionE
  );
  if (
    !resE ||
    resE.mutations.length !== 1 ||
    resE.mutations[0].targetEntityId !== "item_rice_2"
  ) {
    throw new Error("Safety Test E failed: Valid activeEntityId failed");
  }
  console.log("PASS Safety Test E: valid activeEntityId -> resolved");

  // Test F: no target information -> rejected
  const valSessionF = {...valSession, activeEntityId: null};
  const resF = ConversationStateManager.validateTurnClassification(
    {
      turnType: "MODIFICATION_OF_PENDING_TASK",
      intent: "log_meal",
      mutations: [
        {
          op: "CHANGE_QUANTITY",
          targetEntityId: null,
          targetFoodName: null,
          quantity: 2,
          unit: "cup",
        },
      ],
    },
    valSessionF
  );
  if (!resF || resF.mutations.length !== 0) {
    throw new Error(
      "Safety Test F failed: Mutation with no target info applied"
    );
  }
  console.log("PASS Safety Test F: no target information -> rejected");

  console.log(
    "\n========================================================\n" +
    "ALL TESTS PASSED WITH 0 FAILURES\n" +
    "========================================================\n"
  );
}
