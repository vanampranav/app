import axios from "axios";
import { OpenAI } from "openai";
import {
  saveAiCoachData,
  getAiCoachData,
  saveAiCoachHistory,
  getAiCoachHistory,
} from "./firebase";

const openai = new OpenAI({
  apiKey: process.env.NEXT_PUBLIC_OPENAI_API_KEY,
  dangerouslyAllowBrowser: true, // For client-side usage
});

export interface UserProfile {
  age: number;
  height: number;
  weight: number;
  gender: "male" | "female" | "other";
  activityLevel: "sedentary" | "lightly" | "moderate" | "very" | "extra";
  targetWeight: number;
  targetTimeline: number; // in weeks
  workoutDays: number;
  dietaryPreferences: string[];
}

export interface FitnessPlan {
  dailyCalories: number;
  macros: {
    protein: number;
    carbs: number;
    fat: number;
  };
  meals: Meal[];
  workouts: Workout[];
}

export interface Meal {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  ingredients: string[];
  instructions: string;
}

export interface Workout {
  day: string;
  name: string;
  duration: number;
  exercises: Exercise[];
}

export interface Exercise {
  name: string;
  sets: number;
  reps: number;
  weight?: number;
}

// ============================================================
// CALORIE CALCULATION
// ============================================================

/**
 * Calculate BMR using Harris-Benedict formula
 */
export const calculateBMR = (
  age: number,
  height: number,
  weight: number,
  gender: "male" | "female" | "other"
): number => {
  let bmr: number;

  if (gender === "male") {
    bmr =
      88.362 +
      13.397 * weight +
      4.799 * height -
      5.677 * age;
  } else if (gender === "female") {
    bmr =
      447.593 +
      9.247 * weight +
      3.098 * height -
      4.33 * age;
  } else {
    // Average for other
    const maleBMR =
      88.362 +
      13.397 * weight +
      4.799 * height -
      5.677 * age;
    const femaleBMR =
      447.593 +
      9.247 * weight +
      3.098 * height -
      4.33 * age;
    bmr = (maleBMR + femaleBMR) / 2;
  }

  return Math.round(bmr);
};

/**
 * Calculate daily caloric needs based on activity level
 */
export const calculateDailyCalories = (
  bmr: number,
  activityLevel: string
): number => {
  const activityMultipliers: Record<string, number> = {
    sedentary: 1.2,
    lightly: 1.375,
    moderate: 1.55,
    very: 1.725,
    extra: 1.9,
  };

  const multiplier = activityMultipliers[activityLevel] || 1.55;
  return Math.round(bmr * multiplier);
};

/**
 * Adjust calories for weight loss/gain goal
 */
export const adjustCaloriesForGoal = (
  dailyCalories: number,
  currentWeight: number,
  targetWeight: number,
  timelineWeeks: number
): number => {
  const weightDifference = Math.abs(currentWeight - targetWeight);
  const weeklyWeightChange = weightDifference / timelineWeeks;

  // 1 lb = 3500 calories, 1 kg = 7700 calories
  const calorieAdjustment = weeklyWeightChange * 500; // roughly

  if (currentWeight > targetWeight) {
    // Weight loss - reduce calories
    return Math.round(dailyCalories - calorieAdjustment);
  } else {
    // Weight gain - increase calories
    return Math.round(dailyCalories + calorieAdjustment);
  }
};

/**
 * Calculate macronutrient breakdown
 */
export const calculateMacros = (calories: number) => {
  // Standard ratio: 40% carbs, 30% protein, 30% fat
  return {
    protein: Math.round((calories * 0.3) / 4), // 4 cal per gram
    carbs: Math.round((calories * 0.4) / 4),
    fat: Math.round((calories * 0.3) / 9), // 9 cal per gram
  };
};

// ============================================================
// AI GENERATION FUNCTIONS
// ============================================================

/**
 * Generate fitness plan using OpenAI
 */
