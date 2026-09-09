import {
  ConversationSession,
  MealProposal,
  MealProposalItem,
  StateMutation,
  TurnClassificationResult,
} from "./types";
import {AiProvider} from "../ai/ai-provider";
import {NutritionProvider} from "../nutrition/nutrition-provider";
import {MealOrchestrator} from "./meal-orchestrator";
import {
  InterpretedFood,
} from "../ai/types";

/**
 * Normalizes text string.
 *
 * @param {string} str - Raw string.
 * @return {string} Normalized lowercased string.
 */
function normalizeStr(str: string): string {
  return str.toLowerCase().trim().replace(/\s+/g, " ");
}

/**
 * Manages authoritative working conversation state across turns.
 */
export class ConversationStateManager {
  /**
   * Creates a fresh default ConversationSession.
   *
   * @param {string} uid - User ID.
   * @param {string} sessionId - Session ID.
   * @return {ConversationSession} Initialized session object.
   */
  static createDefaultSession(
    uid: string,
    sessionId: string
  ): ConversationSession {
    return {
      sessionId,
      uid,
      activeIntent: null,
      activeDomain: "general",
      pendingAction: "none",
      activeEntityId: null,
      expectedSlot: null,
      pendingClarification: null,
      mealDraft: null,
      recommendationContext: null,
      lastToolResult: null,
      lastResponseText: null,
      updatedAt: Date.now(),
    };
  }

  /**
   * Normalizes an item in a MealProposal to ensure a stable itemId.
   *
   * @param {MealProposalItem} item - Meal proposal item.
   * @param {number} index - Index fallback.
   * @return {MealProposalItem} Item with stable itemId and modifiers.
   */
  static ensureStableItemIdentity(
    item: MealProposalItem,
    index: number
  ): MealProposalItem {
    return {
      ...item,
      itemId: item.itemId || `item_${index}`,
      originalText: item.originalText || item.interpretedName,
      modifiers: item.modifiers || [],
    };
  }

  /**
   * Deterministically validates structured AI turn classification outputs
   * against active session state before mutation execution.
   *
   * @param {TurnClassificationResult} rawResult - Raw classifier result.
   * @param {ConversationSession} session - Active conversation session.
   * @return {TurnClassificationResult | null} Validated classification or null.
   */
  static validateTurnClassification(
    rawResult: TurnClassificationResult,
    session: ConversationSession
  ): TurnClassificationResult | null {
    if (!rawResult || typeof rawResult !== "object") {
      return null;
    }

    const validTurnTypes = [
      "ANSWER_TO_PENDING_CLARIFICATION",
      "MODIFICATION_OF_PENDING_TASK",
      "NEW_INTENT",
      "CANCEL_PENDING_TASK",
      "LOG_COMMAND",
      "NEW_MEAL_LOG",
    ];

    if (!validTurnTypes.includes(rawResult.turnType)) {
      return null;
    }

    const draftItems = session.mealDraft?.items || [];
    const validatedMutations: StateMutation[] = [];

    const validOps = [
      "ADD_ITEM",
      "REMOVE_ITEM",
      "REPLACE_ITEM",
      "CHANGE_QUANTITY",
      "CHANGE_UNIT",
      "CHANGE_MEAL_TYPE",
      "UPDATE_MODIFIERS",
      "ANSWER_CLARIFICATION",
      "NONE",
    ];

    for (const mut of rawResult.mutations || []) {
      if (!mut || !validOps.includes(mut.op) || mut.op === "NONE") {
        continue;
      }

      // Validate numeric quantity if supplied
      if (
        mut.quantity !== undefined &&
        mut.quantity !== null &&
        (typeof mut.quantity !== "number" ||
          isNaN(mut.quantity) ||
          !isFinite(mut.quantity) ||
          mut.quantity <= 0)
      ) {
        continue;
      }

      // Validate entity targeting for item-specific mutations
      if (
        [
          "CHANGE_QUANTITY",
          "UPDATE_MODIFIERS",
          "REPLACE_ITEM",
          "REMOVE_ITEM",
        ].includes(mut.op)
      ) {
        if (draftItems.length === 0) {
          continue; // Cannot apply item mutations to empty draft
        }

        // Target Resolution Step 1: Accept targetEntityId if in draft
        let resolvedTargetId: string | null = null;
        if (
          mut.targetEntityId &&
          draftItems.some((i) => i.itemId === mut.targetEntityId)
        ) {
          resolvedTargetId = mut.targetEntityId;
        }

        // Target Resolution Step 2: Otherwise, resolve using targetFoodName
        // ONLY if it produces ONE UNAMBIGUOUS draft-item match.
        if (
          !resolvedTargetId &&
          mut.targetFoodName &&
          mut.targetFoodName.trim().length > 0
        ) {
          const targetName = normalizeStr(mut.targetFoodName);
          const matchingItems = draftItems.filter((i) => {
            const itemName = normalizeStr(i.interpretedName);
            return (
              itemName.includes(targetName) || targetName.includes(itemName)
            );
          });

          if (matchingItems.length === 1) {
            resolvedTargetId = matchingItems[0].itemId || null;
          }
        }

        // Target Resolution Step 3: Otherwise, use session.activeEntityId
        // ONLY if it exists in the current draft.
        if (
          !resolvedTargetId &&
          session.activeEntityId &&
          draftItems.some((i) => i.itemId === session.activeEntityId)
        ) {
          resolvedTargetId = session.activeEntityId;
        }

        // Target Resolution Step 4: Otherwise, REJECT/DROP mutation safely
        if (!resolvedTargetId) {
          continue; // Never guess or default to draftItems[0]
        }

        validatedMutations.push({
          ...mut,
          targetEntityId: resolvedTargetId,
        });
      } else {
        validatedMutations.push(mut);
      }
    }

    return {
      turnType: rawResult.turnType,
      intent: rawResult.intent || null,
      mutations: validatedMutations,
      newQueryText: rawResult.newQueryText,
    };
  }

