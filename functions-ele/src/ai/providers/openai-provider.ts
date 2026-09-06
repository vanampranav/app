import {AiProvider} from "../ai-provider";
import {
  GetGuidanceInput,
  InterpretMealInput,
  MealInterpretation,
  MealType,
  MealTypeSource,
} from "../types";

/**
 * AiProvider implementation for OpenAI Responses API.
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
   * Interprets user text into structured meal intent using OpenAI
   * Responses API.
   *
   * @param {InterpretMealInput} input - Text and context input.
   * @return {Promise<MealInterpretation>} Standardized structured result.
   */
  async interpretMeal(
    input: InterpretMealInput
  ): Promise<MealInterpretation> {
    const model = process.env.ASK_ELE_MODEL || "gpt-5.6-luna";
    const userPrompt = input.text;

    const requestPayload = {
      model,
      instructions:
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
        "Do NOT invent cup sizes, gram weights, or default quantities.",
      input: [
        {
          role: "user",
          content: userPrompt,
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "meal_interpretation",
          strict: true,
          schema: {
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
          },
        },
      },
    };

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(requestPayload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      let safeMessage = `HTTP ${response.status}`;

      try {
        const parsedError = JSON.parse(errorBody) as {
          error?: {
            type?: string;
            code?: string;
            param?: string;
            message?: string;
          };
        };
        const err = parsedError?.error;

        if (err) {
          safeMessage +=
            ` type=${err.type ?? "unknown"}` +
            ` code=${err.code ?? "unknown"}` +
            ` param=${err.param ?? "unknown"}` +
            ` message=${err.message ?? "unknown"}`;
        } else {
          safeMessage += ` ${response.statusText}`;
        }
      } catch {
        safeMessage += ` ${response.statusText}`;
      }

      throw new Error(
        `OpenAI Responses API request failed: ${safeMessage}`
      );
    }

    const json = (await response.json()) as Record<string, unknown>;

    if (json.status === "failed") {
      throw new Error("OpenAI Responses API response status: failed");
    }

    let rawJsonText: string | null = null;

    if (typeof json.output_text === "string" && json.output_text.trim()) {
      rawJsonText = json.output_text;
    } else if (Array.isArray(json.output)) {
      for (const item of json.output) {
        if (!item || typeof item !== "object") {
          continue;
        }
        const obj = item as Record<string, unknown>;

        if (typeof obj.output_text === "string" && obj.output_text.trim()) {
          rawJsonText = obj.output_text;
          break;
        }

        if (obj.type === "message" && Array.isArray(obj.content)) {
          for (const c of obj.content) {
            if (!c || typeof c !== "object") {
              continue;
            }
            const cObj = c as Record<string, unknown>;
            if (
              (cObj.type === "text" || cObj.type === "output_text") &&
              typeof cObj.text === "string" &&
              cObj.text.trim()
            ) {
              rawJsonText = cObj.text;
              break;
            }
          }
        } else if (
          (obj.type === "text" || obj.type === "output_text") &&
          typeof obj.text === "string" &&
          obj.text.trim()
        ) {
          rawJsonText = obj.text;
          break;
        }

        if (rawJsonText) {
          break;
        }
      }
    }

    if (!rawJsonText) {
      throw new Error(
        "OpenAI Responses API returned empty or missing text output"
      );
    }

    let parsedRaw: unknown;
    try {
      parsedRaw = JSON.parse(rawJsonText);
    } catch {
      throw new Error("Failed to parse JSON from AI model response");
    }

    if (!parsedRaw || typeof parsedRaw !== "object") {
      throw new Error("AI model response is not a valid JSON object");
    }

    const parsed = parsedRaw as Record<string, unknown>;

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
      throw new Error(
        "Invalid AI model output: 'confidence' is invalid"
      );
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

    // 1. Explicit language from model/user takes highest priority
    if (mealType && mealTypeSource === "explicit") {
      // Keep explicit
    } else if (input.context?.suggestedMealType) {
      // 2. Suggested meal type from context
      mealType = input.context.suggestedMealType;
      mealTypeSource = "context";
    } else if (input.context?.localHour !== undefined) {
      // 3. Time inference fallback
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
   * Generates practical, context-aware daily guidance using EleFit user data.
   *
   * @param {GetGuidanceInput} input - Message and structured todayContext.
   * @return {Promise<string>} Guidance response text.
   */
  async getGuidance(input: GetGuidanceInput): Promise<string> {
    const model = process.env.ASK_ELE_MODEL || "gpt-5.6-luna";
    const userPrompt =
      "User Question: \"" +
      input.message +
      "\"\n\n" +
      "User EleFit Context:\n" +
      JSON.stringify(input.todayContext, null, 2);

    const requestPayload = {
      model,
      instructions:
        "You are Ele, the AI fitness assistant for EleFit.\n" +
        "Your job is to provide clear, practical, personalized daily " +
        "fitness and nutrition guidance based on the user's real " +
        "EleFit context.\n\n" +
        "Formatting & Presentation Rules:\n" +
        "- Do NOT output markdown markers like **, ##, ###, or `.\n" +
        "- Format responses using short, clean, scannable lines separated " +
        "by line breaks.\n" +
        "- When presenting daily stats, put metrics on separate lines " +
        "with clean emojis (e.g. 🔥 953 / 2,737 kcal, " +
        "💪 26 / 149g protein, 👟 2,862 steps).\n" +
        "- When giving meal ideas, present them as clean " +
        "scannable lists\n" +
        "(e.g. 🍗 Chicken, 🍚 Rice, 🥦 Veggies).\n" +
        "- Keep paragraphs short (2-5 brief blocks max).\n\n" +
        "Principles:\n" +
        "- Answer the user's question directly and first.\n" +
        "- Use the provided EleFit user data (calories " +
        "consumed/goal/remaining, protein consumed/goal/remaining, " +
        "carbs, fat, steps, today's logged meals).\n" +
        "- Distinguish targets from consumed/remaining values clearly.\n" +
        "- Explain the reasoning behind your suggestion.\n" +
        "- Prioritize actionable, encouraging advice.\n" +
        "- Avoid shaming or judgmental language.\n" +
        "- Never invent or hallucinate foods or measurements the user " +
        "did not log.\n" +
        "- Acknowledge missing data if any is absent.\n" +
        "- Do NOT calculate fake workouts or hallucinate weight trends.",
      input: [
        {
          role: "user",
          content: userPrompt,
        },
      ],
    };

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(requestPayload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(
        `OpenAI Guidance request failed: HTTP ${response.status} ${errorBody}`
      );
    }

    const json = (await response.json()) as Record<string, unknown>;

    let rawText: string | null = null;
    if (typeof json.output_text === "string" && json.output_text.trim()) {
      rawText = json.output_text;
    } else if (Array.isArray(json.output)) {
      for (const item of json.output) {
        if (!item || typeof item !== "object") continue;
        const obj = item as Record<string, unknown>;
        if (typeof obj.output_text === "string" && obj.output_text.trim()) {
          rawText = obj.output_text;
          break;
        }
        if (obj.type === "message" && Array.isArray(obj.content)) {
          for (const c of obj.content) {
            if (!c || typeof c !== "object") continue;
            const cObj = c as Record<string, unknown>;
            if (
              (cObj.type === "text" || cObj.type === "output_text") &&
              typeof cObj.text === "string" &&
              cObj.text.trim()
            ) {
              rawText = cObj.text;
              break;
            }
          }
        }
      }
    }

    if (!rawText || !rawText.trim()) {
      return (
        "I couldn't generate guidance right now. Try asking again in a moment."
      );
    }

    return rawText.trim();
  }
}
