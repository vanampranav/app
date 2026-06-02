"use client";

import { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronLeft, ChevronRight, ChevronDown, Download, ThumbsUp, ThumbsDown, ArrowLeft, Heart } from 'lucide-react';
import BottomNavNew from '@/components/BottomNavNew';
import { Header } from '@/components/Header';
import MobileNavDrawer from '@/components/MobileNavDrawer';
import { useAiCoach } from '@/contexts/AiCoachContext';
import { parseMealPlan, parseWorkoutPlan, WeeklyMeals, WeeklyWorkouts } from '@/lib/ai-coach-parser';
import { saveUserPlan, getPlanById, getCurrentUser } from '@/shared/firebase';
import { useSearchParams } from 'next/navigation';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { generatePlanPDF } from '@/lib/pdf-utils';
import { getShopifyProducts, ShopifyProduct } from '@/lib/shopify';
import Image from 'next/image';

const DAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const MEAL_TIMES = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

const MEAL_ICONS: Record<string, string> = {
    Breakfast: '🌅',
    Lunch: '🍽️',
    Snacks: '🥜',
    Dinner: '🌙',
};

// Products will be fetched from Shopify
const SUGGESTED_PRODUCTS_DEFAULT = [
    { name: 'Loading products...', price: '', image: '⏳' },
];

import { ProtectedRoute } from '@/components/ProtectedRoute';

export default function Schedule() {
    return (
        <ProtectedRoute>
            <ScheduleContent />
        </ProtectedRoute>
    );
}

