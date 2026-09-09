import {NutritionData} from "../nutrition/types";
import {
  MealType,
  MealTypeSource,
  RecommendationContextInput,
} from "../ai/types";

export type MealProposalItemStatus =
  | "resolved"
  | "needs_quantity"
  | "needs_serving"
  | "needs_food_match";

export interface MealProposalItem {
  itemId?: string;
  originalText?: string;
  interpretedName: string;
  modifiers?: string[];

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

  clarificationQuestion: string | null;
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

  resolvedItemCount: number;
  unresolvedItemCount: number;
  resolvedNutritionTotal: NutritionData | null;
}

export interface PrepareMealInput {
  text: string;
  localHour?: number;
  suggestedMealType?: MealType | null;
}

export type ActiveDomain =
  | "meal"
  | "guidance"
  | "recommendation"
  | "workout"
  | "general";

export type PendingAction =
  | "clarify_meal_item"
  | "confirm_meal_log"
  | "select_recommendation_option"
  | "none";

export interface PendingClarificationState {
  targetEntityId: string | null;
  targetFoodName?: string | null;
  question: string;
  expectedSlot: string | null;
}

export interface ConversationSession {
  sessionId: string;
  uid: string;

  activeIntent: string | null;
  activeDomain: ActiveDomain;
  pendingAction: PendingAction;

  activeEntityId: string | null;
  expectedSlot: string | null;

  pendingClarification: PendingClarificationState | null;

  mealDraft: MealProposal | null;
  recommendationContext: RecommendationContextInput | null;

  lastToolResult: Record<string, unknown> | null;
  lastResponseText?: string | null;

  updatedAt: number;
}

export type TurnType =
  | "ANSWER_TO_PENDING_CLARIFICATION"
  | "MODIFICATION_OF_PENDING_TASK"
  | "NEW_INTENT"
  | "CANCEL_PENDING_TASK"
  | "LOG_COMMAND"
  | "NEW_MEAL_LOG";

export type MutationOperation =
  | "ADD_ITEM"
  | "REMOVE_ITEM"
  | "REPLACE_ITEM"
  | "CHANGE_QUANTITY"
  | "CHANGE_UNIT"
  | "CHANGE_MEAL_TYPE"
  | "UPDATE_MODIFIERS"
  | "ANSWER_CLARIFICATION"
  | "NONE";

export interface StateMutation {
  op: MutationOperation;
  targetEntityId?: string | null;
  targetFoodName?: string | null;
  foodName?: string | null;
  quantity?: number | null;
  unit?: string | null;
  addModifiers?: string[];
  removeModifiers?: string[];
  mealType?: string | null;
}

export interface TurnClassificationResult {
  turnType: TurnType;
  intent: string | null;
  mutations: StateMutation[];
  newQueryText?: string | null;
}

