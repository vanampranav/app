import {onCall, HttpsError} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {getNutritionProvider} from "./nutrition/provider-factory";
import {getAiProvider} from "./ai/provider-factory";
import {MealType, RecommendationContextInput} from "./ai/types";
import {MealOrchestrator} from "./ask-ele/meal-orchestrator";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

setGlobalOptions({maxInstances: 10});

export const fatSecretConsumerKey = defineSecret("FATSECRET_CONSUMER_KEY");
export const fatSecretConsumerSecret = defineSecret(
  "FATSECRET_CONSUMER_SECRET"
);
export const openAiApiKey = defineSecret("OPENAI_API_KEY");

export const helloEleFit = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  return {
    success: true,
    message: "Hello from EleFit backend",
    uid: request.auth.uid,
  };
});

const VALID_MEAL_TYPES = ["breakfast", "lunch", "dinner", "snacks"] as const;

const parseNumber = (val: unknown): number | null => {
  if (typeof val === "number" && !isNaN(val)) {
    return val;
  }
  return null;
};

export const saveMeal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const uid = request.auth.uid;
  const data = request.data;

  if (!data || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "Request payload must be an object."
    );
  }

  const entryId =
    typeof data.entryId === "string" ? data.entryId.trim() : "";
  if (!entryId) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'entryId'."
    );
  }

  const foodName =
    typeof data.foodName === "string" ? data.foodName.trim() : "";
  if (!foodName) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'foodName'."
    );
  }

  const fdcId =
    data.fdcId !== undefined && data.fdcId !== null ?
      String(data.fdcId).trim() :
      "";
  if (!fdcId) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'fdcId'."
    );
  }

  const weight =
    typeof data.weight === "number" ? data.weight : Number(data.weight);
  if (isNaN(weight) || weight <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "'weight' must be a positive number."
    );
  }

  const meal =
    typeof data.meal === "string" ? data.meal.trim().toLowerCase() : "";
  if (!VALID_MEAL_TYPES.includes(meal as (typeof VALID_MEAL_TYPES)[number])) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid 'meal'. Must be one of: breakfast, lunch, dinner, snacks."
    );
  }

  const rawTimestamp = data.timestamp;
  if (
    !rawTimestamp ||
    (typeof rawTimestamp !== "string" && typeof rawTimestamp !== "number")
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'timestamp'."
    );
  }

  const parsedDate = new Date(rawTimestamp);
  if (isNaN(parsedDate.getTime())) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid 'timestamp'. Must be a valid date."
    );
  }

  const mealTimestamp = Timestamp.fromDate(parsedDate);

  const rawNutrition = data.nutrition;
  if (!rawNutrition || typeof rawNutrition !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'nutrition' object."
    );
  }

  const calories = parseNumber(rawNutrition.calories);
  const fat = parseNumber(rawNutrition.fat);
  const carbs = parseNumber(rawNutrition.carbs);
  const protein = parseNumber(rawNutrition.protein);

  if (
    calories === null ||
    fat === null ||
    carbs === null ||
    protein === null
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid 'nutrition'. Required macros: calories, fat, carbs, protein."
    );
  }

  const nutrition = {
    calories,
    fat,
    carbs,
    protein,
    fiber: parseNumber(rawNutrition.fiber) ?? 0,
    sugar: parseNumber(rawNutrition.sugar) ?? 0,
    vitaminA: parseNumber(rawNutrition.vitaminA),
    vitaminB1: parseNumber(rawNutrition.vitaminB1),
    vitaminB2: parseNumber(rawNutrition.vitaminB2),
    vitaminC: parseNumber(rawNutrition.vitaminC),
    vitaminE: parseNumber(rawNutrition.vitaminE),
    calcium: parseNumber(rawNutrition.calcium),
    iron: parseNumber(rawNutrition.iron),
    magnesium: parseNumber(rawNutrition.magnesium),
    potassium: parseNumber(rawNutrition.potassium),
    sodium: parseNumber(rawNutrition.sodium),
    zinc: parseNumber(rawNutrition.zinc),
    cholesterol: parseNumber(rawNutrition.cholesterol),
    carotene: parseNumber(rawNutrition.carotene),
    retinol: parseNumber(rawNutrition.retinol),
  };

  const imageUrl =
    typeof data.imageUrl === "string" && data.imageUrl.trim().length > 0 ?
      data.imageUrl.trim() :
      null;

  const source =
    typeof data.source === "string" && data.source.trim().length > 0 ?
      data.source.trim() :
      "manual";

  const nutritionSource =
    typeof data.nutritionSource === "string" &&
    data.nutritionSource.trim().length > 0 ?
      data.nutritionSource.trim() :
      "unknown";

  const mealDoc = {
    entryId,
    foodName,
    fdcId,
    weight,
    meal,
    timestamp: mealTimestamp,
    imageUrl,
    nutrition,
    source,
    nutritionSource,
  };

  const docRef = db
    .collection("users")
    .doc(uid)
    .collection("mealEntries")
    .doc(entryId);

  try {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        transaction.set(docRef, {
          ...mealDoc,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(
          docRef,
          {
            ...mealDoc,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
      }
    });

    return {
      success: true,
      id: entryId,
      message: "Meal entry saved successfully",
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : "Unknown error";
    throw new HttpsError(
      "internal",
      `Failed to save meal entry: ${errorMsg}`
    );
  }
});

