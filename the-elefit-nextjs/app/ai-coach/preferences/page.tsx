"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import BottomNavNew from '@/components/BottomNavNew';
import { useAiCoach, HelpType, ActivityLevel } from '@/contexts/AiCoachContext';

export default function Preferences() {
    const router = useRouter();
    const { data, updateData } = useAiCoach();
    const [mounted, setMounted] = useState(false);
    const [helpType, setHelpType] = useState<HelpType>(data.helpType);
    const [activityLevel, setActivityLevel] = useState<ActivityLevel>(data.activityLevel);
    const [workoutDays, setWorkoutDays] = useState(data.workoutDays);
    const [dietary, setDietary] = useState(data.dietaryText);
    const [dietaryTags, setDietaryTags] = useState<string[]>(data.dietaryTags);

    useEffect(() => {
        const t = requestAnimationFrame(() => setMounted(true));
        return () => cancelAnimationFrame(t);
    }, []);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        updateData({
            helpType,
            activityLevel,
            workoutDays,
            dietaryText: dietary,
            dietaryTags
        });
        router.push('/ai-coach/calories');
    };

    const activityLevels = [
        { id: 'sedentary', label: 'Sedentary', icon: '🛋️', desc: 'Little to no exercise' },
        { id: 'light', label: 'Light', icon: '🚶', desc: 'Exercise 1-2 days/week' },
        { id: 'moderate', label: 'Moderate', icon: '🏃', desc: 'Exercise 3-5 days/week' },
        { id: 'active', label: 'Active', icon: '💪', desc: 'Exercise 6-7 days/week' },
        { id: 'very-active', label: 'Very Active', icon: '🔥', desc: 'Intense daily exercise' },
    ];

    const dietTags = ['Vegetarian', 'Vegan', 'No dairy', 'No eggs'];

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
                            <span className="text-[11px] font-black text-white/40 uppercase tracking-widest">Step 3 of 4</span>
                        </div>

                        {/* Progress Bar */}
                        <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                            <div className="h-full bg-primary w-3/4 rounded-full shadow-[0_0_8px_rgba(204,216,83,0.5)]" />
                        </div>
                    </div>

                    {/* Form Content */}
                    <div className="mt-8 space-y-8">
                        <form onSubmit={handleSubmit} className="space-y-10">
                            {/* Help Type */}
                            <div className="space-y-4">
                                <h1 className="text-[20px] font-black text-white tracking-tight leading-tight">What would you like help with?</h1>
                                <div className="grid grid-cols-3 gap-3">
                                    {[
                                        { id: 'meal', icon: '🍽️', label: 'Meal' },
                                        { id: 'workout', icon: '🏋️', label: 'Workout' },
                                        { id: 'both', icon: '🔥', label: 'Both', badge: 'Best' },
                                    ].map((option) => (
                                        <button
                                            key={option.id}
                                            type="button"
                                            onClick={() => setHelpType(option.id as HelpType)}
                                            className={`relative flex flex-col items-center justify-center gap-3 rounded-[32px] border h-[120px] transition-all ${helpType === option.id
                                                ? 'border-primary bg-primary/10 shadow-[0_0_20px_rgba(204,216,83,0.15)]'
                                                : 'border-white/5 bg-[#1A1A1A]/40 hover:border-white/10'
                                                }`}
                                        >
                                            <span className="text-3xl">{option.icon}</span>
                                            <span className={`text-[13px] font-black tracking-tight ${helpType === option.id ? 'text-white' : 'text-white/40'}`}>
                                                {option.label}
                                            </span>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Activity Level */}
                            <div className="space-y-4">
                                <h2 className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1">Activity Level</h2>
                                <div className="grid grid-cols-2 gap-3">
                                    {activityLevels.map((level) => (
                                        <button
                                            key={level.id}
                                            type="button"
                                            onClick={() => setActivityLevel(level.id as ActivityLevel)}
                                            className={`flex items-center gap-3 rounded-2xl border px-4 py-5 transition-all w-full text-left ${activityLevel === level.id
                                                ? 'border-primary bg-primary/10'
                                                : 'border-white/5 bg-[#1A1A1A]/40 hover:border-white/10'
                                                }`}
                                        >
                                            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/5 text-2xl shrink-0">
                                                {level.icon}
                                            </div>
                                            <div className="flex flex-col min-w-0">
                                                <span className={`text-[14px] font-black ${activityLevel === level.id ? 'text-white' : 'text-white'}`}>
                                                    {level.label}
                                                </span>
                                                <span className="text-[10px] font-medium text-white/30 truncate">
                                                    {level.desc}
                                                </span>
                                            </div>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Workout Days */}
                            <div className="space-y-4">
                                <div className="space-y-1">
                                    <h2 className="text-[14px] font-black text-white tracking-tight ml-1">Workout days per week</h2>
                                    <p className="text-[12px] font-bold text-primary ml-1 tracking-tight">
                                        {workoutDays} days - {workoutDays <= 2 ? 'Minimal & consistent' : workoutDays <= 4 ? 'Balanced & sustainable' : 'Elite & intensive'}
                                    </p>
                                </div>
                                <div className="space-y-4">
                                    <div className="relative flex items-center h-6">
                                        <div className="absolute w-full h-1.5 bg-white/10 rounded-full" />
                                        <div
                                            className="absolute h-1.5 bg-[#0095FF] rounded-full transition-all duration-300"
                                            style={{ width: `${((workoutDays - 1) / 6) * 100}%` }}
                                        />
                                        <input
                                            type="range"
                                            min="1"
                                            max="7"
                                            value={workoutDays}
                                            onChange={(e) => setWorkoutDays(Number(e.target.value))}
                                            className="absolute w-full appearance-none bg-transparent cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:shadow-lg [&::-moz-range-thumb]:h-5 [&::-moz-range-thumb]:w-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-white [&::-moz-range-thumb]:shadow-lg"
                                        />
                                    </div>
                                    <div className="flex justify-between text-[11px] font-bold text-white/30 tracking-tight px-1">
                                        <span>1 Day</span>
                                        <span>7 Day</span>
                                    </div>
                                </div>
                            </div>

                            {/* Dietary Preferences */}
                            <div className="space-y-4">
                                <h2 className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1">Dietary Preferences</h2>
                                <div className="relative">
                                    <input
                                        type="text"
                                        value={dietary}
                                        onChange={(e) => setDietary(e.target.value)}
                                        placeholder="Eg., Vegetarian, no dairy"
                                        className="w-full bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-5 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/30 focus:ring-1 focus:ring-primary/30 transition-all font-medium"
                                    />
                                </div>
                                <div className="flex flex-wrap gap-2">
                                    {dietTags.map((tag) => (
                                        <button
                                            key={tag}
                                            type="button"
                                            onClick={() => {
                                                if (dietaryTags.includes(tag)) {
                                                    setDietaryTags(dietaryTags.filter(t => t !== tag));
                                                } else {
                                                    setDietaryTags([...dietaryTags, tag]);
                                                }
                                            }}
                                            className={`px-4 py-2 rounded-full border text-[10px] font-black uppercase tracking-tight transition-all ${dietaryTags.includes(tag)
                                                ? 'bg-white text-black border-white'
                                                : 'bg-white/5 text-white/40 border-white/10 hover:border-white/20'
                                                }`}
                                        >
                                            {tag}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <button
                                type="submit"
                                className="w-full py-4 bg-primary text-black font-black text-sm rounded-full shadow-[0_4px_15px_rgba(204,216,83,0.3)] hover:scale-[1.02] active:scale-[0.98] transition-all"
                            >
                                Save profile & proceed
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            <BottomNavNew />
        </div>
    );
}
