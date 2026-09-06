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

export interface GetGuidanceInput {
  message: string;
  todayContext: Record<string, unknown>;
  uid: string;
}
