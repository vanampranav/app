import {
  FoodDetailsResult,
  FoodSearchResult,
  ResolvedFoodResult,
  SearchFoodsOptions,
} from "./types";

/**
 * Interface representing a provider-independent nutrition service adapter.
 */
export interface NutritionProvider {
  readonly name: string;

  /**
   * Searches for foods matching a query string.
   *
   * @param {string} query - Text query string.
   * @param {SearchFoodsOptions} [options] - Options for pagination.
   * @return {Promise<FoodSearchResult[]>} Standardized search results.
   */
  searchFoods(
    query: string,
    options?: SearchFoodsOptions
  ): Promise<FoodSearchResult[]>;

  /**
   * Retrieves full details and serving options for a specific food ID.
   *
   * @param {string} foodId - Provider or standardized food ID.
   * @return {Promise<FoodDetailsResult>} Standardized food details.
   */
  getFoodDetails(
    foodId: string
  ): Promise<FoodDetailsResult>;

  /**
   * Resolves scaled nutrition for a specific food, serving option,
   * and quantity.
   *
   * @param {string} foodId - Provider or standardized food ID.
   * @param {string} servingId - Selected serving option ID.
   * @param {number} quantity - Quantity multiplier (> 0).
   * @return {Promise<ResolvedFoodResult>} Standardized scaled food result.
   */
  resolveFood(
    foodId: string,
    servingId: string,
    quantity: number
  ): Promise<ResolvedFoodResult>;
}
