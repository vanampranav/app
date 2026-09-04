import * as crypto from "crypto";
import {NutritionProvider} from "../nutrition-provider";
import {
  FoodDetailsResult,
  FoodSearchResult,
  FoodServingResult,
  NutritionData,
  ResolvedFoodResult,
  SearchFoodsOptions,
} from "../types";

interface FatSecretServing {
  metric_serving_amount?: string | number;
  metric_serving_unit?: string;
  calories?: string | number;
  serving_description?: string;
}

interface FatSecretFood {
  food_id: string | number;
  food_name: string;
  brand_name?: string;
  food_description?: string;
  food_images?: {
    food_image?: Array<{image_url?: string}>;
  };
  servings?: {
    serving?: FatSecretServing | FatSecretServing[];
  };
}

/**
 * NutritionProvider implementation for the FatSecret Platform REST API.
 */
export class FatSecretProvider implements NutritionProvider {
  readonly name = "fatsecret";
  private readonly baseUrl = "https://platform.fatsecret.com/rest/server.api";

  /**
   * Creates an instance of FatSecretProvider.
   *
   * @param {string} consumerKey - FatSecret OAuth consumer key.
   * @param {string} consumerSecret - FatSecret OAuth consumer secret.
   */
  constructor(
    private readonly consumerKey: string,
    private readonly consumerSecret: string
  ) {}

