import {
  ClassifyTurnInput,
  GetGuidanceInput,
  GetGuidanceOutput,
  InterpretMealInput,
  MealInterpretation,
} from "./types";
import {TurnClassificationResult} from "../ask-ele/types";

/**
 * Interface representing a provider-independent AI service adapter.
 */
export interface AiProvider {
  readonly name: string;

  /**
   * Interprets natural-language user text into structured meal intent.
   *
   * @param {InterpretMealInput} input - Text and context input.
   * @return {Promise<MealInterpretation>} Standardized structured result.
   */
  interpretMeal(
    input: InterpretMealInput
  ): Promise<MealInterpretation>;

  /**
   * Generates practical, context-aware daily guidance using EleFit user data.
   *
   * @param {GetGuidanceInput} input - Message, today's context, and UID.
   * @return {Promise<GetGuidanceOutput>} Guidance output with schema.
   */
  getGuidance(
    input: GetGuidanceInput
  ): Promise<GetGuidanceOutput>;

  /**
   * Classifies user turn into structured TurnClassificationResult & mutations.
   *
   * @param {ClassifyTurnInput} input - Message and active session state.
   * @return {Promise<TurnClassificationResult>} Classified turn result.
   */
  classifyTurnAndMutations?(
    input: ClassifyTurnInput
  ): Promise<TurnClassificationResult>;

  /**
   * Reranks candidate food search results semantically against target user food concept.
   *
   * @param {import("./types").RerankCandidatesInput} input - Food name and candidates.
   * @return {Promise<import("./types").RerankCandidatesOutput>} Reranked candidate evaluations.
   */
  rerankFoodCandidates?(
    input: import("./types").RerankCandidatesInput
  ): Promise<import("./types").RerankCandidatesOutput>;
}