  /**
   * Classifies an incoming message turn into turn type & mutations.
   *
   * @param {ConversationSession} session - Active conversation session.
   * @param {string} message - Incoming user text.
   * @param {AiProvider} [aiProvider] - Active AI provider.
   * @return {Promise<TurnClassificationResult>} Classified turn result.
   */
  static async classifyTurn(
    session: ConversationSession,
    message: string,
    aiProvider?: AiProvider
  ): Promise<TurnClassificationResult> {
    const norm = normalizeStr(message);

    // 1. DETERMINISTIC PROTOCOL FAST PATHS
    // Strict single-word UI action commands (emitted by UI buttons).
    // These do not perform natural-language semantic parsing.
    if (norm === "cancel" || norm === "clear" || norm === "start over") {
      return {
        turnType: "CANCEL_PENDING_TASK",
        intent: "cancel",
        mutations: [],
      };
    }

    if (norm === "confirm" || norm === "log" || norm === "log it") {
      return {
        turnType: "LOG_COMMAND",
        intent: "log_meal",
        mutations: [],
      };
    }

    // 2. PRIMARY AI TURN UNDERSTANDING (No phrase-specific fallbacks)
    if (aiProvider && aiProvider.classifyTurnAndMutations) {
      try {
        const rawRes = await aiProvider.classifyTurnAndMutations({
          message,
          session,
        });
        if (rawRes && rawRes.turnType) {
          const validated = this.validateTurnClassification(rawRes, session);
          if (validated) {
            return validated;
          }
        }
      } catch (e) {
        console.warn("AI classifyTurnAndMutations error:", e);
      }
    }

    // 3. GENERIC FALLBACK WHEN AI CLASSIFIER IS UNCONFIGURED
    if (session.pendingClarification || session.activeEntityId) {
      return {
        turnType: "ANSWER_TO_PENDING_CLARIFICATION",
        intent: "log_meal",
        mutations: [
          {
            op: "ANSWER_CLARIFICATION",
            targetEntityId:
              session.activeEntityId ||
              (session.pendingClarification ?
                session.pendingClarification.targetEntityId :
                null),
          },
        ],
      };
    }

    return {
      turnType: "NEW_MEAL_LOG",
      intent: "log_meal",
      mutations: [],
      newQueryText: message,
    };
  }