export const getMealsForDate = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const uid = request.auth.uid;
  const data = request.data;

  if (!data || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "Request payload must be an object."
    );
  }

  const dateStr = typeof data.date === "string" ? data.date.trim() : "";
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  if (!dateRegex.test(dateStr)) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'date'. Expected format: YYYY-MM-DD."
    );
  }

  const [yearStr, monthStr, dayStr] = dateStr.split("-");
  const year = parseInt(yearStr, 10);
  const month = parseInt(monthStr, 10);
  const day = parseInt(dayStr, 10);

  const testDate = new Date(Date.UTC(year, month - 1, day));
  if (
    testDate.getUTCFullYear() !== year ||
    testDate.getUTCMonth() !== month - 1 ||
    testDate.getUTCDate() !== day
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid calendar date. The specified date does not exist."
    );
  }

  const offsetMinutes = data.timezoneOffsetMinutes;
  if (
    typeof offsetMinutes !== "number" ||
    !Number.isInteger(offsetMinutes) ||
    offsetMinutes < -840 ||
    offsetMinutes > 840
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid 'timezoneOffsetMinutes'. " +
      "Must be an integer between -840 and 840."
    );
  }

  const startOfDayUtcMillis =
    Date.UTC(year, month - 1, day, 0, 0, 0, 0) - offsetMinutes * 60 * 1000;
  const nextDayStartUtcMillis =
    startOfDayUtcMillis + 24 * 60 * 60 * 1000;

  const startOfDayUtc = Timestamp.fromMillis(startOfDayUtcMillis);
  const nextDayStartUtc = Timestamp.fromMillis(nextDayStartUtcMillis);

  try {
    const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("mealEntries")
      .where("timestamp", ">=", startOfDayUtc)
      .where("timestamp", "<", nextDayStartUtc)
      .orderBy("timestamp", "asc")
      .get();

    const entries = snapshot.docs.map((doc) => {
      const docData = doc.data();

      const formatTimestamp = (val: unknown): string | null => {
        if (val instanceof Timestamp) {
          return val.toDate().toISOString();
        }
        if (typeof val === "string") {
          return val;
        }
        return null;
      };

      const entryId = docData.entryId || doc.id;
      const ts =
        formatTimestamp(docData.timestamp) || new Date().toISOString();

      return {
        id: entryId,
        entryId,
        foodName: docData.foodName || "",
        fdcId: docData.fdcId || "",
        weight: docData.weight || 0,
        meal: docData.meal || "snacks",
        timestamp: ts,
        imageUrl: docData.imageUrl || null,
        nutrition: docData.nutrition || {},
        source: docData.source || "manual",
        nutritionSource: docData.nutritionSource || "unknown",
        createdAt: formatTimestamp(docData.createdAt),
        updatedAt: formatTimestamp(docData.updatedAt),
      };
    });

    return {
      success: true,
      date: dateStr,
      entries,
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : "Unknown error";
    throw new HttpsError(
      "internal",
      `Failed to fetch meals for date: ${errorMsg}`
    );
  }
});

