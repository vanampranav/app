"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import BottomNavNew from '@/components/BottomNavNew';
import { useAiCoach } from '@/contexts/AiCoachContext';
import { useAuth } from '@/contexts/AuthContext';
import { getUserProfile } from '@/shared/firebase';
import { AiCoachModal } from '@/components/AiCoachModal';
import { extractSpecsFromPrompt } from '@/lib/ai-coach-parser';

export default function Goal() {
    const { data, updateData, clearOnboardingFlow } = useAiCoach();
    const { user } = useAuth();
    const [goal, setGoal] = useState(data.prompt);
    const [mounted, setMounted] = useState(false);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [profileData, setProfileData] = useState<any>(null);
    const [loading, setLoading] = useState(false);
    const router = useRouter();

    useEffect(() => {
        const t = requestAnimationFrame(() => setMounted(true));
        return () => cancelAnimationFrame(t);
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!goal.trim() || loading) return;

        setLoading(true);

        // 1. Extract specs from prompt locally
        const extracted = extractSpecsFromPrompt(goal.trim());
        console.log("Extracted from prompt (local):", extracted);

        // 2. Conditional Reset: Only clear if prompt contains explicit details
        if (Object.keys(extracted).length > 0) {
            clearOnboardingFlow();
            // Handle relative weight even for manual fill if current weight was provided in prompt
            if (!extracted.targetWeight && extracted.currentWeight) {
                if (extracted.weightToLose) {
                    extracted.targetWeight = (parseFloat(extracted.currentWeight) - extracted.weightToLose).toString();
                } else if (extracted.weightToGain) {
                    extracted.targetWeight = (parseFloat(extracted.currentWeight) + extracted.weightToGain).toString();
                }
            }
            updateData({ ...extracted, prompt: goal.trim() });
        } else {
            // No details in prompt, just update prompt and keep existing data
            updateData({ prompt: goal.trim() });
        }

        // 2. Check profile for pre-fill
        if (user?.uid) {
            try {
                const profile = await getUserProfile(user.uid);
                console.log("Profile fetched on Goal page:", profile);

                if (profile) {
                    setProfileData(profile);
                    setIsModalOpen(true);
                    setLoading(false);
                    return;
                }
            } catch (error) {
                console.error("Error fetching profile for pre-fill:", error);
            }
        }

        setLoading(false);
        router.push('/ai-coach/details');
    };

    const handlePreFill = () => {
        if (!profileData) return;

        // 1. Re-extract to ensure we have the latest goal context
        const extracted = extractSpecsFromPrompt(goal.trim());

        // 2. Base data from Profile
        const baseDetails = {
            name: profileData.name || `${profileData.firstName || ''} ${profileData.lastName || ''}`.trim() || data.name,
            age: profileData.age?.toString() || data.age,
            height: profileData.height?.toString() || data.height,
            currentWeight: profileData.weight?.toString() || data.currentWeight,
            targetWeight: profileData.targetWeight?.toString() || data.targetWeight,
            gender: (profileData.gender === 'male' || profileData.gender === 'female' ? profileData.gender : data.gender) as any,
        };

        // 3. Override with Extracted Specs from Prompt (Prompt takes priority)
        const mergedDetails = { ...baseDetails };
        if (extracted.age) mergedDetails.age = extracted.age;
        if (extracted.height) mergedDetails.height = extracted.height;
        if (extracted.currentWeight) mergedDetails.currentWeight = extracted.currentWeight;
        if (extracted.gender) mergedDetails.gender = extracted.gender;
        if (extracted.timelineValue) {
            (mergedDetails as any).timelineValue = extracted.timelineValue;
            (mergedDetails as any).timelineUnit = extracted.timelineUnit;
        }

        // 4. Handle Relative Weight Logic (e.g., "lose 5kg")
        // Target weight calculation: Current - Lose OR Current + Gain
        if (extracted.targetWeight) {
            mergedDetails.targetWeight = extracted.targetWeight;
        } else if (extracted.weightToLose && mergedDetails.currentWeight) {
            mergedDetails.targetWeight = (parseFloat(mergedDetails.currentWeight) - extracted.weightToLose).toString();
        } else if (extracted.weightToGain && mergedDetails.currentWeight) {
            mergedDetails.targetWeight = (parseFloat(mergedDetails.currentWeight) + extracted.weightToGain).toString();
        }

        // 5. Update Context and Redirect
        updateData({
            ...mergedDetails,
            activityLevel: profileData.activityLevel || data.activityLevel,
            dietaryText: (profileData.dietaryRestrictions || profileData.allergies)
                ? [profileData.dietaryRestrictions, profileData.allergies].filter(Boolean).join('. ')
                : data.dietaryText
        });

        router.push('/ai-coach/details');
    };

    return (
        <div className="relative h-screen w-full bg-black overflow-hidden flex flex-col font-sans">
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
                    <div className="flex justify-center mb-6 md:hidden">
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
                            <span className="text-[11px] font-black text-white/40 uppercase tracking-widest">Step 1 of 4</span>
                        </div>

                        {/* Progress Bar */}
                        <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                            <div className="h-full bg-primary w-1/4 rounded-full shadow-[0_0_8px_rgba(204,216,83,0.5)]" />
                        </div>
                    </div>

                    {/* Form Content */}
                    <div className="mt-10 space-y-6">
                        <div className="flex items-center gap-2">
                            <h1 className="text-[22px] font-black text-white tracking-tight">What's your fitness goal?</h1>
                            <span className="text-xl">🔥</span>
                        </div>

                        <form onSubmit={handleSubmit} className="space-y-8">
                            <div className="relative">
                                <input
                                    type="text"
                                    value={goal}
                                    onChange={(e) => setGoal(e.target.value)}
                                    placeholder="Lose 6 kg in 3 months"
                                    className="w-full bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-5 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/30 focus:ring-1 focus:ring-primary/30 transition-all font-medium"
                                />
                                {!goal && (
                                    <span className="absolute right-5 top-1/2 -translate-y-1/2 text-lg">🏋️</span>
                                )}
                            </div>

                            <button
                                type="submit"
                                disabled={!goal.trim() || loading}
                                className="w-full py-4 bg-primary text-black font-black text-sm rounded-full shadow-[0_4px_15_rgba(204,216,83,0.3)] hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-50 disabled:scale-100"
                            >
                                {loading ? 'Analyzing goal...' : 'Create my plan'}
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            <BottomNavNew />

            {/* Profile Pre-fill Modal */}
            <AiCoachModal
                isOpen={isModalOpen}
                onClose={() => router.push('/ai-coach/details')}
                title="Use Existing Profile?"
                description="We found your fitness details in your profile. Would you like to use them to pre-fill your plan details?"
                confirmText="Use My Profile"
                cancelText="Fill Manually"
                onConfirm={handlePreFill}
                onCancel={() => router.push('/ai-coach/details')}
            />
        </div>
    );
}