  /**
   * Applies deterministic state mutations to a MealProposal.
   *
   * @param {MealProposal} draft - Current meal proposal draft.
   * @param {StateMutation[]} mutations - Array of mutations to apply.
   * @param {string} answerMessage - Raw user answer text.
   * @param {NutritionProvider} nutritionProvider - Active nutrition provider.
   * @param {AiProvider} [aiProvider] - Active AI provider.
   * @param {string | null} [activeEntityId] - Active target entity ID.
   * @return {Promise<MealProposal>} Mutated and re-resolved MealProposal.
   */
  static async applyMutationsToMealDraft(
    draft: MealProposal,
    mutations: StateMutation[],
    answerMessage: string,
    nutritionProvider: NutritionProvider,
    aiProvider?: AiProvider,
    activeEntityId?: string | null
  ): Promise<MealProposal> {
    let items = draft.items.map((i, idx) =>
      this.ensureStableItemIdentity(i, idx)
    );

    // 1. APPLY EXPLICIT MUTATIONS
    for (const mut of mutations) {
      if (mut.op === "CHANGE_QUANTITY") {
        items = items.map((item) => {
          if (
            (mut.targetEntityId && item.itemId === mut.targetEntityId) ||
            (mut.targetFoodName &&
              item.interpretedName
                .toLowerCase()
                .includes(mut.targetFoodName.toLowerCase()))
          ) {
            return {
              ...item,
              requestedQuantity: mut.quantity ?? item.requestedQuantity,
              requestedUnit: mut.unit ?? item.requestedUnit,
            };
          }
          return item;
        });
      } else if (mut.op === "UPDATE_MODIFIERS") {
        items = items.map((item) => {
          if (
            (mut.targetEntityId && item.itemId === mut.targetEntityId) ||
            (mut.targetFoodName &&
              item.interpretedName
                .toLowerCase()
                .includes(mut.targetFoodName.toLowerCase()))
          ) {
            let currentMods = [...(item.modifiers || [])];
            const toRemove = mut.removeModifiers || [];
            if (toRemove.length > 0) {
              currentMods = currentMods.filter(
                (m) =>
                  !toRemove.some((rm) => rm.toLowerCase() === m.toLowerCase())
              );
            }
            if (mut.addModifiers) {
              for (const am of mut.addModifiers) {
                if (
                  !currentMods.some(
                    (m) => m.toLowerCase() === am.toLowerCase()
                  )
                ) {
                  currentMods.push(am);
                }
              }
            }
            return {
              ...item,
              modifiers: currentMods,
            };
          }
          return item;
        });
      } else if (mut.op === "REPLACE_ITEM") {
        items = items.map((item) => {
          if (
            (mut.targetEntityId && item.itemId === mut.targetEntityId) ||
            (mut.targetFoodName &&
              item.interpretedName
                .toLowerCase()
                .includes(mut.targetFoodName.toLowerCase()))
          ) {
            return {
              ...item,
              interpretedName:
                mut.foodName || mut.targetFoodName || item.interpretedName,
              requestedQuantity: mut.quantity ?? item.requestedQuantity,
              requestedUnit: mut.unit ?? item.requestedUnit,
              matchedFoodId: null,
              matchedFoodName: null,
              status: "needs_quantity",
            };
          }
          return item;
        });
      } else if (mut.op === "REMOVE_ITEM") {
        items = items.filter(
          (item) =>
            !(
              (mut.targetEntityId && item.itemId === mut.targetEntityId) ||
              (mut.targetFoodName &&
                item.interpretedName
                  .toLowerCase()
                  .includes(mut.targetFoodName.toLowerCase()))
            )
        );
      }
    }

    // 2. CHECK MULTI-ENTITY OR CLARIFICATION ANSWER IN MESSAGE
    if (aiProvider && answerMessage.trim().length > 0) {
      try {
        const aiRes = await aiProvider.interpretMeal({
          text: answerMessage,
        });

        if (aiRes.foods && aiRes.foods.length > 0) {
          // Check multi-entity clarification ("1 cup rice, 200g chicken")
          for (const f of aiRes.foods) {
            const target = items.find(
              (i) =>
                i.interpretedName
                  .toLowerCase()
                  .includes(f.name.toLowerCase()) ||
                f.name
                  .toLowerCase()
                  .includes(i.interpretedName.toLowerCase()) ||
                (activeEntityId && i.itemId === activeEntityId)
            );

            if (target) {
              target.requestedQuantity =
                f.quantity ?? target.requestedQuantity;
              if (f.unit) {
                target.requestedUnit = f.unit;
              }
              if (
                f.name &&
                f.name.length > 1 &&
                f.name.toLowerCase() !== "food" &&
                !f.name.toLowerCase().includes("cup") &&
                !f.name.toLowerCase().includes("gram")
              ) {
                target.interpretedName = f.name;
              }
            }
          }
        }
      } catch (e) {
        console.warn("AI multi-entity interpretation error:", e);
      }
    }

    // 3. RE-RESOLVE ALL ITEMS WITH STATE PRESERVATION
    const updatedItems: MealProposalItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const baseName = item.interpretedName.split(" with ")[0].trim();
      let foodNameWithMods = baseName;
      if (item.modifiers && item.modifiers.length > 0) {
        foodNameWithMods = `${baseName} with ${item.modifiers.join(" and ")}`;
      }

      const updatedFood: InterpretedFood = {
        name: foodNameWithMods,
        quantity: item.requestedQuantity,
        unit: item.requestedUnit,
        modifiers: item.modifiers || [],
      };

      try {
        let resolved = await MealOrchestrator.resolveProposalItem(
          updatedFood,
          nutritionProvider
        );

        // State Preservation Invariant: Preserve intent on failure
        resolved = {
          ...resolved,
          itemId: item.itemId,
          originalText: item.originalText,
          modifiers: item.modifiers,
          interpretedName: foodNameWithMods,
          requestedQuantity:
            item.requestedQuantity ?? resolved.requestedQuantity,
          requestedUnit: item.requestedUnit ?? resolved.requestedUnit,
        };
        updatedItems.push(resolved);
      } catch (err) {
        console.error(
          `Error re-resolving item "${foodNameWithMods}":`,
          err
        );
        updatedItems.push({
          ...item,
          interpretedName: foodNameWithMods,
          status:
            item.requestedQuantity === null ?
              "needs_quantity" :
              "needs_food_match",
          clarificationQuestion:
            item.requestedQuantity === null ?
              `How much ${foodNameWithMods} did you have?` :
              `Which ${foodNameWithMods} did you have?`,
        });
      }
    }