export const generateFitnessPlan = async (
  userProfile: UserProfile
): Promise<FitnessPlan> => {
  try {
    const bmr = calculateBMR(
      userProfile.age,
      userProfile.height,
      userProfile.weight,
      userProfile.gender
    );
    const dailyCalories = calculateDailyCalories(
      bmr,
      userProfile.activityLevel
    );
    const adjustedCalories = adjustCaloriesForGoal(
      dailyCalories,
      userProfile.weight,
      userProfile.targetWeight,
      userProfile.targetTimeline
    );
    const macros = calculateMacros(adjustedCalories);

    // Generate meal plan with OpenAI
    const mealResponse = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content:
            "You are a professional nutritionist. Generate healthy meal plans with specific recipes.",
        },
        {
          role: "user",
          content: `Create a daily meal plan for someone with the following requirements:
          - Daily calorie target: ${adjustedCalories}
          - Protein: ${macros.protein}g
          - Carbs: ${macros.carbs}g
          - Fat: ${macros.fat}g
          - Dietary preferences: ${userProfile.dietaryPreferences.join(", ")}
          
          Format the response as JSON with meal details.`,
        },
      ],
    });

    // Generate workout plan with OpenAI
    const workoutResponse = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content:
            "You are a professional fitness trainer. Generate detailed workout plans.",
        },
        {
          role: "user",
          content: `Create a ${userProfile.workoutDays}-day workout plan for:
          - Activity Level: ${userProfile.activityLevel}
          - Age: ${userProfile.age}
          - Goal: Weight management
          
          Format the response as JSON with day-by-day exercises.`,
        },
      ],
    });

    // Parse responses (simplified - in production, add proper validation)
    let meals: Meal[] = [];
    let workouts: Workout[] = [];

    try {
      const mealContent = mealResponse.choices[0]?.message?.content || "";
      const jsonMatch = mealContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        meals = parsed.meals || [];
      }
    } catch (e) {
      console.error("Error parsing meal plan:", e);
    }

    try {
      const workoutContent =
        workoutResponse.choices[0]?.message?.content || "";
      const jsonMatch = workoutContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        workouts = parsed.workouts || [];
      }
    } catch (e) {
      console.error("Error parsing workout plan:", e);
    }

    return {
      dailyCalories: adjustedCalories,
      macros,
      meals: meals.length > 0 ? meals : generateDefaultMeals(adjustedCalories),
      workouts:
        workouts.length > 0
          ? workouts
          : generateDefaultWorkouts(userProfile.workoutDays),
    };
  } catch (error) {
    console.error("Error generating fitness plan:", error);
    throw new Error(
      error instanceof Error ? error.message : "Failed to generate fitness plan"
    );
  }
};

/**
 * Generate default meals if AI generation fails
 */
const generateDefaultMeals = (calories: number): Meal[] => {
  const caloriesPerMeal = Math.round(calories / 4);
  return [
    {
      name: "Breakfast",
      calories: caloriesPerMeal,
      protein: Math.round(caloriesPerMeal * 0.3 / 4),
      carbs: Math.round(caloriesPerMeal * 0.4 / 4),
      fat: Math.round(caloriesPerMeal * 0.3 / 9),
      ingredients: ["Oats", "Berries", "Greek Yogurt", "Honey"],
      instructions: "Mix ingredients and serve",
    },
    {
      name: "Lunch",
      calories: caloriesPerMeal,
      protein: Math.round(caloriesPerMeal * 0.35 / 4),
      carbs: Math.round(caloriesPerMeal * 0.45 / 4),
      fat: Math.round(caloriesPerMeal * 0.2 / 9),
      ingredients: ["Chicken Breast", "Brown Rice", "Broccoli", "Olive Oil"],
      instructions: "Grill chicken, cook rice, steam broccoli",
    },
    {
      name: "Dinner",
      calories: caloriesPerMeal,
      protein: Math.round(caloriesPerMeal * 0.3 / 4),
      carbs: Math.round(caloriesPerMeal * 0.35 / 4),
      fat: Math.round(caloriesPerMeal * 0.35 / 9),
      ingredients: ["Fish", "Sweet Potato", "Spinach", "Lemon"],
      instructions: "Bake fish, roast sweet potato, sauté spinach",
    },
  ];
};

/**
 * Generate default workouts if AI generation fails
 */
const generateDefaultWorkouts = (days: number): Workout[] => {
  const workoutTemplates = [
    {
      day: "Monday",
      name: "Chest & Triceps",
      duration: 60,
      exercises: [
        { name: "Bench Press", sets: 4, reps: 8 },
        { name: "Incline Dumbbell Press", sets: 3, reps: 10 },
        { name: "Tricep Dips", sets: 3, reps: 8 },
      ],
    },
    {
      day: "Tuesday",
      name: "Back & Biceps",
      duration: 60,
      exercises: [
        { name: "Deadlifts", sets: 4, reps: 6 },
        { name: "Bent-over Rows", sets: 4, reps: 8 },
        { name: "Barbell Curls", sets: 3, reps: 10 },
      ],
    },
    {
      day: "Wednesday",
      name: "Legs",
      duration: 75,
      exercises: [
        { name: "Squats", sets: 4, reps: 8 },
        { name: "Leg Press", sets: 3, reps: 10 },
        { name: "Leg Curls", sets: 3, reps: 10 },
      ],
    },
  ];

  return workoutTemplates.slice(0, days);
};

// ============================================================
// DATABASE OPERATIONS
// ============================================================

/**
 * Save AI coach data to Firebase
 */
export const saveCoachPlan = async (
  uid: string,
  userProfile: UserProfile,
  plan: FitnessPlan
) => {
  try {
    await saveAiCoachData(uid, {
      userProfile,
      plan,
      savedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to save coach plan"
    );
  }
};

/**
 * Get current AI coach plan
 */
export const getCurrentCoachPlan = async (uid: string) => {
  try {
    return await getAiCoachData(uid);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch coach plan"
    );
  }
};

/**
 * Save to history
 */
export const saveToCoachHistory = async (
  uid: string,
  userProfile: UserProfile,
  plan: FitnessPlan
) => {
  try {
    await saveAiCoachHistory(uid, {
      userProfile,
      plan,
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to save to history"
    );
  }
};

/**
 * Get coach history
 */
export const getCoachHistory = async (uid: string) => {
  try {
    return await getAiCoachHistory(uid);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch history"
    );
  }
};
