"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import BottomNavNew from '@/components/BottomNavNew';
import { useAiCoach } from '@/contexts/AiCoachContext';
import { useAuth } from '@/contexts/AuthContext';

export default function Details() {
    const router = useRouter();
    const { user } = useAuth();
    const { data, updateData } = useAiCoach();
    const [mounted, setMounted] = useState(false);
    const [formData, setFormData] = useState({
        name: data.name,
        age: data.age,
        height: data.height,
        currentWeight: data.currentWeight,
        targetWeight: data.targetWeight,
        timelineValue: data.timelineValue,
        timelineUnit: data.timelineUnit,
        gender: data.gender
    });

    useEffect(() => {
        const t = requestAnimationFrame(() => setMounted(true));
        return () => cancelAnimationFrame(t);
    }, []);

    const isFormValid = formData.name?.trim() !== '' &&
        formData.age?.trim() !== '' &&
        formData.height?.trim() !== '' &&
        formData.currentWeight?.trim() !== '' &&
        formData.targetWeight?.trim() !== '';

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (isFormValid) {
            updateData(formData);
            router.push('/ai-coach/preferences');
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
                            <span className="text-[11px] font-black text-white/40 uppercase tracking-widest">Step 2 of 4</span>
                        </div>

                        {/* Progress Bar */}
                        <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                            <div className="h-full bg-primary w-1/3 rounded-full shadow-[0_0_8px_rgba(204,216,83,0.5)]" />
                        </div>
                    </div>

                    {/* Form Content */}
                    <div className="mt-8 space-y-6">
                        <div className="space-y-2">
                            <div className="flex items-center gap-2">
                                <h1 className="text-[22px] font-black text-white tracking-tight">Nice goal!</h1>
                                <span className="text-2xl">🔥</span>
                            </div>
                            <p className="text-[13px] font-medium text-white/40 leading-relaxed">
                                To build the best plan for you, we need a few quick details.
                            </p>
                        </div>

                        <form onSubmit={handleSubmit} className="space-y-6 md:space-y-8">
                            <div className="space-y-4">
                                {/* Name */}
                                <div className="space-y-2">
                                    <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1 flex items-center">
                                        Name {!formData.name && <span className="text-red-500 ml-1 text-base">*</span>}
                                    </label>
                                    <input
                                        type="text"
                                        value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                        placeholder="Enter your name"
                                        className="w-full bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/30 focus:ring-1 focus:ring-primary/30 transition-all font-medium"
                                    />
                                </div>

                                {/* Age and Height */}
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1 flex items-center">
                                            Age {!formData.age && <span className="text-red-500 ml-1 text-base">*</span>}
                                        </label>
                                        <input
                                            type="number"
                                            value={formData.age}
                                            onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                                            placeholder="25"
                                            className="w-full bg-black/40 border border-[#2d2d2d] rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/50 transition-all font-medium"
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1 flex items-center">
                                            Height (cm) {!formData.height && <span className="text-red-500 ml-1 text-base">*</span>}
                                        </label>
                                        <input
                                            type="number"
                                            value={formData.height}
                                            onChange={(e) => setFormData({ ...formData, height: e.target.value })}
                                            placeholder="170"
                                            className="w-full bg-black/40 border border-[#2d2d2d] rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/50 transition-all font-medium"
                                        />
                                    </div>
                                </div>

                                {/* Gender Selection */}
                                <div className="space-y-2">
                                    <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1">Gender</label>
                                    <div className="grid grid-cols-2 gap-4">
                                        <button
                                            type="button"
                                            onClick={() => setFormData({ ...formData, gender: 'male' })}
                                            className={`py-4 rounded-2xl border text-sm font-black transition-all ${formData.gender === 'male'
                                                ? 'border-primary bg-primary/20 text-primary'
                                                : 'border-white/5 bg-[#1A1A1A]/40 text-white/40 hover:border-white/10'
                                                }`}
                                        >
                                            Male ♂️
                                        </button>
                                        <button
                                            type="button"
                                            onClick={() => setFormData({ ...formData, gender: 'female' })}
                                            className={`py-4 rounded-2xl border text-sm font-black transition-all ${formData.gender === 'female'
                                                ? 'border-primary bg-primary/20 text-primary'
                                                : 'border-white/5 bg-[#1A1A1A]/40 text-white/40 hover:border-white/10'
                                                }`}
                                        >
                                            Female ♀️
                                        </button>
                                    </div>
                                </div>

                                {/* Weights */}
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1 text-xs flex items-center">
                                            Current Weight (kg) {!formData.currentWeight && <span className="text-red-500 ml-1 text-base">*</span>}
                                        </label>
                                        <input
                                            type="number"
                                            value={formData.currentWeight}
                                            onChange={(e) => setFormData({ ...formData, currentWeight: e.target.value })}
                                            placeholder="80"
                                            className="w-full bg-black/40 border border-[#2d2d2d] rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/50 transition-all font-medium"
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1 text-xs flex items-center">
                                            Target Weight (kg) {!formData.targetWeight && <span className="text-red-500 ml-1 text-base">*</span>}
                                        </label>
                                        <input
                                            type="number"
                                            value={formData.targetWeight}
                                            onChange={(e) => setFormData({ ...formData, targetWeight: e.target.value })}
                                            placeholder="74"
                                            className="w-full bg-black/40 border border-[#2d2d2d] rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/50 transition-all font-medium"
                                        />
                                    </div>
                                </div>

                                {/* Timeline */}
                                <div className="space-y-2">
                                    <label className="text-[11px] font-black text-white/40 uppercase tracking-widest ml-1">Target Timeline</label>
                                    <div className="flex gap-3 items-center">
                                        <input
                                            type="number"
                                            value={formData.timelineValue}
                                            onChange={(e) => setFormData({ ...formData, timelineValue: e.target.value })}
                                            placeholder="3"
                                            className="w-[80px] bg-[#1A1A1A]/60 backdrop-blur-md border border-white/5 rounded-2xl p-4 text-sm text-white placeholder:text-white/20 focus:outline-none focus:border-primary/30 focus:ring-1 focus:ring-primary/30 transition-all font-medium"
                                        />
                                        <div className="flex flex-1 items-center rounded-2xl bg-[#1A1A1A]/60 backdrop-blur-md p-1 border border-white/5 h-[52px]">
                                            <button
                                                type="button"
                                                onClick={() => setFormData({ ...formData, timelineUnit: 'weeks' })}
                                                className={`flex-1 rounded-xl h-full text-xs font-black transition-all ${formData.timelineUnit === 'weeks'
                                                    ? 'bg-[#0095FF] text-white shadow-lg'
                                                    : 'text-white/40 hover:text-white'
                                                    }`}
                                            >
                                                Weeks
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => setFormData({ ...formData, timelineUnit: 'months' })}
                                                className={`flex-1 rounded-xl h-full text-xs font-black transition-all ${formData.timelineUnit === 'months'
                                                    ? 'bg-[#0095FF] text-white shadow-lg'
                                                    : 'text-white/40 hover:text-white'
                                                    }`}
                                            >
                                                Months
                                            </button>
                                        </div>
                                    </div>
                                    <p className="text-[10px] font-medium text-white/20 ml-1">This helps us calculate accurate calorie & workout targets.</p>
                                </div>
                            </div>

                            <button
                                type="submit"
                                disabled={!isFormValid}
                                className={`w-full py-4 rounded-full font-black text-sm transition-all shadow-[0_4px_15px_rgba(204,216,83,0.3)] ${isFormValid
                                    ? 'bg-primary text-black hover:scale-[1.02] active:scale-[0.98]'
                                    : 'bg-primary/20 text-black/40 cursor-not-allowed opacity-50'
                                    }`}
                            >
                                Continue
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            <BottomNavNew />
        </div>
    );
}
