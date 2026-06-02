"use client";

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getUserPlans, getCurrentUser } from '@/shared/firebase';
import BottomNavNew from '@/components/BottomNavNew';
import MobileNavDrawer from '@/components/MobileNavDrawer';
import { useEffect } from 'react';
import { useAiCoach } from '@/contexts/AiCoachContext';
import { ChevronRight, Calendar, Sparkles, Mail } from 'lucide-react';

export default function Welcome() {
    const router = useRouter();
    const { isAuthenticated, user, refreshProfile } = useAuth();
    const { resetData } = useAiCoach();
    const [activeDrawer, setActiveDrawer] = useState<'continue' | 'new' | null>(null);
    const [savedPlans, setSavedPlans] = useState<any[]>([]);
    const [loadingPlans, setLoadingPlans] = useState(false);

    const closeDrawer = () => setActiveDrawer(null);

    const handleAction = (action: () => void) => {
        if (!isAuthenticated) {
            router.push('/auth?redirect=/ai-coach/welcome');
            return;
        }
        action();
    };

    useEffect(() => {
        if (isAuthenticated && user?.uid) {
            const fetchPlans = async () => {
                setLoadingPlans(true);
                try {
                    const plans = await getUserPlans(user.uid);
                    setSavedPlans(plans);
                } catch (error) {
                    console.error("Error fetching plans:", error);
                } finally {
                    setLoadingPlans(false);
                }
            };
            fetchPlans();
        }
    }, [isAuthenticated, user]);

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

            {/* Mobile Top Nav (logo + hamburger) */}
            <MobileNavDrawer />

            {/* Main Content */}
            <div className="relative z-10 flex flex-1 flex-col items-center justify-center px-6 pt-32 md:pt-20 pb-32">
                <div className="w-full max-w-md">
                    {/* Verification Alert (For Unverified Redirects) */}
                    {isAuthenticated && user && !user.emailVerified && !user.otpVerified && !user.isEmailVerified && (
                        <div className="mb-8 p-5 bg-red-500/10 border border-red-500/20 rounded-[24px] backdrop-blur-xl animate-in fade-in slide-in-from-top-4 duration-500">
                            <div className="flex flex-col gap-4">
                                <div className="flex items-center gap-3">
                                    <div className="h-10 w-10 flex items-center justify-center bg-red-500/20 rounded-full">
                                        <Mail className="w-5 h-5 text-red-500" />
                                    </div>
                                    <div>
                                        <h4 className="text-sm font-black text-white tracking-tight">Account not verified</h4>
                                        <p className="text-[11px] font-bold text-white/40">Verify your email to getting 10 free credits!</p>
                                    </div>
                                </div>
                                <button
                                    onClick={async () => {
                                        try {
                                            const { triggerOTPVerification } = await import('@/shared/firebase');
                                            await triggerOTPVerification(user.email!, user.uid);
                                            router.push('/auth?isSignUp=true&message=Verification+code+sent!&verified=false');
                                        } catch (e: any) {
                                            console.error("Verification error:", e);
                                        }
                                    }}
                                    className="w-full py-3 bg-red-500 text-white font-black text-[11px] uppercase tracking-widest rounded-xl hover:bg-red-600 transition-colors active:scale-[0.98]"
                                >
                                    Verify Now
                                </button>
                            </div>
                        </div>
                    )}

                    {/* Header */}
                    <div className="space-y-2 mb-10 md:text-center">
                        <h1 className="text-[28px] leading-tight font-black text-white tracking-tight flex items-center justify-center md:justify-center gap-2">
                            Welcome Back! <span className="text-2xl animate-bounce">👋</span>
                        </h1>
                        <p className="text-sm font-medium text-white/50">Ready to continue your fitness journey?</p>
                    </div>

                    {/* Action Cards */}
                    <div className="space-y-4">
                        {/* My Fitness Plan Card */}
                        <button
                            onClick={() => handleAction(() => setActiveDrawer('continue'))}
                            className="w-full text-left group relative overflow-hidden rounded-[24px] border border-[#2d2d2d] bg-black/40 backdrop-blur-xl p-6 transition-all active:scale-[0.98]"
                        >
                            <div className="absolute inset-0 bg-gradient-to-r from-cyan-500/20 to-blue-500/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                            <div className="relative flex items-center gap-5">
                                <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-white/5 border border-white/10">
                                    <span className="text-2xl">🏋🏻</span>
                                </div>
                                <div className="flex-1 space-y-0.5">
                                    <h3 className="text-sm font-black text-white tracking-wide">My fitness plans</h3>
                                    <p className="text-[11px] font-bold text-white/40">View your personalized schedule</p>
                                </div>
                                <div className="h-6 w-6 flex items-center justify-center text-white/30 group-hover:text-white transition-colors">
                                    <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" className="w-5 h-5">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                                    </svg>
                                </div>
                            </div>
                        </button>

                        {/* Start New Plan Card */}
                        <button
                            onClick={() => handleAction(() => {
                                resetData();
                                router.push('/ai-coach/goal');
                            })}
                            className="w-full text-left group relative overflow-hidden rounded-[24px] border border-[#2d2d2d] bg-black/40 backdrop-blur-xl p-6 transition-all active:scale-[0.98]"
                        >
                            <div className="absolute inset-0 bg-gradient-to-r from-emerald-500/20 to-lime-500/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                            <div className="relative flex items-center gap-5">
                                <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-white/5 border border-white/10">
                                    <span className="text-2xl">✨</span>
                                </div>
                                <div className="flex-1 space-y-0.5">
                                    <h3 className="text-sm font-black text-white tracking-wide">Start a new plan</h3>
                                    <p className="text-[11px] font-bold text-white/40">Create a fresh fitness goal</p>
                                </div>
                                <div className="h-6 w-6 flex items-center justify-center text-white/30 group-hover:text-white transition-colors">
                                    <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" className="w-5 h-5">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                                    </svg>
                                </div>
                            </div>
                        </button>
                    </div>
                </div>
            </div>

            {/* Bottom Drawers */}
            <div className={`fixed inset-0 z-50 flex items-end md:items-center justify-center transition-opacity duration-300 ${activeDrawer ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}>
                {/* Backdrop overlay within centered container */}
                <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={closeDrawer} />

                <div className={`relative w-full md:max-w-md bg-[#111] rounded-t-[32px] md:rounded-[40px] border-t md:border border-white/10 px-6 pt-2 pb-32 md:pb-8 h-auto max-h-[85vh] transition-transform duration-500 ease-out flex flex-col ${activeDrawer ? 'translate-y-0' : 'translate-y-full'}`}>
                    {/* Drag Handle Area */}
                    <div className="w-full pt-2 pb-4 flex justify-center">
                        <div className="w-12 h-1 bg-white/20 rounded-full" />
                    </div>

                    {/* Drawer Content */}
                    <div className="pb-4 flex-1 overflow-hidden flex flex-col">
                        {activeDrawer === 'continue' && (
                            <div className="space-y-5 animate-in fade-in slide-in-from-bottom-4 duration-500 flex flex-col flex-1 min-h-0">
                                <div className="space-y-2">
                                    <h2 className="text-[22px] font-black text-white tracking-tight">Your Fitness Plans</h2>
                                    <p className="text-sm font-medium text-white/40 leading-relaxed">
                                        Select a plan to continue your journey or view your progress.
                                    </p>
                                </div>

                                <div className="flex-1 overflow-y-auto pr-2 space-y-3 custom-scrollbar min-h-0">
                                    {loadingPlans ? (
                                        <div className="py-20 flex flex-col items-center justify-center gap-4">
                                            <div className="h-8 w-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                                            <p className="text-xs font-bold text-white/40 uppercase tracking-widest">Loading your plans...</p>
                                        </div>
                                    ) : savedPlans.length > 0 ? (
                                        savedPlans.map((plan) => (
                                            <button
                                                key={plan.id}
                                                onClick={() => router.push(`/schedule?planId=${plan.id}`)}
                                                className="w-full text-left group bg-white/5 border border-white/10 p-5 rounded-3xl hover:border-primary/50 transition-all active:scale-[0.98]"
                                            >
                                                <div className="flex items-start justify-between gap-4">
                                                    <div className="space-y-2 flex-1">
                                                        <div className="flex items-center gap-2">
                                                            <Calendar className="w-3.5 h-3.5 text-primary" />
                                                            <span className="text-[10px] font-black text-primary uppercase tracking-[0.15em]">
                                                                {new Date(plan.createdAt?.seconds * 1000).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
                                                            </span>
                                                        </div>
                                                        <h4 className="text-sm font-black text-white line-clamp-1 group-hover:text-primary transition-colors">{plan.name}</h4>
                                                        <p className="text-[11px] font-medium text-white/40 line-clamp-2 italic leading-relaxed">
                                                            "{plan.goal || 'No goal specified'}"
                                                        </p>
                                                    </div>
                                                    <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-primary transition-all">
                                                        <ChevronRight className="w-4 h-4 text-white group-hover:text-black" />
                                                    </div>
                                                </div>
                                            </button>
                                        ))
                                    ) : (
                                        <div className="py-16 text-center space-y-4">
                                            <div className="h-16 w-16 bg-white/5 rounded-full flex items-center justify-center mx-auto border border-white/10">
                                                <Sparkles className="w-8 h-8 text-white/10" />
                                            </div>
                                            <p className="text-sm font-medium text-white/40">You haven't generated any plans yet.</p>
                                            <button
                                                onClick={() => router.push('/ai-coach/goal')}
                                                className="px-6 py-2 bg-primary/10 border border-primary/20 text-primary rounded-full text-xs font-black uppercase tracking-widest"
                                            >
                                                Create your first plan
                                            </button>
                                        </div>
                                    )}
                                </div>

                                <div className="pt-4 border-t border-white/10">
                                    <button
                                        onClick={() => {
                                            resetData();
                                            router.push('/ai-coach/goal');
                                        }}
                                        className="w-full py-4 text-primary font-black text-sm hover:underline"
                                    >
                                        + Start a fresh new plan
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            <BottomNavNew />
        </div>
    );
}
