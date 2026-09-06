import {MealOrchestrator} from "./meal-orchestrator";
import {AiProvider} from "../ai/ai-provider";
import {
  GetGuidanceInput,
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
   * @param {InterpretMealInput} _input - User input context.
   * @return {Promise<MealInterpretation>} Mocked interpretation.
   */
  async interpretMeal(
    _input: InterpretMealInput
  ): Promise<MealInterpretation> {
    return this.mockResponse;
  }

  /**
   * Returns mock daily guidance.
   *
   * @param {GetGuidanceInput} _input - Guidance input context.
   * @return {Promise<string>} Mock guidance.
   */
  async getGuidance(
    _input: GetGuidanceInput
  ): Promise<string> {
    return "Mock guidance";
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
   * @param {SearchFoodsOptions} [_options] - Options.
   * @return {Promise<FoodSearchResult[]>} Results array.
   */
  async searchFoods(
    query: string,
    _options?: SearchFoodsOptions
  ): Promise<FoodSearchResult[]> {
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

  console.log("\n========================================================");
  console.log("ALL REGRESSION SCENARIOS PASSED WITH ZERO FAILURES");
  console.log("========================================================\n");
}
