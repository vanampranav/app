import * as logger from "firebase-functions/logger";
import {AiProvider} from "../ai-provider";
import {
  ClassifyTurnInput,
  GetGuidanceInput,
  GetGuidanceOutput,
  GuidanceResponseType,
  InterpretMealInput,
  MealInterpretation,
  MealRecommendationData,
  MealRecommendationOption,
  MealType,
  MealTypeSource,
  RerankCandidatesInput,
  RerankCandidatesOutput,
} from "../types";
import {
  StateMutation,
  TurnClassificationResult,
  TurnType,
} from "../../ask-ele/types";

/**
 * AiProvider implementation for OpenAI Chat Completions API with Structured Outputs.
 */
export class OpenAiProvider implements AiProvider {
  readonly name = "openai";

  /**
   * Creates an instance of OpenAiProvider.
   *
   * @param {string} apiKey - OpenAI API Key.
   */
  constructor(private readonly apiKey: string) {}

  /**
   * Helper to execute Chat Completion request with structured JSON Schema output.
   *
   * @param {string} instructions - System instructions.
   * @param {string} userPrompt - User message or context.
   * @param {string} schemaName - Name of the JSON schema.
   * @param {Record<string, unknown>} schema - JSON Schema object.
   * @return {Promise<Record<string, unknown>>} Parsed JSON response.
   */
  private async callChatCompletion(
    instructions: string,
    userPrompt: string,
    schemaName: string,
    schema: Record<string, unknown>
  ): Promise<Record<string, unknown>> {
    const model = process.env.ASK_ELE_MODEL || "gpt-4o-mini";

    const requestPayload = {
      model,
      messages: [
        {role: "system", content: instructions},
        {role: "user", content: userPrompt},
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: schemaName,
          strict: true,
          schema,
        },
      },
    };

