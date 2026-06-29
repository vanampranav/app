"use client";

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import BottomNavNew from '@/components/BottomNavNew';
import { useAiCoach } from '@/contexts/AiCoachContext';
import { useAuth } from '@/contexts/AuthContext';
import { decrementCredits, getUserProfile, updateUserProfile, saveUserPlan } from '@/shared/firebase';
import { AiCoachModal } from '@/components/AiCoachModal';

export default function Calories() {
    const router = useRouter();
    const { data, updateData } = useAiCoach();
    const { user, refreshProfile } = useAuth();
    const [mounted, setMounted] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [calorieData, setCalorieData] = useState({
        dailyCalories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
    });
    const [isSaveModalOpen, setIsSaveModalOpen] = useState(false);
    const [disclaimerExpanded, setDisclaimerExpanded] = useState(false);

    const checkDraftProfile = async () => {
        if (!user?.uid) return false;
        try {
            const profile = await getUserProfile(user.uid);
            if (!profile) return true;

            const ageDiff = (profile.age || '').toString() !== (data.age || '').toString();
            const weightDiff = (profile.weight || '').toString() !== (data.currentWeight || '').toString();
            const heightDiff = (profile.height || '').toString() !== (data.height || '').toString();
            const targetWeightDiff = (profile.targetWeight || '').toString() !== (data.targetWeight || '').toString();
            const genderDiff = profile.gender !== data.gender;
            const activityDiff = profile.activityLevel !== data.activityLevel;

            return ageDiff || weightDiff || heightDiff || targetWeightDiff || genderDiff || activityDiff;
        } catch (e) {
            return false;
        }
    };

    const handleSaveToProfile = async () => {
        if (!user?.uid) return;
        try {
            await updateUserProfile(user.uid, {
                age: data.age ? parseInt(data.age) : null,
                weight: data.currentWeight ? parseInt(data.currentWeight) : null,
                height: data.height ? parseInt(data.height) : null,
                targetWeight: data.targetWeight ? parseInt(data.targetWeight) : null,
                gender: data.gender,
                activityLevel: data.activityLevel,
                dietaryRestrictions: data.dietaryText,
                updatedAt: new Date()
            });
            await refreshProfile();
            router.push('/schedule');
        } catch (e) {
            console.error("Failed to save to profile:", e);
            router.push('/schedule');
        }
    };

    useEffect(() => {
        const t = requestAnimationFrame(() => setMounted(true));
        return () => cancelAnimationFrame(t);
    }, []);

    useEffect(() => {
        // Only fetch if we have the minimum required data
        if (!data.age || !data.currentWeight || !data.height || !data.gender || !data.activityLevel || !data.prompt) {
            console.log("Waiting for context data...", {
                age: data.age,
                weight: data.currentWeight,
                height: data.height,
                gender: data.gender,
                activity: data.activityLevel,
                prompt: !!data.prompt
            });
            return;
        }

        const fetchInitialTargets = async () => {
            try {
                setLoading(true);
                setError(null);

                // Prepare timeline weeks
                let timelineWeeks = parseInt(data.timelineValue) || 12;
                if (data.timelineUnit === 'months') {
                    timelineWeeks *= 4;
                }

                console.log("Fetching targets with data:", data);

                const response = await fetch('https://yantraprise.com/user', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        userDetails: {
                            age: data.age,
                            weight: data.currentWeight,
                            height: data.height,
                            gender: data.gender,
                            activityLevel: data.activityLevel,
                            healthGoals: data.prompt,
                            targetWeight: data.targetWeight || data.currentWeight,
                            timelineWeeks: timelineWeeks
                        },
                        prompt: data.prompt
                    }),
                });

                if (!response.ok) {
                    const errorJson = await response.json().catch(() => ({}));
                    const errorText = errorJson.detail || await response.text() || 'Failed to fetch profile targets';
                    throw new Error(errorText);
                }

                const result = await response.json();
                console.log("Fetch targets result:", result);

                // Update component state
                setCalorieData({
                    dailyCalories: result.targetCalories,
                    proteinGrams: result.macros.protein_g,
                    carbsGrams: result.macros.carbs_g,
                    fatGrams: result.macros.fat_g
                });

                // Save results in context for the next steps
                updateData({
                    calculatedData: {
                        tdee: result.tdee,
                        targetCalories: result.targetCalories,
                        proteinGrams: result.macros.protein_g,
                        carbsGrams: result.macros.carbs_g,
                        fatGrams: result.macros.fat_g,
                        workoutFocus: result.WorkoutFocus,
                        capped: result.capped,
                        personalizedInsight: result.personalizedInsight
                    }
                });

                setLoading(false);
            } catch (err) {
                console.error("Error fetching targets:", err);
                setError(err instanceof Error ? err.message : "Calculation failed");
                setLoading(false);
                setCalorieData({
                    dailyCalories: 0,
                    proteinGrams: 0,
                    carbsGrams: 0,
                    fatGrams: 0
                });
            }
        };

        fetchInitialTargets();
    }, [data.age, data.currentWeight, data.height, data.gender, data.activityLevel, data.prompt, data.timelineValue, data.timelineUnit]);

    const handleContinue = async () => {
        try {
            if (!user) {
                setError("Please log in to generate a plan.");
                return;
            }

            if (!user.emailVerified && !user.otpVerified && !user.isEmailVerified) {
                setError("Please verify your email before generating a plan. Check your inbox for the verification code!");
                return;
            }

            if ((user.credits || 0) <= 0) {
                setError("You have 0 credits remaining. Please contact support or upgrade to generate more plans.");
                return;
            }

            setLoading(true);
            setError(null);

            // Deduct credit
            await decrementCredits(user.uid);
            await refreshProfile();

            updateData({ mealPlan: null, workoutPlan: null });

            let mealText = '';
            let workoutText = '';

            // 1. Generate Meal Plan (Conditional)
            if (data.helpType === 'meal' || data.helpType === 'both') {
                const mealResponse = await fetch('https://yantraprise.com/mealplan', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        targetCalories: data.calculatedData?.targetCalories,
                        dietaryRestrictions: data.dietaryTags,
                        healthGoals: data.prompt,
                        prompt: data.prompt,
                        targetWeight: data.targetWeight,
                        timelineWeeks: data.timelineUnit === 'months' ? parseInt(data.timelineValue) * 4 : parseInt(data.timelineValue),
                        weight: data.currentWeight,
                        capped: data.calculatedData?.capped
                    }),
                });

                if (!mealResponse.ok) throw new Error('Meal plan generation failed');

                const mealReader = mealResponse.body?.getReader();
                if (mealReader) {
                    while (true) {
                        const { done, value } = await mealReader.read();
                        if (done) break;
                        mealText += new TextDecoder().decode(value);
                    }
                }
            }

            // 2. Generate Workout Plan (Conditional)
            if (data.helpType === 'workout' || data.helpType === 'both') {
                const workoutResponse = await fetch('https://yantraprise/workoutplan', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        goal: data.prompt,
                        workoutFocus: data.calculatedData?.workoutFocus,
                        days: data.workoutDays,
                        targetWeight: data.targetWeight,
                        timelineWeeks: data.timelineUnit === 'months' ? parseInt(data.timelineValue) * 4 : parseInt(data.timelineValue),
                        prompt: data.prompt
                    }),
                });

                if (!workoutResponse.ok) throw new Error('Workout plan generation failed');

                const workoutReader = workoutResponse.body?.getReader();
                if (workoutReader) {
                    while (true) {
                        const { done, value } = await workoutReader.read();
                        if (done) break;
                        workoutText += new TextDecoder().decode(value);
                    }
                }
            }

            // 3. Store results and redirect
            localStorage.setItem('generated_meal_plan_raw', mealText);
            localStorage.setItem('generated_workout_plan_raw', workoutText);
            localStorage.setItem('plan_generation_date', new Date().toISOString());

            updateData({
                mealPlan: mealText,
                workoutPlan: workoutText
            });

            // 4. Auto-save to Firestore
            try {
                const planName = `Fitness Plan - ${new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}`;
                await saveUserPlan(user.uid, planName, {
                    goal: data.prompt,
                    mealPlan: mealText,
                    workoutPlan: workoutText,
                    calculatedData: {
                        tdee: data.calculatedData?.tdee,
                        targetCalories: data.calculatedData?.targetCalories,
                        proteinGrams: data.calculatedData?.proteinGrams,
                        carbsGrams: data.calculatedData?.carbsGrams,
                        fatGrams: data.calculatedData?.fatGrams,
                        workoutFocus: data.calculatedData?.workoutFocus,
                        capped: data.calculatedData?.capped,
                        personalizedInsight: data.calculatedData?.personalizedInsight
                    },
                    planGenerationDate: new Date().toISOString()
                });
                console.log("Plan auto-saved successfully");
            } catch (saveError) {
                console.error("Auto-save failed:", saveError);
                // We don't block the user if auto-save fails, but we log it
            }

            // Check if we need to ask for profile save
            const needsUpdate = await checkDraftProfile();
            if (needsUpdate) {
                setLoading(false);
                setIsSaveModalOpen(true);
            } else {
                router.push('/schedule');
            }
        } catch (err) {
            console.error("Plan generation error:", err);
            setError(err instanceof Error ? err.message : "Generation failed");
            setLoading(false);
        }
    };

    return (
        <div className="relative min-h-screen w-full bg-black overflow-hidden flex flex-col font-sans">
            {/* Background Image with Dark Gradient Overlay */}
            <div
                className="absolute inset-0 z-0"
                style={{
                    backgroundImage: 'url(/sign-up-bg.jpg)',
                    backgroundPosition: 'center',
                    backgroundSize: 'cover',
                    backgroundRepeat: 'no-repeat'
                }}
            >
                <div className="absolute inset-0 bg-gradient-to-b from-black/20 via-black/40 to-black/90" />
            </div>

            {/* Desktop Center / Mobile Drawer Container */}
            <div className="relative z-10 flex flex-1 items-end md:items-center justify-center">
                {/* Content Card / Drawer */}
                <div className={`w-full md:max-w-md bg-[#0D0D0D]/80 backdrop-blur-xl rounded-t-[40px] md:rounded-[40px] border-t md:border border-white/5 px-6 pt-2 pb-12 md:pb-20 h-auto overflow-y-auto custom-scrollbar transition-transform duration-500 ease-out ${mounted ? 'translate-y-0' : 'translate-y-full md:translate-y-4'}`}>
                    {/* Drag Handle (Mobile) */}
                    <div className="flex justify-center mb-6 md:hidden sticky top-0 bg-[#111] py-2 z-20">
                        <div className="w-12 h-1 bg-white/20 rounded-full" />
                    </div>

                    {/* Step Navigation */}
                    <div className="space-y-6">
                        <div className="flex items-center justify-between">
                            <button
                                onClick={() => router.back()}
                                className="flex h-10 w-10 items-center justify-center rounded-full bg-primary text-black hover:bg-primary/90 transition-all active:scale-95 shadow-[0_0_15px_rgba(204,216,83,0.3)]"
                            >
                                <ArrowLeft className="h-5 w-5 stroke-[3]" />
                            </button>
                            <span className="text-[11px] font-black text-white/40 uppercase tracking-widest">Step 4 of 4</span>
                        </div>

                        {/* Progress Bar */}
                        <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                            <div className="h-full bg-primary w-full rounded-full shadow-[0_0_8px_rgba(204,216,83,0.5)]" />
                        </div>
                    </div>

                    {/* Content Section */}
                    <div className="mt-8 space-y-8">
                        <div className="space-y-2">
                            <h1 className="text-[20px] font-black text-white tracking-tight leading-tight">
                                Your personalized daily calorie target is
                            </h1>
                            <p className="text-[13px] font-medium text-white/40 leading-relaxed">
                                Based on your profile and goals
                            </p>
                        </div>

                        {error && (
                            <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl">
                                <p className="text-xs text-red-500 font-bold uppercase tracking-widest mb-1">Unfeasible Goal</p>
                                <p className="text-[13px] text-white/60 leading-relaxed">{error}</p>
                                <div className="flex gap-4 mt-4">
                                    <button
                                        onClick={() => router.push('/ai-coach/goal')}
                                        className="text-[11px] font-black text-primary uppercase tracking-widest hover:underline"
                                    >
                                        Edit Goal
                                    </button>
                                    <button
                                        onClick={() => window.location.reload()}
                                        className="text-[11px] font-black text-white/40 uppercase tracking-widest hover:underline"
                                    >
                                        Try Again
                                    </button>
                                </div>
                            </div>
                        )}

                        {loading ? (
                            <div className="space-y-6">
                                <div className="h-32 rounded-3xl bg-white/5 animate-pulse flex flex-col items-center justify-center p-6 text-center">
                                    <p className="text-primary font-black text-sm uppercase tracking-widest animate-pulse">
                                        {calorieData.dailyCalories > 0
                                            ? (data.helpType === 'meal' ? 'Generating Meal Plan...'
                                                : data.helpType === 'workout' ? 'Generating Workout Plan...'
                                                    : 'Generating Your Plans...')
                                            : 'Calculating Macros...'}
                                    </p>
                                    <p className="text-white/40 text-[11px] mt-2">
                                        {data.helpType === 'workout'
                                            ? 'Crafting your personalized workout schedule'
                                            : 'AI is crafting your tailored fitness journey'}
                                    </p>
                                </div>
                                <div className="grid grid-cols-3 gap-3">
                                    {[1, 2, 3].map((i) => (
                                        <div key={i} className="h-24 rounded-2xl bg-white/5 animate-pulse" />
                                    ))}
                                </div>
                            </div>
                        ) : (
                            <div className="space-y-8">
                                {/* Large Calorie Display */}
                                <div className="relative group">
                                    <div className="absolute inset-0 bg-primary/5 rounded-[32px] blur-2xl group-hover:bg-primary/10 transition-all" />
                                    <div className="relative bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-[32px] p-8 flex flex-col items-center justify-center text-center">
                                        <span className="text-[56px] font-black text-primary tracking-tighter leading-none">
                                            {calorieData.dailyCalories}
                                        </span>
                                        <span className="text-[13px] font-black text-white/40 uppercase tracking-[0.2em] mt-2">
                                            kcal / day
                                        </span>
                                    </div>
                                </div>

                                {/* Macros Grid */}
                                <div className="grid grid-cols-3 gap-3">
                                    {/* Protein */}
                                    <div className="bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-4 flex flex-col items-center gap-1">
                                        <span className="text-[18px] font-black text-white">{calorieData.proteinGrams}g</span>
                                        <span className="text-[10px] font-black text-[#FF6B6B] uppercase tracking-wider">Protein</span>
                                    </div>
                                    {/* Carbs */}
                                    <div className="bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-4 flex flex-col items-center gap-1">
                                        <span className="text-[18px] font-black text-white">{calorieData.carbsGrams}g</span>
                                        <span className="text-[10px] font-black text-[#4ECDC4] uppercase tracking-wider">Carbs</span>
                                    </div>
                                    {/* Fat */}
                                    <div className="bg-black/40 border border-[#2d2d2d] rounded-2xl p-4 flex flex-col items-center gap-1">
                                        <span className="text-[18px] font-black text-white">{calorieData.fatGrams}g</span>
                                        <span className="text-[10px] font-black text-[#FFD93D] uppercase tracking-wider">Fat</span>
                                    </div>
                                </div>



                                {/* Medical Disclaimer */}
                                <div
                                    onClick={() => setDisclaimerExpanded(!disclaimerExpanded)}
                                    className="flex gap-2 p-4 bg-zinc-900/80 hover:bg-zinc-900 rounded-2xl border border-zinc-700/50 cursor-pointer transition-all group"
                                >
                                    <span className="text-sm">⚠️</span>
                                    <p className={`text-[9px] font-medium text-white/60 leading-relaxed transition-all ${disclaimerExpanded ? '' : 'line-clamp-2'}`}>
                                        This site offers health, fitness and nutritional information and is designed for educational purposes only. You should not rely on this information as a substitute for, nor does it replace, professional medical advice, diagnosis, or treatment. If you have any concerns or questions about your health, you should always consult with a physician or other health-care professional. Do not disregard, avoid or delay obtaining medical or health related advice from your health-care professional because of something you may have read on this site. The use of any information provided on this site is solely at your own risk.
                                    </p>
                                </div>

                                <button
                                    onClick={handleContinue}
                                    disabled={!!error || loading || calorieData.dailyCalories === 0}
                                    className="w-full py-4 bg-primary text-black font-black text-sm rounded-full shadow-[0_4px_15px_rgba(204,216,83,0.3)] hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-20 disabled:grayscale disabled:scale-100 disabled:cursor-not-allowed"
                                >
                                    Generate my plan
                                </button>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            <BottomNavNew />

            {/* Profile Update Modal */}
            <AiCoachModal
                isOpen={isSaveModalOpen}
                onClose={() => router.push('/schedule')}
                title="Save to profile?"
                description="You've entered new details. Would you like to update your profile with this information?"
                confirmText="Update profile"
                cancelText="Skip"
                onConfirm={handleSaveToProfile}
                onCancel={() => router.push('/schedule')}
            />
        </div>
    );
}