    const resolvedItemCount = updatedItems.filter(
      (i) => i.status === "resolved"
    ).length;
    const unresolvedItemCount = updatedItems.length - resolvedItemCount;

    const hasUnresolvedItem = unresolvedItemCount > 0;
    const isMealTypeUnknown = draft.mealType === null;
    const needsClarification = hasUnresolvedItem || isMealTypeUnknown;

    let clarificationQuestion: string | null = null;
    if (needsClarification) {
      const firstUnresolved = updatedItems.find((i) => i.status !== "resolved");
      if (firstUnresolved) {
        clarificationQuestion = firstUnresolved.clarificationQuestion;
      } else if (isMealTypeUnknown) {
        clarificationQuestion =
          "Was this breakfast, lunch, dinner, or a snack?";
      }
    }

    const resolvedNutritionTotal =
      MealOrchestrator.calculateResolvedNutritionTotal(updatedItems);

    const readyToLog =
      draft.mealType !== null &&
      !needsClarification &&
      updatedItems.length > 0 &&
      updatedItems.every((i) => i.status === "resolved");

    return {
      originalText: draft.originalText,
      mealType: draft.mealType,
      mealTypeSource: draft.mealTypeSource,
      interpretationConfidence: draft.interpretationConfidence,
      items: updatedItems,
      readyToLog,
      needsClarification,
      clarificationQuestion,
      resolvedItemCount,
      unresolvedItemCount,
      resolvedNutritionTotal,
    };
  }

  /**
   * Processes a conversation turn, updating ConversationSession state.
   *
   * @param {ConversationSession} session - Active conversation session.
   * @param {string} message - Incoming user message text.
   * @param {AiProvider} aiProvider - Active AI provider.
   * @param {NutritionProvider} nutritionProvider - Active nutrition provider.
   * @param {Record<string, unknown>} todayContext - TodayContext payload.
   * @return {Promise<Object>} Turn execution output object.
   */
  static async processTurn(
    session: ConversationSession,
    message: string,
    aiProvider: AiProvider,
    nutritionProvider: NutritionProvider,
    todayContext: Record<string, unknown>
  ): Promise<{
    session: ConversationSession;
    responseText: string;
    proposal: MealProposal | null;
    recommendation: unknown;
    responseType: string;
  }> {
    const classification = await this.classifyTurn(
      session,
      message,
      aiProvider
    );

    console.log(
      "[ConversationState Transition]\n" +
        `  sessionId: ${session.sessionId}\n` +
        `  incomingMessage: "${message}"\n` +
        `  turnType: ${classification.turnType}\n` +
        `  activeDomainBefore: ${session.activeDomain}\n` +
        `  activeEntityIdBefore: ${session.activeEntityId}\n` +
        `  mutationsCount: ${classification.mutations.length}`
    );

    // 1. CANCEL PENDING TASK
    if (classification.turnType === "CANCEL_PENDING_TASK") {
      session.mealDraft = null;
      session.pendingClarification = null;
      session.activeEntityId = null;
      session.expectedSlot = null;
      session.pendingAction = "none";
      session.activeDomain = "general";
      session.updatedAt = Date.now();

      return {
        session,
        responseText: "Cleared your pending meal draft.",
        proposal: null,
        recommendation: null,
        responseType: "guidance",
      };
    }

    // 2. INTENT INTERRUPTION (e.g. "How much protein do I have left today?")
    if (classification.turnType === "NEW_INTENT") {
      const guidanceResult = await aiProvider.getGuidance({
        message,
        todayContext,
        recommendationContext: session.recommendationContext,
        uid: session.uid,
      });

      session.activeDomain = "guidance";
      session.lastToolResult = guidanceResult as unknown as Record<
        string,
        unknown
      >;
      session.updatedAt = Date.now();

      return {
        session,
        responseText: guidanceResult.responseText,
        proposal: session.mealDraft, // PRESERVED INTENT: mealDraft intact
        recommendation: guidanceResult.recommendation ?? null,
        responseType: guidanceResult.responseType,
      };
    }

    // 3. MODIFICATION OR CLARIFICATION ON ACTIVE DRAFT
    if (
      (classification.turnType === "MODIFICATION_OF_PENDING_TASK" ||
        classification.turnType === "ANSWER_TO_PENDING_CLARIFICATION") &&
      session.mealDraft
    ) {
      const updatedDraft = await this.applyMutationsToMealDraft(
        session.mealDraft,
        classification.mutations,
        message,
        nutritionProvider,
        aiProvider,
        session.activeEntityId
      );

      session.mealDraft = updatedDraft;
      session.activeDomain = "meal";

      if (updatedDraft.needsClarification) {
        const firstUnresolved = updatedDraft.items.find(
          (i) => i.status !== "resolved"
        );
        session.pendingAction = "clarify_meal_item";
        session.activeEntityId = firstUnresolved?.itemId || null;
        session.expectedSlot =
          firstUnresolved?.status === "needs_quantity" ?
            "quantity" :
            "food_identity";
        session.pendingClarification = {
          targetEntityId: firstUnresolved?.itemId || null,
          targetFoodName: firstUnresolved?.interpretedName || null,
          question:
            updatedDraft.clarificationQuestion ||
            "Could you clarify the meal details?",
          expectedSlot: session.expectedSlot,
        };
      } else {
        session.pendingAction = "confirm_meal_log";
        session.activeEntityId = null;
        session.expectedSlot = null;
        session.pendingClarification = null;
      }

      session.updatedAt = Date.now();

      return {
        session,
        responseText:
          updatedDraft.clarificationQuestion || "Updated meal draft.",
        proposal: updatedDraft,
        recommendation: null,
        responseType: "meal_proposal",
      };
    }

    // 4. NEW MEAL LOG ACTION
    const newProposal = await MealOrchestrator.prepareMeal(
      {
        text: message,
      },
      aiProvider,
      nutritionProvider
    );

    // Assign stable itemIds to new proposal items
    newProposal.items = newProposal.items.map((i, idx) =>
      this.ensureStableItemIdentity(i, idx)
    );

    session.mealDraft = newProposal;
    session.activeDomain = "meal";

    if (newProposal.needsClarification) {
      const firstUnresolved = newProposal.items.find(
        (i) => i.status !== "resolved"
      );
      session.pendingAction = "clarify_meal_item";
      session.activeEntityId = firstUnresolved?.itemId || null;
      session.expectedSlot =
        firstUnresolved?.status === "needs_quantity" ?
          "quantity" :
          "food_identity";
      session.pendingClarification = {
        targetEntityId: firstUnresolved?.itemId || null,
        targetFoodName: firstUnresolved?.interpretedName || null,
        question:
          newProposal.clarificationQuestion ||
          "Could you clarify the meal details?",
        expectedSlot: session.expectedSlot,
      };
    } else {
      session.pendingAction = "confirm_meal_log";
      session.activeEntityId = null;
      session.expectedSlot = null;
      session.pendingClarification = null;
    }

    session.updatedAt = Date.now();

    return {
      session,
      responseText:
        newProposal.clarificationQuestion || "Prepared meal proposal.",
      proposal: newProposal,
      recommendation: null,
      responseType: "meal_proposal",
    };
  }
}
