export interface FoodSearchResult {
  foodId: string;
  name: string;
  brandName?: string | null;
  description?: string | null;
  caloriesPer100g?: number | null;
  defaultServing?: string | null;
  imageUrl?: string | null;
  provider: string;
}

export interface SearchFoodsOptions {
  page?: number;
  maxResults?: number;
}

export interface NutritionData {
  calories: number | null;
  fat: number | null;
  carbs: number | null;
  protein: number | null;
  fiber: number | null;
  sugar: number | null;
  vitaminA: number | null;
  vitaminB1: number | null;
  vitaminB2: number | null;
  vitaminC: number | null;
  vitaminE: number | null;
  calcium: number | null;
  iron: number | null;
  magnesium: number | null;
  potassium: number | null;
  sodium: number | null;
  zinc: number | null;
  cholesterol: number | null;
  carotene: number | null;
  retinol: number | null;
}

export interface FoodServingResult {
  servingId: string;
  description: string;
  metricAmount?: number | null;
  metricUnit?: string | null;
  nutrition: NutritionData;
}

export interface FoodDetailsResult {
  foodId: string;
  name: string;
  brandName?: string | null;
  imageUrl?: string | null;
  servings: FoodServingResult[];
  provider: string;
}

export interface ResolvedFoodResult {
  foodId: string;
  name: string;
  brandName?: string | null;
  servingId: string;
  servingDescription: string;
  quantity: number;
  weightGrams?: number | null;
  nutrition: NutritionData;
  provider: string;
}