function ScheduleContent() {
    const router = useRouter();
    const { data } = useAiCoach();
    const searchParams = useSearchParams();
    const planId = searchParams.get('planId');
    const [savedPlanData, setSavedPlanData] = useState<any>(null);
    const [selectedDayIndex, setSelectedDayIndex] = useState(0);
    const [activeTab, setActiveTab] = useState<'meals' | 'workout' | 'suggestions'>('meals');
    const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({});
    const [isSaveModalOpen, setIsSaveModalOpen] = useState(false);
    const [planName, setPlanName] = useState('My Custom Plan');
    const [isSaving, setIsSaving] = useState(false);
    const [isPlanSaved, setIsPlanSaved] = useState(false);
    const [isSaveEditDrawerOpen, setIsSaveEditDrawerOpen] = useState(false);
    const [products, setProducts] = useState<ShopifyProduct[]>([]);
    const [showAllProducts, setShowAllProducts] = useState(false);

    // Initialize accordions based on screen size
    useEffect(() => {
        const isDesktop = window.innerWidth >= 768;
        if (isDesktop) {
            setExpandedSections({
                Breakfast: true,
                Lunch: true,
                Snacks: true,
                Dinner: true,
                ...DAYS.reduce((acc, day) => ({ ...acc, [day]: true }), {})
            });
        } else {
            setExpandedSections({});
        }
    }, []);


    // Fetch plan if planId is present
    useEffect(() => {
        if (planId) {
            const fetchPlan = async () => {
                const user = getCurrentUser();
                if (user) {
                    const fetchedPlan = await getPlanById(user.uid, planId);
                    if (fetchedPlan) {
                        setSavedPlanData(fetchedPlan);
                    }
                }
            };
            fetchPlan();
        }
    }, [planId]);

    // Fetch Shopify products
    useEffect(() => {
        const fetchProducts = async () => {
            try {
                const shopifyProducts = await getShopifyProducts(20);
                setProducts(shopifyProducts);
            } catch (error) {
                console.error("Error fetching Shopify products:", error);
            }
        };
        fetchProducts();
    }, []);

    // Parse plans
    const parsedMeals = useMemo<WeeklyMeals | null>(() => {
        const raw = savedPlanData?.mealPlan || data.mealPlan || localStorage.getItem('generated_meal_plan_raw');
        return raw ? parseMealPlan(raw) : null;
    }, [data.mealPlan, savedPlanData]);

    const parsedWorkouts = useMemo<WeeklyWorkouts | null>(() => {
        const raw = savedPlanData?.workoutPlan || data.workoutPlan || localStorage.getItem('generated_workout_plan_raw');
        return raw ? parseWorkoutPlan(raw) : null;
    }, [data.workoutPlan, savedPlanData]);

    // Prioritize specific products
    const sortedProducts = useMemo(() => {
        const priorityTitles = [
            "Smart Body Fat Scale with Bright LED Display & 14 Core Metrics",
            "Lifting Straps BLACK for Weightlifting, Bodybuilding, Powerlifting & Deadlifts – Extra-Long 18” Cotton Straps with Padded Neoprene Wrist Support",
            "Lifting Grips GREEN – Built to Lift Heavy. Built to Last.",
            "Performance Lifting Belt WHITE"
        ];

        return [...products].sort((a, b) => {
            const indexA = priorityTitles.indexOf(a.title);
            const indexB = priorityTitles.indexOf(b.title);

            if (indexA !== -1 && indexB !== -1) return indexA - indexB;
            if (indexA !== -1) return -1;
            if (indexB !== -1) return 1;
            return 0;
        });
    }, [products]);

    // Plan header data (either from saved plan or current context)
    const headerData = {
        prompt: savedPlanData?.name || data.prompt || "AI Coach",
        calories: savedPlanData?.calculatedData?.targetCalories || data.calculatedData?.targetCalories || 0,
        workoutFocus: savedPlanData?.calculatedData?.workoutFocus || data.calculatedData?.workoutFocus || 'GENERAL',
        genDate: savedPlanData?.planGenerationDate || localStorage.getItem('plan_generation_date')
    };

    // Calculate dates
    const scheduleDates = useMemo(() => {
        const genDateStr = headerData.genDate;
        const startDate = genDateStr ? new Date(genDateStr) : new Date();
        const shortDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

        return Array.from({ length: 7 }, (_, i) => {
            const date = new Date(startDate);
            date.setDate(startDate.getDate() + i);
            return {
                dayName: shortDays[date.getDay()],
                dateNum: date.getDate().toString().padStart(2, '0'),
                fullDate: date
            };
        });
    }, [headerData.genDate]);

    const toggleSection = (id: string) => {
        setExpandedSections(prev => ({ ...prev, [id]: !prev[id] }));
    };

    const handlePrevDay = () => setSelectedDayIndex((prev) => Math.max(0, prev - 1));
    const handleNextDay = () => setSelectedDayIndex((prev) => Math.min(6, prev + 1));

    const CollapsibleSection = ({
        id,
        title,
        icon,
        rightLabel,
        children
    }: {
        id: string;
        title: string;
        icon?: string | React.ReactNode;
        rightLabel?: string;
        children: React.ReactNode;
    }) => {
        const isExpanded = expandedSections[id];
        const iconLabel = id === 'Breakfast' ? '☀️' : id === 'Lunch' ? '🍽️' : id === 'Snacks' ? '🍯' : id === 'Dinner' ? '🌙' : icon;

        return (
            <div className={`rounded-2xl border border-[#212121] bg-[#0c0c0c] overflow-hidden transition-all h-fit ${isExpanded ? 'pb-4' : 'pb-0 shadow-[0_8px_20px_rgba(0,0,0,0.3)]'}`}>
                <button
                    onClick={() => toggleSection(id)}
                    className="flex w-full items-center justify-between p-4 md:p-5 hover:bg-[#1a1a1a] transition-colors"
                >
                    <div className="flex items-center gap-3">
                        <ChevronDown className={`h-4 w-4 text-[#898989] transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`} />
                        <span className="font-bold text-[#898989] text-[11px] md:text-xs uppercase tracking-[0.1em]">{title}</span>
                    </div>
                    <div className="flex items-center gap-3">
                        {rightLabel && <span className="text-[10px] md:text-xs font-bold text-primary uppercase tracking-widest">{rightLabel}</span>}
                        <div className="flex items-center gap-2">
                            <span className="text-base md:text-lg grayscale-0">{iconLabel}</span>
                        </div>
                    </div>
                </button>
                <div className={`px-4 md:px-5 space-y-3 overflow-hidden transition-all duration-300 ${isExpanded ? 'max-h-[1000px] opacity-100' : 'max-h-0 opacity-0'}`}>
                    <div className="pt-2">
                        {children}
                    </div>
                </div>
            </div>
        );
    };

    return (
        <div className="relative min-h-screen w-full bg-[#0c0c0c] text-white selection:bg-primary selection:text-black">
            {/* Desktop Header */}
            <div className="hidden md:block">
                <Header />
            </div>

            {/* Mobile Header with Hamburger */}
            <MobileNavDrawer title="Weekly Schedule" />

            {/* Content Container */}
            <div className="relative z-10 px-4 md:px-8 py-6 md:py-8 pb-40 md:pb-32">
                <div className="mx-auto max-w-7xl">

                    {/* Page Header */}
                    <div className="relative flex items-center justify-center md:mb-12 mb-8">
                        {/* Back Arrow - Responsive Position */}
                        <button
                            onClick={() => router.back()}
                            className="absolute md:left-0 left-0 h-10 w-10 flex items-center justify-center rounded-full md:bg-primary bg-transparent md:text-black text-white hover:bg-primary/90 transition-all md:shadow-[0_0_15px_rgba(204,216,83,0.3)]"
                        >
                            <ArrowLeft className="h-6 w-6" />
                        </button>

                        {/* Title - Responsive Alignment */}
                        <div className="flex items-center gap-3 md:justify-center w-full max-sm:pl-10">
                            <span className="text-2xl hidden md:inline">📅</span>
                            <h1 className="text-xl md:text-3xl font-bold tracking-tight text-white">Weekly Schedule</h1>
                        </div>

                        {/* Action Buttons - Right End */}
                        <div className="absolute right-0 flex items-center gap-2">
                            {/* Download Button (Mobile Only) */}
                            <button
                                onClick={() => generatePlanPDF({ headerData, parsedMeals, parsedWorkouts, scheduleDates })}
                                className="md:hidden h-10 w-10 flex items-center justify-center rounded-full bg-white/5 text-white hover:bg-white/10 transition-all border border-white/10 active:scale-95 group"
                                title="Download Plan"
                            >
                                <Download className="h-5 w-5 group-hover:translate-y-0.5 transition-transform" />
                            </button>

                            {/* Heart (Favorite) Button */}
                            <button
                                onClick={() => setIsSaveModalOpen(true)}
                                className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 text-white hover:bg-white/10 transition-all border border-white/10 active:scale-95 group"
                                title="Add to Favorites"
                            >
                                <Heart className="h-5 w-5 group-hover:fill-primary group-hover:text-primary transition-colors" />
                            </button>
                        </div>
                    </div>
                    {/* Date Selector Navigation */}
                    <div className="flex items-center justify-between md:justify-center gap-4 md:gap-8 mb-12">
                        <button
                            onClick={handlePrevDay}
                            disabled={selectedDayIndex === 0}
                            className={`flex h-10 w-10 items-center justify-center rounded-full transition-all flex-shrink-0 ${selectedDayIndex === 0 ? 'text-white/10' : 'text-[#898989] hover:text-white'}`}
                        >
                            <ChevronLeft className="h-8 w-8" />
                        </button>

                        <div className="flex items-center justify-between md:justify-center gap-4 md:gap-8 overflow-x-auto no-scrollbar pb-2 flex-grow max-w-xl">
                            {scheduleDates.map((dateObj, idx) => {
                                const isActive = idx === selectedDayIndex;
                                return (
                                    <button
                                        key={dateObj.dayName}
                                        onClick={() => setSelectedDayIndex(idx)}
                                        className="flex flex-col items-center gap-2 transition-opacity duration-300 flex-shrink-0"
                                    >
                                        {/* Yellow Dot Above */}
                                        <div className={`h-1.5 w-1.5 rounded-full bg-primary transition-all duration-300 ${isActive ? 'scale-100 opacity-100 shadow-[0_0_8px_rgba(204,216,83,1)]' : 'scale-0 opacity-0'}`} />

                                        <div className="flex flex-col items-center">
                                            <span className={`text-lg md:text-xl font-bold transition-colors ${isActive ? 'text-white' : 'text-[#454545]'}`}>
                                                {dateObj.dateNum}
                                            </span>
                                            <span className={`text-[10px] font-bold uppercase tracking-widest transition-colors ${isActive ? 'text-white md:text-[#898989]' : 'text-[#454545]'}`}>
                                                {dateObj.dayName}
                                            </span>
                                        </div>

                                        {/* Yellow Underline Below */}
                                        <div className={`h-[2px] rounded-full bg-primary transition-all duration-300 ${isActive ? 'w-full opacity-100' : 'w-0 opacity-0'}`} />
                                    </button>
                                );
                            })}
                        </div>

                        <button
                            onClick={handleNextDay}
                            disabled={selectedDayIndex === 6}
                            className={`flex h-10 w-10 items-center justify-center rounded-full transition-all flex-shrink-0 ${selectedDayIndex === 6 ? 'text-white/10' : 'text-[#898989] hover:text-white'}`}
                        >
                            <ChevronRight className="h-8 w-8" />
                        </button>
                    </div>

                    {/* Main Plan Container "Plan Box" */}
                    <div className="rounded-[32px] bg-[#111111] border border-[#212121] overflow-hidden shadow-2xl">

                        {/* Plan Header section in plan box */}
                        <div className="bg-[#1a1c14] border-b border-[#212121] px-6 md:px-8 py-6 flex items-center justify-between gap-6">
                            <div className="space-y-2">
                                <h2 className="text-sm md:text-lg font-bold text-white tracking-tight flex items-baseline gap-2">
                                    <span className="text-[#898989] font-black uppercase text-[10px] md:text-xs tracking-widest whitespace-nowrap">Plan Goal:</span>
                                    {headerData.prompt}
                                </h2>
                                <div className="flex items-center gap-4">
                                    <div className="flex items-center gap-2 bg-[#0c0c0c] px-3 py-1 rounded-lg border border-[#212121]">
                                        <span className="text-sm">🗓️</span>
                                        <span className="text-[10px] md:text-xs text-[#898989] font-bold uppercase tracking-wider">Duration: <span className="text-primary">7 Days</span></span>
                                    </div>
                                    <div className="flex items-center gap-2 bg-[#0c0c0c] px-3 py-1 rounded-lg border border-[#212121]">
                                        <span className="text-sm">🔥</span>
                                        <span className="text-[10px] md:text-xs text-primary font-black uppercase tracking-wider">{headerData.calories} kcal</span>
                                    </div>
                                </div>
                            </div>

                            <button
                                onClick={() => generatePlanPDF({ headerData, parsedMeals, parsedWorkouts, scheduleDates })}
                                className="hidden md:flex items-center justify-center md:w-auto md:h-auto md:bg-transparent md:border md:border-primary/30 text-primary font-bold text-xs uppercase tracking-widest md:px-6 md:py-2.5 md:rounded-xl hover:bg-primary/5 transition-all group"
                            >
                                <Download className="md:h-4 md:w-4 group-hover:translate-y-0.5 transition-transform" />
                                <span className="hidden md:inline ml-2">Download Plan</span>
                            </button>
                        </div>

                        {/* Robust Centered Tabs Container */}
                        <div className="bg-[#0c0c0c]/50 px-4 md:px-8 py-4 border-b border-[#212121]">
                            <div className="flex items-center justify-center gap-10 md:gap-12 mx-auto w-fit">
                                {(['meals', 'workout', 'suggestions'] as const).map((tab) => {
                                    const isActive = activeTab === tab;
                                    const labels = { meals: 'Meal Plans', workout: 'Workout', suggestions: 'Plan Suggestions' };
                                    const icons = { meals: '🍴', workout: '🏋️', suggestions: '💡' };

                                    return (
                                        <button
                                            key={tab}
                                            onClick={() => setActiveTab(tab)}
                                            className="group relative py-2 flex items-center gap-2"
                                        >
                                            <div className="flex items-center gap-2">
                                                <span className={`text-base transition-opacity ${isActive ? 'opacity-100' : 'opacity-40 group-hover:opacity-100'}`}>{icons[tab]}</span>
                                                <span className={`text-[10px] md:text-[11px] font-black uppercase tracking-[0.1em] md:tracking-[0.2em] transition-colors ${isActive ? 'text-primary' : 'text-[#898989] group-hover:text-white'} ${!isActive ? 'hidden md:inline' : ''}`}>
                                                    {labels[tab]}
                                                </span>
                                            </div>
                                            {isActive && (
                                                <div className="absolute -bottom-4 left-0 right-0 h-[3px] bg-primary rounded-full shadow-[0_0_8px_rgba(204,216,83,0.5)]" />
                                            )}
                                        </button>
                                    );
                                })}
                            </div>
                        </div>

                        {/* Content Body */}
                        <div className="p-6 md:p-8 space-y-12">
                            {activeTab === 'meals' ? (
                                <>
                                    {/* Goal */}
                                    <div className="flex items-center justify-between gap-2 mb-6">
                                        <div className="flex items-center gap-3">
                                            <span className="text-sm font-bold text-white uppercase tracking-widest">DAILY INTAKE</span>
                                            <div className="flex items-center gap-1.5 bg-primary/10 px-3 py-1 rounded-full border border-primary/20">
                                                <span className="text-sm">🔥</span>
                                                <span className="text-sm font-black text-primary tracking-tighter">{headerData.calories} kcal</span>
                                            </div>
                                        </div>

                                        {/* Desktop Only Navigation Arrows */}
                                        <div className="hidden md:flex items-center gap-4">
                                            <button
                                                onClick={handlePrevDay}
                                                disabled={selectedDayIndex === 0}
                                                className={`h-11 w-11 flex items-center justify-center rounded-full border border-[#212121] bg-[#1a1a1a] transition-all ${selectedDayIndex === 0 ? 'opacity-20 cursor-not-allowed' : 'text-[#898989] hover:text-white hover:border-white/40 active:scale-95'}`}
                                            >
                                                <ChevronLeft className="h-6 w-6" />
                                            </button>
                                            <button
                                                onClick={handleNextDay}
                                                disabled={selectedDayIndex === 6}
                                                className={`h-11 w-11 flex items-center justify-center rounded-full border border-[#212121] bg-[#1a1a1a] transition-all ${selectedDayIndex === 6 ? 'opacity-20 cursor-not-allowed' : 'text-[#898989] hover:text-white hover:border-white/40 active:scale-95'}`}
                                            >
                                                <ChevronRight className="h-6 w-6" />
                                            </button>
                                        </div>
                                    </div>

                                    {/* Meals Grid */}
                                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 items-start">
                                        {MEAL_TIMES.map((mealTime) => {
                                            const mealsForDay = parsedMeals ? parsedMeals[selectedDayIndex]?.[mealTime] || [] : [];
                                            return (
                                                <CollapsibleSection
                                                    key={mealTime}
                                                    id={mealTime}
                                                    title={mealTime}
                                                    icon={MEAL_ICONS[mealTime]}
                                                >
                                                    <div className="space-y-4">
                                                        {mealsForDay.length > 0 ? (
                                                            mealsForDay.map((item: any, idx: number) => (
                                                                <div key={idx} className="space-y-3 pb-4 border-b border-[#212121] last:border-0 last:pb-0 group">
                                                                    <div className="space-y-1">
                                                                        <p className="font-black text-white text-sm tracking-tight">{item.name}</p>
                                                                        <p className="text-[10px] font-black uppercase tracking-widest text-primary">{item.quantity}</p>
                                                                    </div>
                                                                    <div className="bg-[#1a1a1a] rounded-xl p-3 border border-[#212121]/50">
                                                                        <p className="text-[10px] font-bold text-[#898989] uppercase tracking-wider flex items-center gap-2">
                                                                            <span>🔥 {item.calories} KCAL</span>
                                                                            <span className="h-1 w-1 rounded-full bg-[#454545]" />
                                                                            <span>💪 {item.macro}</span>
                                                                        </p>
                                                                    </div>
                                                                </div>
                                                            ))
                                                        ) : (
                                                            <p className="text-[10px] text-[#454545] py-4 text-center">No meals planned for this time.</p>
                                                        )}
                                                    </div>
                                                </CollapsibleSection>
                                            );
                                        })}
                                    </div>
                                </>
                            ) : activeTab === 'workout' ? (
                                <>
                                    {/* Goal */}
                                    <div className="relative flex items-center justify-center mb-6">
                                        <div className="flex items-center gap-2">
                                            <span className="text-lg font-bold uppercase tracking-widest text-[#BFAFAF]">Focus</span>
                                            <span className="h-px w-4 bg-[#BFAFAF]" />
                                            <span className="text-lg md:text-xl font-black text-primary uppercase tracking-tighter">
                                                {headerData.workoutFocus}
                                            </span>
                                        </div>

                                        {/* Desktop Only Navigation Arrows */}
                                        <div className="absolute right-0 hidden md:flex items-center gap-4">
                                            <button
                                                onClick={handlePrevDay}
                                                disabled={selectedDayIndex === 0}
                                                className={`h-11 w-11 flex items-center justify-center rounded-full border border-[#212121] bg-[#1a1a1a] transition-all ${selectedDayIndex === 0 ? 'opacity-20 cursor-not-allowed' : 'text-[#898989] hover:text-white hover:border-white/40 active:scale-95'}`}
                                            >
                                                <ChevronLeft className="h-6 w-6" />
                                            </button>
                                            <button
                                                onClick={handleNextDay}
                                                disabled={selectedDayIndex === 6}
                                                className={`h-11 w-11 flex items-center justify-center rounded-full border border-[#212121] bg-[#1a1a1a] transition-all ${selectedDayIndex === 6 ? 'opacity-20 cursor-not-allowed' : 'text-[#898989] hover:text-white hover:border-white/40 active:scale-95'}`}
                                            >
                                                <ChevronRight className="h-6 w-6" />
                                            </button>
                                        </div>
                                    </div>

                                    {/* Workout Grid - Centered on Desktop */}
                                    <div className="flex md:justify-center items-start">
                                        <div className="w-full md:max-w-md">
                                            {(() => {
                                                const workout = parsedWorkouts ? parsedWorkouts[selectedDayIndex] : null;
                                                if (!workout) return <div key="empty" className="py-12 text-center text-white/20">No workout data available</div>;

                                                return (
                                                    <CollapsibleSection
                                                        key={selectedDayIndex}
                                                        id={`workout-${selectedDayIndex}`}
                                                        title={workout.isRestDay ? 'Rest Day' : workout.name}
                                                        rightLabel={workout.duration && !workout.duration.toLowerCase().includes('0 min') ? workout.duration : undefined}
                                                        icon="🏋️"
                                                    >
                                                        <div className="space-y-6 pt-2">
                                                            {workout.duration && !workout.duration.toLowerCase().includes('0 min') && (
                                                                <div className="group space-y-2">
                                                                    <div className="flex items-center gap-2 bg-[#1a1a1a] px-3 py-1.5 rounded-lg border border-[#212121]/50 w-fit">
                                                                        <span className="text-sm">⏱️</span>
                                                                        <p className="text-[10px] font-black uppercase tracking-widest text-[#898989]">{workout.duration}</p>
                                                                    </div>
                                                                </div>
                                                            )}
                                                            <div className="space-y-3">
                                                                {workout.exercises.map((exercise: string, i: number) => (
                                                                    <div key={i} className="flex items-center gap-3 group/ex">
                                                                        <div className="h-1.5 w-1.5 rounded-full bg-primary shadow-[0_0_8px_rgba(204,216,83,0.5)] transition-transform group-hover/ex:scale-125" />
                                                                        <span className="text-xs text-[#898989] font-bold group-hover/ex:text-white transition-colors">{exercise}</span>
                                                                    </div>
                                                                ))}
                                                            </div>
                                                        </div>
                                                    </CollapsibleSection>
                                                );
                                            })()}
                                        </div>
                                    </div>
                                </>
                            ) : (
                                <div className="space-y-8">
                                    {/* Personalized Suggestions Card */}
                                    <div className="rounded-2xl border border-[#212121] bg-[#0c0c0c] overflow-hidden">
                                        <div className="flex items-center justify-between p-4 border-b border-[#212121]">
                                            <div className="flex items-center gap-3">
                                                <ChevronDown className="h-4 w-4 text-[#898989]" />
                                                <span className="font-bold text-white text-sm">Personalized Suggestions</span>
                                            </div>
                                        </div>
                                        <div className="p-5 space-y-5">
                                            <div className="flex items-start justify-between">
                                                <div className="space-y-1">
                                                    <p className="text-sm font-bold text-primary">Meal Plan Focus</p>
                                                    <p className="text-xs text-[#898989]">
                                                        {savedPlanData?.calculatedData?.personalizedInsight || data.calculatedData?.personalizedInsight || `Consistency is the key to achieving your "${data.targetWeight || savedPlanData?.calculatedData?.targetWeight || 'goal'}" goal.`}
                                                    </p>
                                                </div>
                                                <div className="flex items-center gap-3">
                                                    <button className="p-2 rounded-lg bg-[#1a1a1a] text-[#898989] hover:text-white transition-colors">
                                                        <ThumbsDown className="h-4 w-4" />
                                                    </button>
                                                    <button className="p-2 rounded-lg bg-[#1a1a1a] text-[#898989] hover:text-white transition-colors">
                                                        <ThumbsUp className="h-4 w-4" />
                                                    </button>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Suggested Products Section */}
                                    <div className="space-y-6">
                                        <div className="flex items-center justify-between">
                                            <h3 className="font-bold text-white text-sm">Suggested products</h3>
                                            {products.length > 5 && (
                                                <button
                                                    onClick={() => setShowAllProducts(!showAllProducts)}
                                                    className="text-[11px] font-bold text-primary hover:underline transition-all"
                                                >
                                                    {showAllProducts ? 'Show less' : 'View all'}
                                                </button>
                                            )}
                                        </div>
                                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
                                            {(showAllProducts ? sortedProducts : sortedProducts.slice(0, 5)).map((product) => {
                                                const imageUrl = product.images.edges[0]?.node.url || null;
                                                const price = product.priceRange.minVariantPrice;
                                                const formattedPrice = new Intl.NumberFormat('en-IN', {
                                                    style: 'currency',
                                                    currency: price.currencyCode,
                                                }).format(parseFloat(price.amount));

                                                return (
                                                    <div
                                                        key={product.id}
                                                        onClick={() => product.onlineStoreUrl && window.open(product.onlineStoreUrl, '_blank')}
                                                        className="group rounded-2xl bg-[#0c0c0c] border border-[#212121] p-4 text-center space-y-3 hover:border-primary transition-all cursor-pointer h-full flex flex-col justify-between"
                                                    >
                                                        <div className="relative aspect-square w-full rounded-xl overflow-hidden bg-white/5 flex items-center justify-center">
                                                            {imageUrl ? (
                                                                <img
                                                                    src={imageUrl}
                                                                    alt={product.title}
                                                                    className="object-cover w-full h-full group-hover:scale-110 transition-transform duration-500"
                                                                />
                                                            ) : (
                                                                <span className="text-4xl opacity-20">🛒</span>
                                                            )}
                                                        </div>
                                                        <div className="space-y-1">
                                                            <p className="text-[10px] text-white font-bold line-clamp-2 min-h-[2.5em]">{product.title}</p>
                                                            <p className="text-[10px] text-primary font-black uppercase">{formattedPrice}</p>
                                                        </div>
                                                    </div>
                                                );
                                            })}
                                            {products.length === 0 && Array.from({ length: 5 }).map((_, i) => (
                                                <div key={i} className="rounded-2xl bg-[#0c0c0c] border border-[#212121] p-4 animate-pulse aspect-[4/5]" />
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            </div>

            {/* Save (Favorite) Modal */}
            {isSaveModalOpen && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
                    <div className="w-full max-w-sm rounded-[32px] border border-[#212121] bg-[#0c0c0c] p-8 shadow-2xl">
                        <h3 className="text-lg font-bold text-white mb-2 text-center">Add To Favorites</h3>
                        {/* <p className="text-xs text-[#898989] mb-6 text-center">Pick a name to find this in your Favorite Plans</p> */}

                        <div className="space-y-4">
                            <div className="space-y-1.5">
                                <label className="text-[10px] font-bold uppercase tracking-widest text-[#454545] ml-1">Pick a Name</label>
                                <Input
                                    value={planName}
                                    onChange={(e) => setPlanName(e.target.value)}
                                    placeholder="e.g. 12 Week Shred"
                                    className="bg-[#111] border-[#212121] text-white h-12 rounded-2xl focus:ring-primary"
                                />
                            </div>

                            <div className="flex gap-3 pt-2">
                                <Button
                                    variant="outline"
                                    onClick={() => setIsSaveModalOpen(false)}
                                    className="flex-1 bg-transparent border-[#212121] text-[#898989] hover:bg-white/5 h-12 rounded-2xl font-bold"
                                >
                                    Cancel
                                </Button>
                                <Button
                                    onClick={async () => {
                                        const user = getCurrentUser();
                                        if (user) {
                                            setIsSaving(true);
                                            try {
                                                const mealPlanRaw = data.mealPlan || localStorage.getItem('generated_meal_plan_raw');
                                                const workoutPlanRaw = data.workoutPlan || localStorage.getItem('generated_workout_plan_raw');

                                                await saveUserPlan(user.uid, planName, {
                                                    goal: data.prompt,
                                                    mealPlan: mealPlanRaw,
                                                    workoutPlan: workoutPlanRaw,
                                                    calculatedData: data.calculatedData,
                                                    planGenerationDate: localStorage.getItem('plan_generation_date')
                                                });
                                                setIsSaveModalOpen(false);
                                                setIsPlanSaved(true);
                                                alert('Plan favorited successfully!');
                                            } catch (e) {
                                                alert('Failed to favorite plan');
                                            } finally {
                                                setIsSaving(false);
                                            }
                                        }
                                    }}
                                    disabled={isSaving}
                                    className="flex-1 bg-primary text-black hover:bg-primary/90 h-12 rounded-2xl font-bold"
                                >
                                    {isSaving ? 'Favoriting...' : 'Save'}
                                </Button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Bottom Nav */}
            <BottomNavNew />
        </div>
    );
}