export const searchFoods = onCall(
  {
    secrets: [fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    if (!data || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Request payload must be an object."
      );
    }

    const query = typeof data.query === "string" ? data.query.trim() : "";
    if (!query || query.length > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'query'. Must be a string up to 100 chars."
      );
    }

    let page: number | undefined;
    if (data.page !== undefined) {
      if (
        typeof data.page !== "number" ||
        !Number.isInteger(data.page) ||
        data.page < 0
      ) {
        throw new HttpsError(
          "invalid-argument",
          "'page' must be a non-negative integer."
        );
      }
      page = data.page;
    }

    let maxResults: number | undefined;
    if (data.maxResults !== undefined) {
      if (
        typeof data.maxResults !== "number" ||
        !Number.isInteger(data.maxResults) ||
        data.maxResults <= 0 ||
        data.maxResults > 50
      ) {
        throw new HttpsError(
          "invalid-argument",
          "'maxResults' must be an integer between 1 and 50."
        );
      }
      maxResults = data.maxResults;
    }

    const key = fatSecretConsumerKey.value();
    const secret = fatSecretConsumerSecret.value();

    if (!key || !secret) {
      logger.error("FatSecret secrets are not configured in environment.");
      throw new HttpsError(
        "internal",
        "Nutrition provider credentials are not configured."
      );
    }

    const provider = getNutritionProvider(key, secret);

    try {
      const foods = await provider.searchFoods(query, {
        page,
        maxResults,
      });

      logger.info("Food search executed successfully", {
        uid,
        provider: provider.name,
        query,
        resultCount: foods.length,
      });

      return {
        success: true,
        query,
        provider: provider.name,
        foods,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Food search failed", {
        uid,
        provider: provider.name,
        query,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        `Failed to perform food search: ${errorMsg}`
      );
    }
  }
);

export const getFoodDetails = onCall(
  {
    secrets: [fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    if (!data || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Request payload must be an object."
      );
    }

    const foodId = typeof data.foodId === "string" ? data.foodId.trim() : "";
    if (!foodId || foodId.length > 50) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'foodId'. Must be a string up to 50 chars."
      );
    }

    const key = fatSecretConsumerKey.value();
    const secret = fatSecretConsumerSecret.value();

    if (!key || !secret) {
      logger.error("FatSecret secrets are not configured in environment.");
      throw new HttpsError(
        "internal",
        "Nutrition provider credentials are not configured."
      );
    }

    const provider = getNutritionProvider(key, secret);

    try {
      const food = await provider.getFoodDetails(foodId);

      logger.info("Food details retrieved successfully", {
        uid,
        provider: provider.name,
        foodId,
        servingCount: food.servings.length,
      });

      return {
        success: true,
        provider: provider.name,
        food,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Food details retrieval failed", {
        uid,
        provider: provider.name,
        foodId,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to retrieve food details."
      );
    }
  }
);

export const resolveFood = onCall(
  {
    secrets: [fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    if (!data || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Request payload must be an object."
      );
    }

    const foodId = typeof data.foodId === "string" ? data.foodId.trim() : "";
    if (!foodId || foodId.length > 50) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'foodId'. Must be a string up to 50 chars."
      );
    }

    const servingId =
      typeof data.servingId === "string" ? data.servingId.trim() : "";
    if (!servingId || servingId.length > 50) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'servingId'. Must be a string up to 50 chars."
      );
    }

    const quantity = data.quantity;
    if (
      typeof quantity !== "number" ||
      !isFinite(quantity) ||
      quantity <= 0 ||
      quantity > 1000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'quantity'. Must be a number between 0 and 1000."
      );
    }

    const key = fatSecretConsumerKey.value();
    const secret = fatSecretConsumerSecret.value();

    if (!key || !secret) {
      logger.error("FatSecret secrets are not configured in environment.");
      throw new HttpsError(
        "internal",
        "Nutrition provider credentials are not configured."
      );
    }

    const provider = getNutritionProvider(key, secret);

    try {
      const resolvedFood = await provider.resolveFood(
        foodId,
        servingId,
        quantity
      );

      logger.info("Food resolved successfully", {
        uid,
        provider: provider.name,
        foodId,
        servingId,
        quantity,
        weightGrams: resolvedFood.weightGrams,
      });

      return {
        success: true,
        provider: provider.name,
        food: resolvedFood,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Food resolution failed", {
        uid,
        provider: provider.name,
        foodId,
        servingId,
        quantity,
        error: errorMsg,
      });

      if (errorMsg.toLowerCase().includes("not found")) {
        throw new HttpsError(
          "not-found",
          "The requested serving could not be found."
        );
      }

      throw new HttpsError(
        "internal",
        "Unable to resolve food nutrition."
      );
    }
  }
);

