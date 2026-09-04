import {NutritionData} from "../nutrition/types";
import {MealType, MealTypeSource} from "../ai/types";

export type MealProposalItemStatus =
  | "resolved"
  | "needs_quantity"
  | "needs_serving"
  | "needs_food_match";

export interface MealProposalItem {
  interpretedName: string;

  matchedFoodId: string | null;
  matchedFoodName: string | null;
  brandName: string | null;

  requestedQuantity: number | null;
  requestedUnit: string | null;

  matchedServingId: string | null;
  matchedServingDescription: string | null;

  resolvedQuantity: number | null;
  weightGrams: number | null;

  nutrition: NutritionData | null;

  matchConfidence: number;

  status: MealProposalItemStatus;
}

export interface MealProposal {
  originalText: string;

  mealType: MealType | null;
  mealTypeSource: MealTypeSource;

  interpretationConfidence: number;

  items: MealProposalItem[];

  readyToLog: boolean;

  needsClarification: boolean;

  clarificationQuestion: string | null;
}

export interface PrepareMealInput {
  text: string;
  localHour?: number;
  suggestedMealType?: MealType | null;
}
