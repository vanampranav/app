import {NutritionProvider} from "./nutrition-provider";
import {FatSecretProvider} from "./providers/fatsecret-provider";

/**
 * Factory to return the configured NutritionProvider.
 *
 * @param {string} consumerKey - FatSecret consumer key.
 * @param {string} consumerSecret - FatSecret consumer secret.
 * @return {NutritionProvider} The active NutritionProvider instance.
 */
export function getNutritionProvider(
  consumerKey: string,
  consumerSecret: string
): NutritionProvider {
  const providerName = (
    process.env.NUTRITION_PROVIDER || "fatsecret"
  ).toLowerCase();

  switch (providerName) {
  case "fatsecret":
  default:
    return new FatSecretProvider(consumerKey, consumerSecret);
  }
}