export const interpretMeal = onCall(
  {
    secrets: [openAiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    if (!data || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Request payload must be an object."
      );
    }

    const text = typeof data.text === "string" ? data.text.trim() : "";
    if (!text || text.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'text'. Must be a string up to 500 chars."
      );
    }

    let localHour: number | undefined;
    if (data.localHour !== undefined) {
      if (
        typeof data.localHour !== "number" ||
        !Number.isInteger(data.localHour) ||
        data.localHour < 0 ||
        data.localHour > 23
      ) {
        throw new HttpsError(
          "invalid-argument",
          "'localHour' must be an integer between 0 and 23."
        );
      }
      localHour = data.localHour;
    }

    let suggestedMealType: MealType | null = null;
    if (
      data.suggestedMealType !== undefined &&
      data.suggestedMealType !== null
    ) {
      const rawMealType = String(data.suggestedMealType).trim().toLowerCase();
      if (VALID_MEAL_TYPES.includes(rawMealType as MealType)) {
        suggestedMealType = rawMealType as MealType;
      } else {
        throw new HttpsError(
          "invalid-argument",
          "Invalid 'suggestedMealType'. Must be breakfast, lunch, " +
          "dinner, or snacks."
        );
      }
    }

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      logger.error("OPENAI_API_KEY is not configured in environment.");
      throw new HttpsError(
        "internal",
        "AI provider credentials are not configured."
      );
    }

    const provider = getAiProvider(apiKey);

    try {
      const interpretation = await provider.interpretMeal({
        text,
        context: {
          localHour,
          suggestedMealType,
        },
      });

      logger.info("Meal interpretation executed successfully", {
        uid,
        provider: provider.name,
        foodCount: interpretation.foods.length,
        mealType: interpretation.mealType,
        mealTypeSource: interpretation.mealTypeSource,
        confidence: interpretation.confidence,
        needsClarification: interpretation.needsClarification,
      });

      return {
        success: true,
        interpretation,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Meal interpretation failed", {
        uid,
        provider: provider.name,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to interpret meal."
      );
    }
  }
);

export const prepareMeal = onCall(
  {
    secrets: [openAiApiKey, fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    if (!data || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Request payload must be an object."
      );
    }

    const text = typeof data.text === "string" ? data.text.trim() : "";
    if (!text || text.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "Missing or invalid 'text'. Must be a string up to 500 chars."
      );
    }

    let localHour: number | undefined;
    if (data.localHour !== undefined) {
      if (
        typeof data.localHour !== "number" ||
        !Number.isInteger(data.localHour) ||
        data.localHour < 0 ||
        data.localHour > 23
      ) {
        throw new HttpsError(
          "invalid-argument",
          "'localHour' must be an integer between 0 and 23."
        );
      }
      localHour = data.localHour;
    }

    let suggestedMealType: MealType | null = null;
    if (
      data.suggestedMealType !== undefined &&
      data.suggestedMealType !== null
    ) {
      const rawMealType = String(data.suggestedMealType).trim().toLowerCase();
      if (VALID_MEAL_TYPES.includes(rawMealType as MealType)) {
        suggestedMealType = rawMealType as MealType;
      } else {
        throw new HttpsError(
          "invalid-argument",
          "Invalid 'suggestedMealType'. Must be breakfast, lunch, " +
          "dinner, or snacks."
        );
      }
    }

    const aiKey = openAiApiKey.value();
    const fatKey = fatSecretConsumerKey.value();
    const fatSecret = fatSecretConsumerSecret.value();

    if (!aiKey || !fatKey || !fatSecret) {
      logger.error("Required backend secrets are not configured.");
      throw new HttpsError(
        "internal",
        "Backend service credentials are not configured."
      );
    }

    const aiProvider = getAiProvider(aiKey);
    const nutritionProvider = getNutritionProvider(fatKey, fatSecret);

    try {
      const proposal = await MealOrchestrator.prepareMeal(
        {
          text,
          localHour,
          suggestedMealType,
        },
        aiProvider,
        nutritionProvider
      );

      const resolvedItemCount = proposal.items.filter(
        (i) => i.status === "resolved"
      ).length;

      logger.info("Meal proposal prepared successfully", {
        uid,
        aiProvider: aiProvider.name,
        nutritionProvider: nutritionProvider.name,
        mealType: proposal.mealType,
        itemCount: proposal.items.length,
        resolvedItemCount,
        readyToLog: proposal.readyToLog,
        needsClarification: proposal.needsClarification,
      });

      return {
        success: true,
        proposal,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Meal proposal preparation failed", {
        uid,
        aiProvider: aiProvider.name,
        nutritionProvider: nutritionProvider.name,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to prepare meal proposal."
      );
    }
  }
);

