"use client";

import React, { createContext, useContext, useState, ReactNode, useEffect } from 'react';

export type HelpType = 'meal' | 'workout' | 'both';
export type Gender = 'male' | 'female';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active';
export type TimelineUnit = 'weeks' | 'months';

export interface AiCoachData {
    // Step 1: Goal
    prompt: string;

    // Step 2: Details
    name: string;
    age: string;
    height: string;
    currentWeight: string;
    targetWeight: string;
    timelineValue: string;
    timelineUnit: TimelineUnit;
    gender: Gender;

    // Step 3: Preferences
    helpType: HelpType;
    activityLevel: ActivityLevel;
    workoutDays: number;
    dietaryText: string;
    dietaryTags: string[];

    // Results from /user endpoint
    calculatedData: {
        tdee: number;
        targetCalories: number;
        proteinGrams: number;
        carbsGrams: number;
        fatGrams: number;
        workoutFocus: string;
        capped: boolean;
        personalizedInsight?: string | null;
    } | null;

    // Generated Plans
    mealPlan: string | null;
    workoutPlan: string | null;
}

interface AiCoachContextType {
    data: AiCoachData;
    updateData: (updates: Partial<AiCoachData>) => void;
    clearOnboardingFlow: () => void;
    resetData: () => void;
    isGenerating: boolean;
    setIsGenerating: (value: boolean) => void;
}

const initialData: AiCoachData = {
    prompt: '',
    name: '',
    age: '',
    height: '',
    currentWeight: '',
    targetWeight: '',
    timelineValue: '3',
    timelineUnit: 'weeks',
    gender: 'male',
    helpType: 'both',
    activityLevel: 'moderate',
    workoutDays: 4,
    dietaryText: '',
    dietaryTags: [],
    calculatedData: null,
    mealPlan: null,
    workoutPlan: null,
};

const AiCoachContext = createContext<AiCoachContextType | undefined>(undefined);

export const AiCoachProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
    const [data, setData] = useState<AiCoachData>(initialData);
    const [isGenerating, setIsGenerating] = useState(false);

    // Persist data in localStorage
    useEffect(() => {
        const savedData = localStorage.getItem('ai_coach_onboarding');
        if (savedData) {
            try {
                setData(JSON.parse(savedData));
            } catch (e) {
                console.error("Failed to parse saved onboarding data", e);
            }
        }
    }, []);

    const updateData = (updates: Partial<AiCoachData>) => {
        setData(prev => {
            const newData = { ...prev, ...updates };
            localStorage.setItem('ai_coach_onboarding', JSON.stringify(newData));
            return newData;
        });
    };

    const clearOnboardingFlow = () => {
        setData(prev => {
            const newData = {
                ...initialData,
                prompt: prev.prompt,
            };
            localStorage.setItem('ai_coach_onboarding', JSON.stringify(newData));
            return newData;
        });
    };

    const resetData = () => {
        setData(initialData);
        localStorage.removeItem('ai_coach_onboarding');
        localStorage.removeItem('generated_meal_plan');
        localStorage.removeItem('generated_workout_plan');
        localStorage.removeItem('plan_generation_date');
    };

    return (
        <AiCoachContext.Provider value={{ data, updateData, clearOnboardingFlow, resetData, isGenerating, setIsGenerating }}>
            {children}
        </AiCoachContext.Provider>
    );
};

export const useAiCoach = () => {
    const context = useContext(AiCoachContext);
    if (!context) {
        throw new Error('useAiCoach must be used within an AiCoachProvider');
    }
    return context;
};
