import {ConversationSession} from "../ask-ele/types";

export type MealType = "breakfast" | "lunch" | "dinner" | "snacks";

export type MealTypeSource =
  | "explicit"
  | "context"
  | "time_inferred"
  | "unknown";

export interface InterpretedFood {
  name: string;
  quantity: number | null;
  unit: string | null;
  modifiers: string[];
}

export interface MealInterpretation {
  foods: InterpretedFood[];
  mealType: MealType | null;
  mealTypeSource: MealTypeSource;
  confidence: number;
  needsClarification: boolean;
  clarificationQuestion: string | null;
}

export interface InterpretMealInput {
  text: string;
  context?: {
    localHour?: number;
    suggestedMealType?: MealType | null;
  };
}

export interface RecommendationOptionInput {
  optionId: string;
  title: string;
  foods: string[];
}

export interface RecommendationContextInput {
  mealType: MealType;
  suggestedFoods?: string[];
  recommendationId?: string | null;
  selectedOptionId?: string | null;
  options?: RecommendationOptionInput[];
}

export interface GetGuidanceInput {
  message: string;
  todayContext: Record<string, unknown>;
  recommendationContext?: RecommendationContextInput | null;
  uid: string;
}

export interface MealRecommendationOption {
  optionId: string;
  title: string;
  foods: string[];
  rationale: string;
  estimatedCalories: number | null;
  estimatedProtein: number | null;
  estimatedCarbs: number | null;
  estimatedFat: number | null;
  confidence: number;
}

export interface MealRecommendationData {
  recommendationId: string;
  mealType: MealType;
  options: MealRecommendationOption[];
  suggestedFoods?: string[];
}

export type GuidanceResponseType =
  | "guidance"
  | "meal_recommendation"
  | "recommendation_followup";

export interface GetGuidanceOutput {
  responseType: GuidanceResponseType;
  responseText: string;
  recommendation: MealRecommendationData | null;
  preparedMealText?: string | null;
  suggestedMealType?: MealType | null;
}

export interface ClassifyTurnInput {
  message: string;
  session: ConversationSession;
}