export const resolveMealClarification = onCall(
  {
    secrets: [fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required to resolve meal clarification."
      );
    }

    const uid = request.auth.uid;
    const {proposal, itemIndex, answer} = request.data || {};

    if (!proposal || !Array.isArray(proposal.items)) {
      throw new HttpsError(
        "invalid-argument",
        "Valid proposal object is required."
      );
    }

    if (
      typeof itemIndex !== "number" ||
      itemIndex < 0 ||
      itemIndex >= proposal.items.length
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Valid itemIndex is required."
      );
    }

    if (typeof answer !== "string" || !answer.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Non-empty answer string is required."
      );
    }

    if (answer.length > 200) {
      throw new HttpsError(
        "invalid-argument",
        "Answer exceeds max length of 200 characters."
      );
    }

    const targetItem = proposal.items[itemIndex];
    if (targetItem.status === "resolved") {
      throw new HttpsError(
        "invalid-argument",
        "Target item is already resolved."
      );
    }

    const fatKey = fatSecretConsumerKey.value();
    const fatSecret = fatSecretConsumerSecret.value();

    if (!fatKey || !fatSecret) {
      logger.error("Required backend secrets are not configured.");
      throw new HttpsError(
        "internal",
        "Backend service credentials are not configured."
      );
    }

    const nutritionProvider = getNutritionProvider(fatKey, fatSecret);

    try {
      const updatedProposal =
        await MealOrchestrator.resolveMealClarification(
          proposal,
          itemIndex,
          answer,
          nutritionProvider
        );

      logger.info("Meal clarification resolved successfully", {
        uid,
        itemIndex,
        targetItem: targetItem.interpretedName,
        answer,
        readyToLog: updatedProposal.readyToLog,
        needsClarification: updatedProposal.needsClarification,
      });

      return {
        success: true,
        proposal: updatedProposal,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Meal clarification resolution failed", {
        uid,
        itemIndex,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to resolve meal clarification."
      );
    }
  }
);

export const updateMealProposalContext = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required to update meal proposal context."
      );
    }

    const uid = request.auth.uid;
    const {proposal, mealType} = request.data || {};

    if (!proposal || !Array.isArray(proposal.items)) {
      throw new HttpsError(
        "invalid-argument",
        "Valid proposal object is required."
      );
    }

    if (typeof mealType !== "string" || !mealType.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Non-empty mealType string is required."
      );
    }

    try {
      const updatedProposal =
        MealOrchestrator.updateMealProposalContext(
          proposal,
          mealType
        );

      logger.info("Meal proposal context updated successfully", {
        uid,
        mealType: updatedProposal.mealType,
        readyToLog: updatedProposal.readyToLog,
        needsClarification: updatedProposal.needsClarification,
      });

      return {
        success: true,
        proposal: updatedProposal,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Meal proposal context update failed", {
        uid,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to update meal proposal context."
      );
    }
  }
);

