import {InterpretMealInput, MealInterpretation} from "./types";

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
}