  /**
   * Encodes a string according to RFC 3986.
   *
   * @param {string} str - Input string to encode.
   * @return {string} RFC 3986 encoded string.
   */
  private rfc3986Encode(str: string): string {
    return encodeURIComponent(str).replace(
      /[!'()*]/g,
      (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`
    );
  }

  /**
   * Generates a random hex nonce for OAuth 1.0a.
   *
   * @return {string} Hex nonce string.
   */
  private generateNonce(): string {
    return crypto.randomBytes(16).toString("hex");
  }

  /**
   * Generates an OAuth 1.0a HMAC-SHA1 signature.
   *
   * @param {string} method - HTTP method (GET / POST).
   * @param {string} url - Base URL.
   * @param {Record<string, string>} params - Parameter key-value pairs.
   * @return {string} Base64 encoded OAuth signature.
   */
  private generateOAuthSignature(
    method: string,
    url: string,
    params: Record<string, string>
  ): string {
    const sortedKeys = Object.keys(params).sort();
    const paramString = sortedKeys
      .map(
        (k) =>
          `${this.rfc3986Encode(k)}=${this.rfc3986Encode(params[k])}`
      )
      .join("&");

    const signatureBaseString = `${method.toUpperCase()}&${this.rfc3986Encode(
      url
    )}&${this.rfc3986Encode(paramString)}`;

    const signingKey = `${this.rfc3986Encode(this.consumerSecret)}&`;

    const hmac = crypto.createHmac("sha1", signingKey);
    hmac.update(signatureBaseString);
    return hmac.digest("base64");
  }

  /**
   * Parses a nutrient value from a serving map, preserving null when missing.
   *
   * @param {Record<string, unknown>} s - Serving object map.
   * @param {string} key - Nutrient property key.
   * @return {number | null} Parsed numeric value or null.
   */
  private parseNutrientVal(
    s: Record<string, unknown>,
    key: string
  ): number | null {
    const val = s[key];
    if (val === undefined || val === null || val === "") {
      return null;
    }
    const num = Number(val);
    return isNaN(num) ? null : num;
  }

  /**
   * Scales a nutrient value by quantity multiplier, preserving null.
   *
   * @param {number | null} val - Base nutrient value or null.
   * @param {number} qty - Quantity multiplier.
   * @return {number | null} Scaled nutrient value rounded to 2
   *     decimals or null.
   */
  private scaleNutrient(val: number | null, qty: number): number | null {
    if (val === null || val === undefined) {
      return null;
    }
    return Math.round((val * qty + Number.EPSILON) * 100) / 100;
  }

  /**
   * Normalizes raw FatSecret JSON food items into FoodSearchResult objects.
   *
   * @param {unknown} rawFoods - Raw food payload from FatSecret API.
   * @return {FoodSearchResult[]} Standardized FoodSearchResult array.
   */
  normalizeFoodResults(rawFoods: unknown): FoodSearchResult[] {
    if (!rawFoods) {
      return [];
    }

    const foodList: FatSecretFood[] = Array.isArray(rawFoods) ?
      (rawFoods as FatSecretFood[]) :
      [rawFoods as FatSecretFood];

    return foodList.map((food) => {
      let caloriesPer100g: number | null = null;
      let defaultServing: string | null = "100g";

      if (food.servings?.serving) {
        const rawServings = Array.isArray(food.servings.serving) ?
          food.servings.serving :
          [food.servings.serving];

        let chosenMetric: FatSecretServing | null = null;
        for (const s of rawServings) {
          if (
            s &&
            (s.metric_serving_unit === "g" || s.metric_serving_unit === "ml")
          ) {
            chosenMetric = s;
            break;
          }
        }

        const chosen = chosenMetric || rawServings[0];
        if (chosen) {
          const cal = Number(chosen.calories || 0);
          const amt = Number(chosen.metric_serving_amount || 0);
          const unit = String(chosen.metric_serving_unit || "");

          if (cal > 0 && amt > 0 && (unit === "g" || unit === "ml")) {
            caloriesPer100g = Math.round((cal / amt) * 100);
            defaultServing = `100${unit}`;
          } else if (cal > 0) {
            caloriesPer100g = Math.round(cal);
            defaultServing = chosen.serving_description || "1 serving";
          }
        }
      }

      if (caloriesPer100g === null && food.food_description) {
        const calorieMatch = /Cal(?:ories)?: \s*([\d.,]+)/i.exec(
          food.food_description
        );
        if (calorieMatch) {
          const rawCal = calorieMatch[1].replace(/,/g, "");
          const calNum = Number(rawCal);
          if (!isNaN(calNum)) {
            caloriesPer100g = Math.round(calNum);
          }
        }
        const servingMatch = /Per\s+(.+?)\s*-/i.exec(food.food_description);
        if (servingMatch) {
          defaultServing = servingMatch[1].trim();
        }
      }

      let imageUrl: string | null = null;
      if (
        food.food_images?.food_image &&
        food.food_images.food_image.length > 0
      ) {
        imageUrl = food.food_images.food_image[0].image_url || null;
      }

      return {
        foodId: String(food.food_id),
        name: food.food_name || "Unknown Food",
        brandName: food.brand_name || null,
        description: food.food_description || null,
        caloriesPer100g,
        defaultServing,
        imageUrl,
        provider: this.name,
      };
    });
  }

  /**
   * Normalizes raw FatSecret detailed food object into FoodDetailsResult.
   *
   * @param {unknown} rawFood - Raw food details payload from FatSecret API.
   * @return {FoodDetailsResult} Standardized FoodDetailsResult object.
   */
  normalizeFoodDetails(rawFood: unknown): FoodDetailsResult {
    const food = (rawFood || {}) as Record<string, unknown>;

    let imageUrl: string | null = null;
    const foodImages = food.food_images as
      | {food_image?: Array<{image_url?: string}>}
      | undefined;
    if (foodImages?.food_image && foodImages.food_image.length > 0) {
      imageUrl = foodImages.food_image[0].image_url || null;
    }

    const rawServingsObj = food.servings as
      | {serving?: Record<string, unknown> | Array<Record<string, unknown>>}
      | undefined;

    const rawServings = rawServingsObj?.serving;
    const servingList: Array<Record<string, unknown>> = Array.isArray(
      rawServings
    ) ?
      rawServings :
      (rawServings ? [rawServings] : []);

    const servings: FoodServingResult[] = servingList.map((s) => {
      const metricAmountRaw = s.metric_serving_amount;
      const metricAmount =
        metricAmountRaw !== undefined && metricAmountRaw !== null ?
          Number(metricAmountRaw) :
          null;

      return {
        servingId: String(s.serving_id || "0"),
        description: String(s.serving_description || "1 serving"),
        metricAmount: isNaN(metricAmount as number) ? null : metricAmount,
        metricUnit:
          s.metric_serving_unit ? String(s.metric_serving_unit) : null,
        nutrition: {
          calories: this.parseNutrientVal(s, "calories"),
          fat: this.parseNutrientVal(s, "fat"),
          carbs: this.parseNutrientVal(s, "carbohydrate"),
          protein: this.parseNutrientVal(s, "protein"),
          fiber: this.parseNutrientVal(s, "fiber"),
          sugar: this.parseNutrientVal(s, "sugar"),
          vitaminA: this.parseNutrientVal(s, "vitamin_a"),
          vitaminB1: this.parseNutrientVal(s, "vitamin_b1"),
          vitaminB2: this.parseNutrientVal(s, "vitamin_b2"),
          vitaminC: this.parseNutrientVal(s, "vitamin_c"),
          vitaminE: this.parseNutrientVal(s, "vitamin_e"),
          calcium: this.parseNutrientVal(s, "calcium"),
          iron: this.parseNutrientVal(s, "iron"),
          magnesium: this.parseNutrientVal(s, "magnesium"),
          potassium: this.parseNutrientVal(s, "potassium"),
          sodium: this.parseNutrientVal(s, "sodium"),
          zinc: this.parseNutrientVal(s, "zinc"),
          cholesterol: this.parseNutrientVal(s, "cholesterol"),
          carotene: this.parseNutrientVal(s, "carotene"),
          retinol: this.parseNutrientVal(s, "retinol"),
        },
      };
    });

    return {
      foodId: String(food.food_id || ""),
      name: String(food.food_name || "Unknown Food"),
      brandName: food.brand_name ? String(food.brand_name) : null,
      imageUrl,
      servings,
      provider: this.name,
    };
  }

  /**
   * Searches FatSecret for food items matching a query string.
   *
   * @param {string} query - Text query (e.g. "Chicken").
   * @param {SearchFoodsOptions} [options] - Options for page and maxResults.
   * @return {Promise<FoodSearchResult[]>} Standardized search results array.
   */
  async searchFoods(
    query: string,
    options?: SearchFoodsOptions
  ): Promise<FoodSearchResult[]> {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const nonce = this.generateNonce();

    const oauthParams: Record<string, string> = {
      oauth_consumer_key: this.consumerKey,
      oauth_signature_method: "HMAC-SHA1",
      oauth_timestamp: timestamp,
      oauth_nonce: nonce,
      oauth_version: "1.0",
      format: "json",
    };

    const methodParams: Record<string, string> = {
      method: "foods.search.v3",
      search_expression: query,
      max_results: options?.maxResults ? String(options.maxResults) : "20",
      include_food_images: "1",
    };

    if (options?.page !== undefined) {
      methodParams.page_number = String(options.page);
    }

    const allParams = {...oauthParams, ...methodParams};
    const signature = this.generateOAuthSignature(
      "GET",
      this.baseUrl,
      allParams
    );
    allParams.oauth_signature = signature;

    const queryParams = new URLSearchParams(allParams).toString();
    const requestUrl = `${this.baseUrl}?${queryParams}`;

    const response = await fetch(requestUrl);
    if (!response.ok) {
      throw new Error(`FatSecret API returned HTTP ${response.status}`);
    }

    const json = (await response.json()) as Record<string, unknown>;
    const foodsSearch = json.foods_search as
      | {results?: {food?: unknown}}
      | undefined;
    const rawFoods = foodsSearch?.results?.food;

    return this.normalizeFoodResults(rawFoods);
  }

  /**
   * Retrieves detailed food and serving information by food ID.
   *
   * @param {string} foodId - FatSecret food ID.
   * @return {Promise<FoodDetailsResult>} Standardized FoodDetailsResult.
   */
  async getFoodDetails(foodId: string): Promise<FoodDetailsResult> {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const nonce = this.generateNonce();

    const oauthParams: Record<string, string> = {
      oauth_consumer_key: this.consumerKey,
      oauth_signature_method: "HMAC-SHA1",
      oauth_timestamp: timestamp,
      oauth_nonce: nonce,
      oauth_version: "1.0",
      format: "json",
    };

    const methodParams: Record<string, string> = {
      method: "food.get.v4",
      food_id: foodId,
    };

    const allParams = {...oauthParams, ...methodParams};
    const signature = this.generateOAuthSignature(
      "GET",
      this.baseUrl,
      allParams
    );
    allParams.oauth_signature = signature;

    const queryParams = new URLSearchParams(allParams).toString();
    const requestUrl = `${this.baseUrl}?${queryParams}`;

    const response = await fetch(requestUrl);
    if (!response.ok) {
      throw new Error(`FatSecret API returned HTTP ${response.status}`);
    }

    const json = (await response.json()) as Record<string, unknown>;
    const rawFood = json.food;
    if (!rawFood) {
      throw new Error(`Food with ID '${foodId}' not found`);
    }

    return this.normalizeFoodDetails(rawFood);
  }

  /**
   * Resolves scaled nutrition for a specific food, serving option,
   * and quantity. Reuses getFoodDetails(foodId).
   *
   * @param {string} foodId - FatSecret food ID.
   * @param {string} servingId - Serving ID to select and scale.
   * @param {number} quantity - Multiplier quantity (> 0).
   * @return {Promise<ResolvedFoodResult>} Standardized scaled food result.
   */
  async resolveFood(
    foodId: string,
    servingId: string,
    quantity: number
  ): Promise<ResolvedFoodResult> {
    const details = await this.getFoodDetails(foodId);

    const serving = details.servings.find((s) => s.servingId === servingId);
    if (!serving) {
      throw new Error(
        `Serving with ID '${servingId}' not found for food '${foodId}'`
      );
    }

    let weightGrams: number | null = null;
    if (
      serving.metricUnit === "g" &&
      typeof serving.metricAmount === "number" &&
      !isNaN(serving.metricAmount)
    ) {
      weightGrams =
        Math.round((serving.metricAmount * quantity + Number.EPSILON) * 100) /
        100;
    }

    const n = serving.nutrition;
    const scaledNutrition: NutritionData = {
      calories: this.scaleNutrient(n.calories, quantity),
      fat: this.scaleNutrient(n.fat, quantity),
      carbs: this.scaleNutrient(n.carbs, quantity),
      protein: this.scaleNutrient(n.protein, quantity),
      fiber: this.scaleNutrient(n.fiber, quantity),
      sugar: this.scaleNutrient(n.sugar, quantity),
      vitaminA: this.scaleNutrient(n.vitaminA, quantity),
      vitaminB1: this.scaleNutrient(n.vitaminB1, quantity),
      vitaminB2: this.scaleNutrient(n.vitaminB2, quantity),
      vitaminC: this.scaleNutrient(n.vitaminC, quantity),
      vitaminE: this.scaleNutrient(n.vitaminE, quantity),
      calcium: this.scaleNutrient(n.calcium, quantity),
      iron: this.scaleNutrient(n.iron, quantity),
      magnesium: this.scaleNutrient(n.magnesium, quantity),
      potassium: this.scaleNutrient(n.potassium, quantity),
      sodium: this.scaleNutrient(n.sodium, quantity),
      zinc: this.scaleNutrient(n.zinc, quantity),
      cholesterol: this.scaleNutrient(n.cholesterol, quantity),
      carotene: this.scaleNutrient(n.carotene, quantity),
      retinol: this.scaleNutrient(n.retinol, quantity),
    };

    return {
      foodId: details.foodId,
      name: details.name,
      brandName: details.brandName || null,
      servingId: serving.servingId,
      servingDescription: serving.description,
      quantity,
      weightGrams,
      nutrition: scaledNutrition,
      provider: this.name,
    };
  }
}