export const getAskEleGuidance = onCall(
  {
    secrets: [openAiApiKey, fatSecretConsumerKey, fatSecretConsumerSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required to request Ask Ele guidance."
      );
    }

    const uid = request.auth.uid;
    const {message, todayContext, recommendationContext} = request.data || {};

    if (typeof message !== "string" || !message.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Non-empty message string is required."
      );
    }

    try {
      const aiProvider = getAiProvider(openAiApiKey.value());

      const guidanceResult = await aiProvider.getGuidance({
        message,
        todayContext:
          todayContext && typeof todayContext === "object" ?
            (todayContext as Record<string, unknown>) :
            {},
        recommendationContext:
          recommendationContext && typeof recommendationContext === "object" ?
            (recommendationContext as RecommendationContextInput) :
            null,
        uid,
      });

      let proposal = null;

      if (
        guidanceResult.preparedMealText &&
        guidanceResult.preparedMealText.trim()
      ) {
        const fatKey = fatSecretConsumerKey.value();
        const fatSecret = fatSecretConsumerSecret.value();

        if (fatKey && fatSecret) {
          const nutritionProvider = getNutritionProvider(fatKey, fatSecret);
          proposal = await MealOrchestrator.prepareMeal(
            {
              text: guidanceResult.preparedMealText,
              suggestedMealType:
                guidanceResult.suggestedMealType ||
                guidanceResult.recommendation?.mealType ||
                null,
            },
            aiProvider,
            nutritionProvider
          );
        }
      }

      logger.info("Ask Ele guidance generated successfully", {
        uid,
        messageLength: message.length,
        responseType: guidanceResult.responseType,
        hasRecommendation: !!guidanceResult.recommendation,
        hasPreparedMeal: !!guidanceResult.preparedMealText,
        hasProposal: !!proposal,
      });

      return {
        success: true,
        responseType: guidanceResult.responseType,
        responseText: guidanceResult.responseText,
        recommendation: guidanceResult.recommendation,
        preparedMealText: guidanceResult.preparedMealText ?? null,
        suggestedMealType: guidanceResult.suggestedMealType ?? null,
        proposal: proposal ?? null,
      };
    } catch (error) {
      const errorMsg =
        error instanceof Error ? error.message : String(error);
      logger.error("Ask Ele guidance generation failed", {
        uid,
        error: errorMsg,
      });

      throw new HttpsError(
        "internal",
        "Unable to generate Ask Ele guidance."
      );
    }
  }
);

export const saveRecommendationFeedback = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to save feedback."
    );
  }

  const uid = request.auth.uid;
  const data = request.data;

  if (!data || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "Payload must be an object."
    );
  }

  const recommendationId =
    typeof data.recommendationId === "string" ?
      data.recommendationId.trim() :
      "";
  const optionId =
    typeof data.optionId === "string" ? data.optionId.trim() : "";
  const action = typeof data.action === "string" ? data.action.trim() : "";

  const validActions = ["liked", "disliked", "refreshed", "selected"];
  if (!validActions.includes(action)) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid action. Must be one of: liked, disliked, refreshed, selected."
    );
  }

  const feedbackId =
    typeof data.feedbackId === "string" && data.feedbackId.trim() ?
      data.feedbackId.trim() :
      `fb_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

  const feedbackDoc = {
    feedbackId,
    recommendationId: recommendationId || null,
    optionId: optionId || null,
    action,
    createdAt: FieldValue.serverTimestamp(),
  };

  const docRef = db
    .collection("users")
    .doc(uid)
    .collection("recommendationFeedback")
    .doc(feedbackId);

  try {
    await docRef.set(feedbackDoc, {merge: true});

    logger.info("Recommendation feedback recorded", {
      uid,
      feedbackId,
      action,
      recommendationId,
      optionId,
    });

    return {
      success: true,
      feedbackId,
      message: "Feedback recorded successfully",
    };
  } catch (error) {
    const errorMsg =
      error instanceof Error ? error.message : String(error);
    logger.error("Failed to record recommendation feedback", {
      uid,
      error: errorMsg,
    });

    throw new HttpsError(
      "internal",
      `Failed to record recommendation feedback: ${errorMsg}`
    );
  }
});