    const response = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify(requestPayload),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(
        `OpenAI Chat Completion request failed: HTTP ${response.status} ${errorBody}`
      );
    }

    const json = (await response.json()) as {
      choices?: Array<{message?: {content?: string}}>;
    };

    const rawText = json.choices?.[0]?.message?.content;
    if (!rawText || !rawText.trim()) {
      throw new Error(
        "OpenAI API returned empty or missing content in choices"
      );
    }

    return JSON.parse(rawText) as Record<string, unknown>;
  }

  /**
   * Infers meal type based on local hour window (0-23).
   *
   * @param {number} hour - Local hour of the day.
   * @return {MealType | null} Inferred MealType or null if ambiguous.
   */
  private inferMealTypeFromHour(hour: number): MealType | null {
    if (hour >= 5 && hour <= 10) {
      return "breakfast";
    }
    if (hour >= 11 && hour <= 15) {
      return "lunch";
    }
    if (hour >= 17 && hour <= 21) {
      return "dinner";
    }
    return null;
  }

  /**
   * Interprets user text into structured meal intent using OpenAI API.
   *
   * @param {InterpretMealInput} input - Text and context input.
   * @return {Promise<MealInterpretation>} Standardized structured result.
   */
  async interpretMeal(
    input: InterpretMealInput
  ): Promise<MealInterpretation> {
    const userPrompt = input.text;
    const instructions =
      "You are the meal interpretation engine for EleFit.\n" +
      "Your job is to convert natural-language descriptions of " +
      "food consumption into structured meal intent.\n\n" +
      "Do NOT calculate calories or nutrition.\n" +
      "Do NOT fabricate nutrition facts.\n" +
      "Do NOT search external food databases.\n" +
      "Do NOT create MealEntry records.\n\n" +
      "Speech Transcription Food Normalization:\n" +
      "- Input text may come from voice transcripts with phonetic " +
      "speech errors (e.g. 'doll' for 'dal', 'samber' for 'sambar').\n" +
      "- Use meal and culinary context to recognize likely food errors.\n" +
      "- If context/confidence are high, normalize food name.\n" +
      "- If confidence is uncertain, set needsClarification = true " +
      "and set clarificationQuestion (e.g. 'Did you mean dal?').\n" +
      "- Never silently change a genuinely ambiguous word.\n\n" +
      "Extract:\n" +
      "- foods (name, quantity, unit, modifiers)\n" +
      "- mealType (breakfast, lunch, dinner, snacks, or null)\n" +
      "- mealTypeSource (explicit, context, time_inferred, unknown)\n" +
      "- confidence (0.0 to 1.0)\n" +
      "- needsClarification (true ONLY if food identity is unclear)\n" +
      "- clarificationQuestion (question if needsClarification)\n\n" +
      "Preserve culturally specific food names such as: idli, dosa, " +
      "dal, sambar, chutney, filter coffee, roti, upma, poha, biryani.\n" +
      "Do not convert them into generic western equivalents.\n\n" +
      "If quantity is not provided, use null.\n" +
      "If unit is not reasonably known, use null.\n" +
      "Do NOT invent cup sizes, gram weights, or default quantities.";

    const schema = {
      type: "object",
      properties: {
        foods: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: {type: "string"},
              quantity: {type: ["number", "null"]},
              unit: {type: ["string", "null"]},
              modifiers: {
                type: "array",
                items: {type: "string"},
              },
            },
            required: ["name", "quantity", "unit", "modifiers"],
            additionalProperties: false,
          },
        },
        mealType: {
          type: ["string", "null"],
          enum: ["breakfast", "lunch", "dinner", "snacks", null],
        },
        mealTypeSource: {
          type: "string",
          enum: ["explicit", "context", "time_inferred", "unknown"],
        },
        confidence: {type: "number"},
        needsClarification: {type: "boolean"},
        clarificationQuestion: {type: ["string", "null"]},
      },
      required: [
        "foods",
        "mealType",
        "mealTypeSource",
        "confidence",
        "needsClarification",
        "clarificationQuestion",
      ],
      additionalProperties: false,
    };

    const parsed = await this.callChatCompletion(
      instructions,
      userPrompt,
      "meal_interpretation",
      schema
    );

    // Strict model-output validation
    if (!Array.isArray(parsed.foods)) {
      throw new Error("Invalid AI model output: 'foods' must be an array");
    }

    const validatedFoods = parsed.foods.map((item, index) => {
      if (!item || typeof item !== "object") {
        throw new Error(
          `Invalid AI model output: 'foods[${index}]' must be an object`
        );
      }
      const f = item as Record<string, unknown>;

      if (typeof f.name !== "string" || !f.name.trim()) {
        throw new Error(
          `Invalid AI model output: 'foods[${index}].name' must be a string`
        );
      }

      if (
        f.quantity !== null &&
        (typeof f.quantity !== "number" || !isFinite(f.quantity))
      ) {
        throw new Error(
          `Invalid AI model output: 'foods[${index}].quantity' must be ` +
          "number/null"
        );
      }

      if (f.unit !== null && typeof f.unit !== "string") {
        throw new Error(
          `Invalid AI model output: 'foods[${index}].unit' must be string/null`
        );
      }

      if (!Array.isArray(f.modifiers)) {
        throw new Error(
          `Invalid AI model output: 'foods[${index}].modifiers' must be array`
        );
      }

      const modifiers = f.modifiers.map((m, mIdx) => {
        if (typeof m !== "string") {
          throw new Error(
            `Invalid AI model output: 'foods[${index}].modifiers[${mIdx}]' ` +
            "must be string"
          );
        }
        return m.trim();
      });

      return {
        name: f.name.trim(),
        quantity: f.quantity as number | null,
        unit: typeof f.unit === "string" ? f.unit.trim() : null,
        modifiers,
      };
    });

    const validMealTypes = ["breakfast", "lunch", "dinner", "snacks", null];
    if (!validMealTypes.includes(parsed.mealType as MealType | null)) {
      throw new Error("Invalid AI model output: 'mealType' is invalid");
    }

    const validSources = ["explicit", "context", "time_inferred", "unknown"];
    if (!validSources.includes(parsed.mealTypeSource as MealTypeSource)) {
      throw new Error("Invalid AI model output: 'mealTypeSource' is invalid");
    }

    if (
      typeof parsed.confidence !== "number" ||
      !isFinite(parsed.confidence) ||
      parsed.confidence < 0 ||
      parsed.confidence > 1
    ) {
      throw new Error("Invalid AI model output: 'confidence' is invalid");
    }

    if (typeof parsed.needsClarification !== "boolean") {
      throw new Error(
        "Invalid AI model output: 'needsClarification' is invalid"
      );
    }

    if (
      parsed.clarificationQuestion !== null &&
      typeof parsed.clarificationQuestion !== "string"
    ) {
      throw new Error(
        "Invalid AI model output: 'clarificationQuestion' is invalid"
      );
    }

    // Post-processing & Precedence Resolution for mealType
    let mealType = parsed.mealType as MealType | null;
    let mealTypeSource = parsed.mealTypeSource as MealTypeSource;

    if (mealType && mealTypeSource === "explicit") {
      // Keep explicit
    } else if (input.context?.suggestedMealType) {
      mealType = input.context.suggestedMealType;
      mealTypeSource = "context";
    } else if (input.context?.localHour !== undefined) {
      const inferred = this.inferMealTypeFromHour(input.context.localHour);
      if (inferred) {
        mealType = inferred;
        mealTypeSource = "time_inferred";
      } else if (!mealType) {
        mealType = null;
        mealTypeSource = "unknown";
      }
    } else if (!mealType) {
      mealType = null;
      mealTypeSource = "unknown";
    }

    logger.info("[DIAGNOSTIC] OpenAiProvider.interpretMeal output:", {
      foodCount: validatedFoods.length,
      foodNames: validatedFoods.map((f) => f.name),
      mealType,
      needsClarification: parsed.needsClarification,
    });

    return {
      foods: validatedFoods,
      mealType,
      mealTypeSource,
      confidence: parsed.confidence as number,
      needsClarification: parsed.needsClarification as boolean,
      clarificationQuestion: parsed.clarificationQuestion ?
        (parsed.clarificationQuestion as string).trim() :
        null,
    };
  }

  /**
   * Generates practical, context-aware daily guidance and recommendations.
   *
   * @param {GetGuidanceInput} input - Message, todayContext, and context.
   * @return {Promise<GetGuidanceOutput>} Guidance response object.
   */
  async getGuidance(input: GetGuidanceInput): Promise<GetGuidanceOutput> {
    const userPrompt =
      "User Question: \"" +
      input.message +
      "\"\n\n" +
      "User EleFit Context:\n" +
      JSON.stringify(input.todayContext, null, 2) +
      "\n\n" +
      "Active Recommendation Context:\n" +
      JSON.stringify(input.recommendationContext ?? null, null, 2);

    const instructions =
      "You are Ele, the AI fitness and nutrition coach for EleFit.\n" +
      "Your job is to provide clear, practical, personalized guidance " +
      "and structured 2-3 meal recommendation options based on the user's " +
      "real EleFit context.\n\n" +
      "TARGETS & PLAN CONTEXT RULES:\n" +
      "- WHEN TARGETS EXIST in TodayContext (calorieTarget/proteinTarget " +
      "non-null): Ele gives precise remaining-target guidance.\n" +
      "- WHEN TARGETS DO NOT EXIST (calorieTarget is null): Ele MUST NOT " +
      "invent a target or claim a precise amount remaining. Ele provides " +
      "general contextual guidance using available data (logged meals, " +
      "steps).\n" +
      "- PLANNED vs ACTUAL DISTINCTION: TodayContext may contain " +
      "'activePlan' with today's scheduled meals and workout. Never " +
      "claim that scheduled meals/workouts were consumed unless they " +
      "appear in 'mealsLogged'.\n" +
      "- WHEN USER ASKS 'What should I eat for dinner?':\n" +
      "  * WITH activePlan: Consider today's scheduled dinner first, " +
      "compare with actual meals logged today, consider remaining " +
      "targets if present, and recommend whether to follow or adjust.\n" +
      "  * WITHOUT activePlan: Use today's actual logs and targets to " +
      "offer recommendations.\n" +
      "- WHEN USER ASKS 'What workout do I have today?':\n" +
      "  * WITH activePlan & plannedWorkout: Answer from today's " +
      "planned workout (name, duration, exercises).\n" +
      "  * WITHOUT activePlan: State clearly that no active workout plan " +
      "is scheduled for today and offer general advice. Do NOT invent " +
      "a scheduled workout.\n\n" +
      "ROLES & BEHAVIORS:\n" +
      "1. MEAL RECOMMENDATIONS:\n" +
      "- When the user asks what to eat (e.g. 'What should I eat for " +
      "dinner?', 'What should I eat?', 'Any protein ideas?', " +
      "'What can I eat with 700 kcal left?'), analyze TodayContext " +
      "(calories remaining, protein remaining, logged meals, activePlan).\n" +
      "- Return EXACTLY 2 OR 3 meaningfully different, realistic meal " +
      "options in 'recommendation.options'. Do NOT return 1 option, and " +
      "do NOT return more than 3 options.\n" +
      "- Set responseType = 'meal_recommendation'.\n" +
      "- Populate 'recommendation' with { recommendationId, mealType, " +
      "options: [...] }.\n" +
      "- Each option must have: optionId (e.g. 'opt_1', 'opt_2', " +
      "'opt_3'), title, foods array, rationale, estimatedCalories, " +
      "estimatedProtein, estimatedCarbs, estimatedFat, confidence.\n" +
      "- If exact nutrition cannot be confidently estimated from " +
      "context, return null for estimated macros. " +
      "Do NOT invent fake precision.\n" +
      "- Keep responseText concise (1-2 sentences introducing options). " +
      "Do NOT output raw markdown formatting (no **, ##, ###, `).\n\n" +
      "2. RECOMMENDATION FOLLOW-UPS (SELECTION / ACCEPTANCE / " +
      "REFINEMENT):\n" +
      "- If active Recommendation Context is provided ({ mealType, " +
      "options }), and the user's message selects or references an " +
      "option (e.g. 'I'll take option 2', 'the paneer option', " +
      "'option 1', 'the second one', 'I'll do that one', 'I'll do " +
      "chicken and rice'):\n" +
      "  a) IF QUANTITIES ARE MISSING:\n" +
      "     - Identify the selected option's title/foods.\n" +
      "     - Ask a short, friendly clarification question asking for " +
      "quantities (e.g., 'You picked Paneer & Roti. How much paneer and " +
      "roti are you planning?').\n" +
      "     - Set responseType = 'recommendation_followup'.\n" +
      "     - Set preparedMealText = null.\n" +
      "  b) IF QUANTITIES ARE PROVIDED (e.g. '200 grams chicken and 150 " +
      "grams rice'):\n" +
      "     - Normalize the meal description with quantities and mealType " +
      "into preparedMealText (e.g. '200 grams chicken and 150 grams " +
      "rice for dinner').\n" +
      "     - Set suggestedMealType to the recommendation's mealType.\n" +
      "     - Set responseType = 'recommendation_followup'.\n" +
      "     - Set responseText = '' or a brief confirmation.\n\n" +
      "3. GENERAL GUIDANCE:\n" +
      "- If the user asks a general progress or guidance question (e.g. " +
      "'How am I doing today?', 'How much protein do I have left?', " +
      "'What workout do I have today?'):\n" +
      "- Set responseType = 'guidance'.\n" +
      "- Set recommendation = null.\n" +
      "- Answer directly using real values from TodayContext.\n\n" +
      "FORMATTING RULES:\n" +
      "- NO markdown syntax (no **, ##, ###, `).\n" +
      "- Short, clean lines separated by line breaks.\n" +
      "- Emojis for list items (🍗, 🍚, 🥦, 🔥, 💪, 👟).\n" +
      "- Keep responseText brief (2-3 lines max).";

    const schema = {
      type: "object",
      properties: {
        responseType: {
          type: "string",
          enum: [
            "guidance",
            "meal_recommendation",
            "recommendation_followup",
          ],
        },
        responseText: {type: "string"},
        recommendation: {
          type: ["object", "null"],
          properties: {
            recommendationId: {type: "string"},
            mealType: {
              type: "string",
              enum: ["breakfast", "lunch", "dinner", "snacks"],
            },
            options: {
              type: "array",
              minItems: 2,
              maxItems: 3,
              items: {
                type: "object",
                properties: {
                  optionId: {type: "string"},
                  title: {type: "string"},
                  foods: {
                    type: "array",
                    items: {type: "string"},
                  },
                  rationale: {type: "string"},
                  estimatedCalories: {type: ["number", "null"]},
                  estimatedProtein: {type: ["number", "null"]},
                  estimatedCarbs: {type: ["number", "null"]},
                  estimatedFat: {type: ["number", "null"]},
                  confidence: {type: "number"},
                },
                required: [
                  "optionId",
                  "title",
                  "foods",
                  "rationale",
                  "estimatedCalories",
                  "estimatedProtein",
                  "estimatedCarbs",
                  "estimatedFat",
                  "confidence",
                ],
                additionalProperties: false,
              },
            },
          },
          required: ["recommendationId", "mealType", "options"],
          additionalProperties: false,
        },
        preparedMealText: {type: ["string", "null"]},
        suggestedMealType: {
          type: ["string", "null"],
          enum: ["breakfast", "lunch", "dinner", "snacks", null],
        },
      },
      required: [
        "responseType",
        "responseText",
        "recommendation",
        "preparedMealText",
        "suggestedMealType",
      ],
      additionalProperties: false,
    };

    let parsed: Record<string, unknown>;
    try {
      parsed = await this.callChatCompletion(
        instructions,
        userPrompt,
        "guidance_response",
        schema
      );
    } catch {
      return {
        responseType: "guidance",
        responseText:
          "I couldn't generate guidance right now. " +
          "Try asking again in a moment.",
        recommendation: null,
        preparedMealText: null,
        suggestedMealType: null,
      };
    }

    const responseType =
      (parsed.responseType as GuidanceResponseType) || "guidance";
    const responseText = (parsed.responseText as string) || "";

    let recommendation: MealRecommendationData | null = null;
    if (parsed.recommendation && typeof parsed.recommendation === "object") {
      const recObj = parsed.recommendation as Record<string, unknown>;
      const rawOptions = Array.isArray(recObj.options) ? recObj.options : [];
      const optionsList: MealRecommendationOption[] = rawOptions.map(
        (opt: Record<string, unknown>, idx: number) => {
          const rawFoods = Array.isArray(opt.foods) ? opt.foods : [];
          return {
            optionId:
              typeof opt.optionId === "string" ?
                opt.optionId :
                `opt_${idx + 1}`,
            title: typeof opt.title === "string" ? opt.title : "Meal Option",
            foods: rawFoods.map((f) => String(f)),
            rationale: typeof opt.rationale === "string" ? opt.rationale : "",
            estimatedCalories:
              typeof opt.estimatedCalories === "number" ?
                opt.estimatedCalories :
                null,
            estimatedProtein:
              typeof opt.estimatedProtein === "number" ?
                opt.estimatedProtein :
                null,
            estimatedCarbs:
              typeof opt.estimatedCarbs === "number" ?
                opt.estimatedCarbs :
                null,
            estimatedFat:
              typeof opt.estimatedFat === "number" ?
                opt.estimatedFat :
                null,
            confidence:
              typeof opt.confidence === "number" ? opt.confidence : 0.9,
          };
        }
      );

      const validatedOptions = optionsList.slice(0, 3);
      const allSuggestedFoods: string[] = [];
      for (const opt of validatedOptions) {
        for (const f of opt.foods) {
          if (!allSuggestedFoods.includes(f)) {
            allSuggestedFoods.push(f);
          }
        }
      }

      recommendation = {
        recommendationId:
          typeof recObj.recommendationId === "string" ?
            recObj.recommendationId :
            `rec_${Date.now()}`,
        mealType: (recObj.mealType as MealType) || "dinner",
        options: validatedOptions,
        suggestedFoods: allSuggestedFoods,
      };
    }

    if (responseType === "meal_recommendation") {
      if (!recommendation || recommendation.options.length < 2) {
        return {
          responseType: "guidance",
          responseText:
            responseText.trim() ||
            "I have a few meal suggestions based on your targets. " +
            "Let me know what you'd like to eat!",
          recommendation: null,
          preparedMealText: null,
          suggestedMealType: null,
        };
      }
    }

    const preparedMealText =
      typeof parsed.preparedMealText === "string" &&
      parsed.preparedMealText.trim().length > 0 ?
        parsed.preparedMealText.trim() :
        null;

    const suggestedMealType =
      typeof parsed.suggestedMealType === "string" &&
      parsed.suggestedMealType.trim().length > 0 ?
        (parsed.suggestedMealType.trim() as MealType) :
        null;

    return {
      responseType,
      responseText: responseText.trim(),
      recommendation,
      preparedMealText,
      suggestedMealType,
    };
  }

  /**
   * Classifies user turn into structured TurnClassificationResult & mutations.
   *
   * @param {ClassifyTurnInput} input - Message and active session state.
   * @return {Promise<TurnClassificationResult>} Classified turn result.
   */
  async classifyTurnAndMutations(
    input: ClassifyTurnInput
  ): Promise<TurnClassificationResult> {
    const draftItems = input.session.mealDraft?.items || [];
    const pendingQ =
      input.session.pendingClarification?.question || "null";
    const expectedSlot = input.session.expectedSlot || "null";
    const activeEntityId = input.session.activeEntityId || "null";
    const currentMealType = input.session.mealDraft?.mealType || "null";

    const promptText =
      "Active Session State:\n" +
      `Domain: ${input.session.activeDomain}\n` +
      `Pending Action: ${input.session.pendingAction}\n` +
      `Active Entity ID: ${activeEntityId}\n` +
      `Expected Slot: ${expectedSlot}\n` +
      `Pending Question: ${pendingQ}\n` +
      `Current Meal Type: ${currentMealType}\n` +
      `Draft Items: ${JSON.stringify(
        draftItems.map((i) => ({
          itemId: i.itemId,
          name: i.interpretedName,
          quantity: i.requestedQuantity,
          unit: i.requestedUnit,
          status: i.status,
          modifiers: i.modifiers || [],
        })),
        null,
        2
      )}\n\n` +
      `User Message: "${input.message}"`;

    const instructions =
      "You are the conversation turn classifier for EleFit.\n" +
      "Classify the user message and output required state mutations based on Active Session State (expectedSlot, pendingQuestion, activeEntityId, currentMealType).\n\n" +
      "CRITICAL CLASSIFICATION RULE:\n" +
      "- A message describing a new meal or listing new foods consumed (e.g., 'I had soy chunks, rice, and dal', 'I ate chicken and salad', 'I had 2 rotis') MUST ALWAYS be classified as 'NEW_MEAL_LOG', regardless of whether there is a pending question, active entity, or expected slot.\n" +
      "- A turn is 'ANSWER_TO_PENDING_CLARIFICATION' or 'MODIFICATION_OF_PENDING_TASK' ONLY if it specifically answers or modifies the active pending question or item quantity/unit/meal_type (e.g. '2 tablespoons', 'about 50 grams', 'actually make it dinner', 'no chutney').\n\n" +
      "Semantic Intent Guidelines:\n" +
      "1. Questions asking for recommendations or information (e.g., 'what is my dinner today?', 'what should I eat for dinner?', 'how much protein left?') MUST be classified as 'NEW_INTENT'.\n" +
      "2. Statements describing new foods consumed or logging meals MUST be classified as 'NEW_MEAL_LOG'.\n" +
      "3. Corrections, changes, or additions to an existing pending proposal MUST be classified as 'MODIFICATION_OF_PENDING_TASK' or 'ANSWER_TO_PENDING_CLARIFICATION'.\n\n" +
      "turnType MUST be one of:\n" +
      "- 'NEW_MEAL_LOG' (logging a new meal or listing new foods consumed)\n" +
      "- 'ANSWER_TO_PENDING_CLARIFICATION' (answering a pending question/slot like quantity, meal_type, or food_identity)\n" +
      "- 'MODIFICATION_OF_PENDING_TASK' (modifying task/item or proposal mealType)\n" +
      "- 'NEW_INTENT' (asking progress/guidance question or meal recommendation)\n" +
      "- 'CANCEL_PENDING_TASK' (canceling/clearing current draft)\n" +
      "- 'LOG_COMMAND' (confirming/logging current draft)\n\n" +
      "mutations array ops:\n" +
      "- CHANGE_QUANTITY: { targetEntityId, quantity, unit }\n" +
      "- CHANGE_UNIT: { targetEntityId, unit }\n" +
      "- CHANGE_MEAL_TYPE: { mealType }\n" +
      "- UPDATE_MODIFIERS: { targetEntityId, addModifiers, removeModifiers }\n" +
      "- REPLACE_ITEM: { targetEntityId, foodName, quantity, unit }\n" +
      "- REMOVE_ITEM: { targetEntityId }\n" +
      "- ADD_ITEM: { foodName, quantity, unit }\n" +
      "- ANSWER_CLARIFICATION: { targetEntityId }\n";

    const schema = {
      type: "object",
      properties: {
        turnType: {
          type: "string",
          enum: [
            "ANSWER_TO_PENDING_CLARIFICATION",
            "MODIFICATION_OF_PENDING_TASK",
            "NEW_INTENT",
            "CANCEL_PENDING_TASK",
            "LOG_COMMAND",
            "NEW_MEAL_LOG",
          ],
        },
        intent: {type: ["string", "null"]},
        mutations: {
          type: "array",
          items: {
            type: "object",
            properties: {
              op: {
                type: "string",
                enum: [
                  "ADD_ITEM",
                  "REMOVE_ITEM",
                  "REPLACE_ITEM",
                  "CHANGE_QUANTITY",
                  "CHANGE_UNIT",
                  "CHANGE_MEAL_TYPE",
                  "UPDATE_MODIFIERS",
                  "ANSWER_CLARIFICATION",
                  "NONE",
                ],
              },
              targetEntityId: {type: ["string", "null"]},
              targetFoodName: {type: ["string", "null"]},
              foodName: {type: ["string", "null"]},
              quantity: {type: ["number", "null"]},
              unit: {type: ["string", "null"]},
              addModifiers: {
                type: "array",
                items: {type: "string"},
              },
              removeModifiers: {
                type: "array",
                items: {type: "string"},
              },
              mealType: {type: ["string", "null"]},
            },
            required: [
              "op",
              "targetEntityId",
              "targetFoodName",
              "foodName",
              "quantity",
              "unit",
              "addModifiers",
              "removeModifiers",
              "mealType",
            ],
            additionalProperties: false,
          },
        },
      },
      required: ["turnType", "intent", "mutations"],
      additionalProperties: false,
    };

    try {
      const parsed = await this.callChatCompletion(
        instructions,
        promptText,
        "turn_classification",
        schema
      );

      const tt = (parsed.turnType as TurnType) ||
        "ANSWER_TO_PENDING_CLARIFICATION";

      logger.info("[DIAGNOSTIC] OpenAiProvider.classifyTurnAndMutations output:", {
        turnType: tt,
        intent: (parsed.intent as string) || null,
        mutationsCount: Array.isArray(parsed.mutations) ? parsed.mutations.length : 0,
      });

      return {
        turnType: tt,
        intent: (parsed.intent as string) || null,
        mutations: (parsed.mutations as StateMutation[]) || [],
      };
    } catch (err) {
      logger.error("[DIAGNOSTIC] classifyTurnAndMutations Error:", err);
      return {
        turnType: "ANSWER_TO_PENDING_CLARIFICATION",
        intent: "log_meal",
        mutations: [],
      };
    }
  }

  /**
   * Reranks candidate food search results semantically against target user food concept.
   *
   * @param {RerankCandidatesInput} input - Food name and candidate items.
   * @return {Promise<RerankCandidatesOutput>} Reranked candidate evaluations.
   */
  async rerankFoodCandidates(
    input: RerankCandidatesInput
  ): Promise<RerankCandidatesOutput> {
    const userPrompt =
      `User Food Concept: "${input.foodName}"\n\n` +
      `Provider Search Candidates:\n` +
      JSON.stringify(input.candidates, null, 2);

    const instructions =
      "You are the semantic food candidate reranker for EleFit.\n" +
      "Your job is to evaluate how semantically equivalent each candidate food search result is to the user's intended food concept.\n\n" +
      "Evaluation Rules:\n" +
      "1. semanticScore (0.0 to 1.0):\n" +
      "   - 1.0: Exact same food concept (e.g. 'soy chunks' vs 'Soya Chunks', 'chickpeas' vs 'Garbanzo Beans', 'curd' vs 'Yogurt').\n" +
      "   - 0.8-0.95: Very close variant or regional synonym (e.g. 'coke' vs 'Coca-Cola', 'roti' vs 'Whole Wheat Roti').\n" +
      "   - 0.4-0.6: Related food item or product derived from the food, but distinct in form/macros (e.g. 'apple' vs 'Apple Juice' or 'Apple Pie', 'chicken' vs 'Chicken Breast' vs 'Chicken Wings').\n" +
      "   - 0.0-0.2: Fundamentally different food concept or product category (e.g. 'soy' vs 'Soy Milk' vs 'Soy Nuts', 'soy chunks' vs 'Pineapple Chunks').\n\n" +
      "2. isGeneric: Set true if this is a generic/unbranded food entry (e.g. 'Soya Chunks'), false if it is a specific commercial brand (e.g. 'Nutrela Soya Chunks').\n\n" +
      "3. userLabel: A concise, human-friendly label for UI selection chips (e.g. 'Regular Soya Chunks', 'Nutrela High-Protein Soya Chunks'). Do NOT include raw provider database IDs.";

    const schema = {
      type: "object",
      properties: {
        evaluations: {
          type: "array",
          items: {
            type: "object",
            properties: {
              foodId: {type: "string"},
              semanticScore: {type: "number"},
              isGeneric: {type: "boolean"},
              userLabel: {type: "string"},
            },
            required: ["foodId", "semanticScore", "isGeneric", "userLabel"],
            additionalProperties: false,
          },
        },
      },
      required: ["evaluations"],
      additionalProperties: false,
    };

    try {
      const parsed = await this.callChatCompletion(
        instructions,
        userPrompt,
        "food_candidate_reranking",
        schema
      );

      const rawEvals = Array.isArray(parsed.evaluations) ?
        parsed.evaluations :
        [];
      const evaluations = rawEvals.map((item) => {
        const ev = item as Record<string, unknown>;
        return {
          foodId: String(ev.foodId || ""),
          semanticScore:
            typeof ev.semanticScore === "number" && !isNaN(ev.semanticScore) ?
              Math.min(1.0, Math.max(0.0, ev.semanticScore)) :
              0.0,
          isGeneric: Boolean(ev.isGeneric),
          userLabel: typeof ev.userLabel === "string" ? ev.userLabel : "",
        };
      });

      return {evaluations};
    } catch (err) {
      logger.error("rerankFoodCandidates Error:", err);
      return {evaluations: []};
    }
  }
}
