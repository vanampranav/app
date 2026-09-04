import {FatSecretProvider} from "./providers/fatsecret-provider";

/**
 * Runs offline unit tests for FatSecret result normalization.
 *
 * @return {void}
 */
export function runNormalizationTests(): void {
  const provider = new FatSecretProvider("dummy_key", "dummy_secret");

  // Test 1: Zero results
  const zeroResults = provider.normalizeFoodResults(null);
  if (zeroResults.length !== 0) {
    throw new Error("Zero results test failed");
  }

  // Test 2: Single result
  const singleRaw = {
    food_id: "12345",
    food_name: "Idli",
    food_description: "Per 100g - Calories: 150kcal | Fat: 1g | Carbs: 30g",
    servings: {
      serving: {
        metric_serving_amount: "100",
        metric_serving_unit: "g",
        calories: "150",
      },
    },
  };
  const singleResult = provider.normalizeFoodResults(singleRaw);
  if (
    singleResult.length !== 1 ||
    singleResult[0].foodId !== "12345" ||
    singleResult[0].name !== "Idli" ||
    singleResult[0].caloriesPer100g !== 150
  ) {
    throw new Error("Single result test failed");
  }

  // Test 3: Multiple results
  const multipleRaw = [
    {
      food_id: "101",
      food_name: "Dosa",
      servings: {
        serving: {
          metric_serving_amount: "100",
          metric_serving_unit: "g",
          calories: "200",
        },
      },
    },
    {
      food_id: "102",
      food_name: "Sambhar",
      servings: {
        serving: {
          metric_serving_amount: "100",
          metric_serving_unit: "g",
          calories: "80",
        },
      },
    },
  ];
  const multipleResults = provider.normalizeFoodResults(multipleRaw);
  if (
    multipleResults.length !== 2 ||
    multipleResults[0].foodId !== "101" ||
    multipleResults[1].foodId !== "102"
  ) {
    throw new Error("Multiple results test failed");
  }
}
