import { useState } from 'react';
import { ChevronLeft, ChevronRight, Download } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';
import { Header } from '@/components/Header';

const DAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const DATES = ['02', '03', '04', '05', '06', '07', '08'];

const MEAL_TIMES = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

const WEEKLY_MEALS: Record<string, Record<string, { name: string; quantity: string; calories: number; macro: string }[]>> = {
  MON: {
    Breakfast: [
      { name: 'Oatmeal', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Banana', quantity: '1 pcs', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Almonds', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
    ],
    Lunch: [
      { name: 'Brown rice', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Grilled chicken breast', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Steamed broccoli', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
    ],
    Snacks: [
      { name: 'Apple', quantity: '1 Pcs', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Rice cakes', quantity: '1 pcs', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
    ],
    Dinner: [
      { name: 'Spaghetti', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Marinara sauce', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
      { name: 'Green salad', quantity: '245 g', calories: 955, macro: '22g Prot • 8g fat • 48g carbs' },
    ],
  },
  TUE: {
    Breakfast: [
      { name: 'Eggs', quantity: '3 pcs', calories: 850, macro: '24g Prot • 10g fat • 40g carbs' },
      { name: 'Toast', quantity: '2 slices', calories: 850, macro: '24g Prot • 10g fat • 40g carbs' },
      { name: 'Avocado', quantity: '1/2 fruit', calories: 850, macro: '24g Prot • 10g fat • 40g carbs' },
    ],
    Lunch: [
      { name: 'Grilled fish', quantity: '200 g', calories: 920, macro: '26g Prot • 9g fat • 45g carbs' },
      { name: 'White rice', quantity: '250 g', calories: 920, macro: '26g Prot • 9g fat • 45g carbs' },
      { name: 'Vegetables mix', quantity: '150 g', calories: 920, macro: '26g Prot • 9g fat • 45g carbs' },
    ],
    Snacks: [
      { name: 'Protein shake', quantity: '1 shake', calories: 800, macro: '25g Prot • 8g fat • 42g carbs' },
    ],
    Dinner: [
      { name: 'Beef steak', quantity: '200 g', calories: 980, macro: '28g Prot • 11g fat • 50g carbs' },
      { name: 'Sweet potato', quantity: '200 g', calories: 980, macro: '28g Prot • 11g fat • 50g carbs' },
    ],
  },
  WED: {
    Breakfast: [
      { name: 'Greek yogurt', quantity: '200 g', calories: 900, macro: '20g Prot • 8g fat • 46g carbs' },
      { name: 'Granola', quantity: '50 g', calories: 900, macro: '20g Prot • 8g fat • 46g carbs' },
      { name: 'Berries', quantity: '100 g', calories: 900, macro: '20g Prot • 8g fat • 46g carbs' },
    ],
    Lunch: [
      { name: 'Chicken breast', quantity: '220 g', calories: 1000, macro: '28g Prot • 10g fat • 52g carbs' },
      { name: 'Brown rice', quantity: '200 g', calories: 1000, macro: '28g Prot • 10g fat • 52g carbs' },
      { name: 'Broccoli', quantity: '150 g', calories: 1000, macro: '28g Prot • 10g fat • 52g carbs' },
    ],
    Snacks: [
      { name: 'Almonds', quantity: '28 g', calories: 850, macro: '22g Prot • 9g fat • 44g carbs' },
    ],
    Dinner: [
      { name: 'Salmon', quantity: '180 g', calories: 950, macro: '26g Prot • 10g fat • 48g carbs' },
      { name: 'Asparagus', quantity: '150 g', calories: 950, macro: '26g Prot • 10g fat • 48g carbs' },
    ],
  },
  THU: {
    Breakfast: [
      { name: 'Pancakes', quantity: '3 pcs', calories: 920, macro: '24g Prot • 8g fat • 47g carbs' },
      { name: 'Syrup', quantity: '30 ml', calories: 920, macro: '24g Prot • 8g fat • 47g carbs' },
      { name: 'Berries', quantity: '100 g', calories: 920, macro: '24g Prot • 8g fat • 47g carbs' },
    ],
    Lunch: [
      { name: 'Turkey breast', quantity: '200 g', calories: 980, macro: '28g Prot • 9g fat • 49g carbs' },
      { name: 'Quinoa', quantity: '150 g', calories: 980, macro: '28g Prot • 9g fat • 49g carbs' },
      { name: 'Mixed veggies', quantity: '150 g', calories: 980, macro: '28g Prot • 9g fat • 49g carbs' },
    ],
    Snacks: [
      { name: 'Protein bar', quantity: '1 bar', calories: 870, macro: '23g Prot • 8g fat • 45g carbs' },
    ],
    Dinner: [
      { name: 'Pork loin', quantity: '200 g', calories: 940, macro: '27g Prot • 10g fat • 48g carbs' },
      { name: 'Roasted veggies', quantity: '200 g', calories: 940, macro: '27g Prot • 10g fat • 48g carbs' },
    ],
  },
  FRI: {
    Breakfast: [
      { name: 'Scrambled eggs', quantity: '3 pcs', calories: 890, macro: '25g Prot • 9g fat • 45g carbs' },
      { name: 'Whole grain toast', quantity: '2 slices', calories: 890, macro: '25g Prot • 9g fat • 45g carbs' },
      { name: 'Spinach', quantity: '50 g', calories: 890, macro: '25g Prot • 9g fat • 45g carbs' },
    ],
    Lunch: [
      { name: 'Tuna', quantity: '150 g', calories: 1010, macro: '29g Prot • 11g fat • 51g carbs' },
      { name: 'Brown rice', quantity: '200 g', calories: 1010, macro: '29g Prot • 11g fat • 51g carbs' },
      { name: 'Cucumber', quantity: '100 g', calories: 1010, macro: '29g Prot • 11g fat • 51g carbs' },
    ],
    Snacks: [
      { name: 'Energy balls', quantity: '3 pcs', calories: 880, macro: '22g Prot • 8g fat • 46g carbs' },
    ],
    Dinner: [
      { name: 'Grilled shrimp', quantity: '200 g', calories: 960, macro: '28g Prot • 9g fat • 50g carbs' },
      { name: 'Sweet potato', quantity: '150 g', calories: 960, macro: '28g Prot • 9g fat • 50g carbs' },
    ],
  },
  SAT: {
    Breakfast: [
      { name: 'French toast', quantity: '2 slices', calories: 950, macro: '26g Prot • 10g fat • 48g carbs' },
      { name: 'Berries', quantity: '100 g', calories: 950, macro: '26g Prot • 10g fat • 48g carbs' },
      { name: 'Honey', quantity: '20 ml', calories: 950, macro: '26g Prot • 10g fat • 48g carbs' },
    ],
    Lunch: [
      { name: 'Burger', quantity: '200 g', calories: 1050, macro: '30g Prot • 12g fat • 53g carbs' },
      { name: 'Sweet potato fries', quantity: '150 g', calories: 1050, macro: '30g Prot • 12g fat • 53g carbs' },
    ],
    Snacks: [
      { name: 'Protein shake', quantity: '1 shake', calories: 900, macro: '25g Prot • 9g fat • 46g carbs' },
    ],
    Dinner: [
      { name: 'Steak', quantity: '250 g', calories: 1000, macro: '31g Prot • 12g fat • 52g carbs' },
      { name: 'Baked potato', quantity: '200 g', calories: 1000, macro: '31g Prot • 12g fat • 52g carbs' },
    ],
  },
  SUN: {
    Breakfast: [
      { name: 'Waffle', quantity: '1 pcs', calories: 930, macro: '24g Prot • 9g fat • 48g carbs' },
      { name: 'Strawberries', quantity: '100 g', calories: 930, macro: '24g Prot • 9g fat • 48g carbs' },
    ],
    Lunch: [
      { name: 'Roasted chicken', quantity: '250 g', calories: 1020, macro: '30g Prot • 11g fat • 51g carbs' },
      { name: 'Rice pilaf', quantity: '200 g', calories: 1020, macro: '30g Prot • 11g fat • 51g carbs' },
      { name: 'Vegetables', quantity: '150 g', calories: 1020, macro: '30g Prot • 11g fat • 51g carbs' },
    ],
    Snacks: [
      { name: 'Smoothie', quantity: '1 cup', calories: 880, macro: '22g Prot • 8g fat • 46g carbs' },
    ],
    Dinner: [
      { name: 'Pasta carbonara', quantity: '250 g', calories: 980, macro: '27g Prot • 10g fat • 50g carbs' },
      { name: 'Side salad', quantity: '100 g', calories: 980, macro: '27g Prot • 10g fat • 50g carbs' },
    ],
  },
};

const MEAL_ICONS: Record<string, string> = {
  Breakfast: '🌅',
  Lunch: '🍽️',
  Snacks: '🥜',
  Dinner: '🌙',
};

const WORKOUTS: Record<string, { name: string; duration: string; exercises: string[] }> = {
  MON: { name: 'Upper Body Strength', duration: '60 mins', exercises: ['Bench Press', 'Pull-ups', 'Shoulder Press', 'Bicep Curls'] },
  TUE: { name: 'Cardio & HIIT', duration: '45 mins', exercises: ['Running', 'Jump Rope', 'Mountain Climbers', 'Burpees'] },
  WED: { name: 'Lower Body', duration: '50 mins', exercises: ['Squats', 'Deadlifts', 'Leg Press', 'Calf Raises'] },
  THU: { name: 'Rest & Recovery', duration: '30 mins', exercises: ['Yoga', 'Stretching', 'Foam Rolling'] },
  FRI: { name: 'Full Body', duration: '55 mins', exercises: ['Compound Lifts', 'Core Work', 'Cardio Finisher'] },
  SAT: { name: 'HIIT Training', duration: '30 mins', exercises: ['Jump Squats', 'Push-ups', 'High Knees'] },
  SUN: { name: 'Active Recovery', duration: '20 mins', exercises: ['Light Walking', 'Stretching', 'Meditation'] },
};

const SUGGESTED_PRODUCTS = [
  { name: 'Gym Floor Kettlebells', price: '₹ 2,499.00', image: '🏋️' },
  { name: 'Resistance Bands', price: '₹ 2,499.00', image: '💪' },
  { name: 'Yoga Mat & Strap', price: '₹ 999.00', image: '🧘' },
  { name: 'Dumbbell Set', price: '₹ 5,999.00', image: '⏱️' },
  { name: 'Yoga Straps', price: '₹ 1,099.00', image: '🎯' },
];

export default function Schedule() {
  const [currentWeek, setCurrentWeek] = useState(0);
  const [activeTab, setActiveTab] = useState<'meals' | 'workout' | 'suggestions'>('meals');

  const handlePrevWeek = () => setCurrentWeek((prev) => Math.max(0, prev - 1));
  const handleNextWeek = () => setCurrentWeek((prev) => prev + 1);

  const totalCalories = Object.values(WEEKLY_MEALS.MON).flat().reduce((sum, item) => sum + item.calories, 0) / 1000;

  return (
    <div className="relative min-h-screen w-full bg-[#3D3D3D]">
      {/* Glow Effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[200%] h-[100%] opacity-90 blur-[250px] bg-primary/20" />
      </div>

      {/* Header */}
      <Header />

      {/* Content */}
      <div className="relative z-10 px-4 md:px-8 py-6 md:py-8 pb-24 md:pb-0">
        <div className="mx-auto max-w-7xl space-y-4 md:space-y-6">
          {/* Title */}
          <div className="flex items-center gap-3">
            <span className="text-2xl md:text-3xl">📅</span>
            <h1 className="text-2xl md:text-3xl font-bold text-white">Weekly Schedule</h1>
          </div>

          {/* Date Selector */}
          <div className="flex flex-col md:flex-row items-center justify-center gap-3 md:gap-6 rounded-2xl bg-[#212121] border border-[#454545] px-3 md:px-6 py-4 md:py-6 overflow-x-auto">
            <button
              onClick={handlePrevWeek}
              className="flex h-9 w-9 md:h-10 md:w-10 items-center justify-center rounded-full bg-[#2A2A2A] text-white transition-all hover:bg-primary hover:text-black flex-shrink-0"
            >
              <ChevronLeft className="h-5 w-5 md:h-6 md:w-6" />
            </button>

            <div className="flex items-center gap-4 md:gap-8">
              {DAYS.map((day, idx) => (
                <div key={day} className="flex flex-col items-center gap-1 md:gap-2 flex-shrink-0">
                  <p className="text-xs text-[#AFAFAF]">{DATES[idx]}</p>
                  <div className={`rounded-full px-2 md:px-3 py-1 text-xs font-medium transition-colors ${
                    idx === 2
                      ? 'bg-primary text-black'
                      : 'text-[#AFAFAF]'
                  }`}>
                    {day}
                  </div>
                </div>
              ))}
            </div>

            <button
              onClick={handleNextWeek}
              className="flex h-9 w-9 md:h-10 md:w-10 items-center justify-center rounded-full bg-[#2A2A2A] text-white transition-all hover:bg-primary hover:text-black flex-shrink-0"
            >
              <ChevronRight className="h-5 w-5 md:h-6 md:w-6" />
            </button>
          </div>

          {/* Plan Info */}
          <div className="rounded-2xl bg-[#212121] border border-[#454545] px-4 md:px-6 py-3 md:py-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
            <div className="min-w-0">
              <h2 className="font-semibold text-white text-sm md:text-base">General LW (7D) Plan #1</h2>
              <div className="mt-2 flex flex-col md:flex-row md:items-center gap-2 md:gap-4">
                <span className="text-xs text-[#AFAFAF]">
                  📅 Duration: 7 Days
                </span>
                <span className="text-xs text-primary font-semibold">
                  🔥 2838 kcal
                </span>
              </div>
            </div>
            <button className="flex items-center gap-2 rounded-lg border border-primary px-3 md:px-4 py-2 text-xs md:text-sm font-medium text-primary transition-all hover:bg-primary/10 whitespace-nowrap">
              <Download className="h-4 w-4 flex-shrink-0" />
              Download
            </button>
          </div>

          {/* Tabs */}
          <div className="flex gap-2 md:gap-6 border-b border-[#454545] overflow-x-auto">
            <button 
              onClick={() => setActiveTab('meals')}
              className={`border-b-2 px-2 md:px-3 py-2 md:py-3 text-xs md:text-sm font-medium transition-all whitespace-nowrap ${
                activeTab === 'meals'
                  ? 'border-primary text-primary'
                  : 'border-transparent text-[#AFAFAF] hover:text-white'
              }`}
            >
              🍽️ Meals
            </button>
            <button 
              onClick={() => setActiveTab('workout')}
              className={`border-b-2 px-2 md:px-3 py-2 md:py-3 text-xs md:text-sm font-medium transition-all whitespace-nowrap ${
                activeTab === 'workout'
                  ? 'border-primary text-primary'
                  : 'border-transparent text-[#AFAFAF] hover:text-white'
              }`}
            >
              💪 Workout
            </button>
            <button 
              onClick={() => setActiveTab('suggestions')}
              className={`border-b-2 px-2 md:px-3 py-2 md:py-3 text-xs md:text-sm font-medium transition-all whitespace-nowrap ${
                activeTab === 'suggestions'
                  ? 'border-primary text-primary'
                  : 'border-transparent text-[#AFAFAF] hover:text-white'
              }`}
            >
              📌 Suggestions
            </button>
          </div>

          {/* Content Tabs */}
          {activeTab === 'meals' ? (
            <>
              {/* Goal */}
              <div className="text-center">
                <p className="text-xs md:text-sm text-[#AFAFAF]">Goal</p>
                <p className="text-xl md:text-2xl font-bold text-primary">700 kcal</p>
              </div>

              {/* Meals Grid */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-6">
                {MEAL_TIMES.map((mealTime) => (
                  <div key={mealTime} className="space-y-2 md:space-y-3">
                    {/* Meal Header */}
                    <div className="flex items-center gap-2 pb-2 md:pb-3 border-b border-[#454545]">
                      <span className="text-lg md:text-xl">{MEAL_ICONS[mealTime]}</span>
                      <h3 className="font-semibold text-white text-sm md:text-base">{mealTime}</h3>
                    </div>

                    {/* Meal Items */}
                    <div className="space-y-2 md:space-y-4">
                      {WEEKLY_MEALS.MON[mealTime]?.map((item, idx) => (
                        <div key={idx} className="rounded-lg bg-[#212121] border border-[#454545] p-2 md:p-3 space-y-1 md:space-y-2">
                          <div>
                            <p className="font-medium text-white text-xs md:text-sm">{item.name}</p>
                            <p className="text-xs text-[#AFAFAF]">{item.quantity}</p>
                          </div>
                          <div className="space-y-0.5">
                            <p className="text-xs text-primary font-medium">{item.calories} kcal</p>
                            <p className="text-xs text-[#666]">{item.macro}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : activeTab === 'workout' ? (
            <>
              {/* Goal */}
              <div className="text-center">
                <p className="text-xs md:text-sm text-[#AFAFAF]">Goal</p>
                <p className="text-xl md:text-2xl font-bold text-primary">450 kcal</p>
              </div>

              {/* Workout Grid */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-6">
                {DAYS.map((day, idx) => {
                  const workout = WORKOUTS[day];
                  return (
                    <div key={day} className="space-y-2 md:space-y-3">
                      {/* Day Header */}
                      <div className="pb-2 md:pb-3 border-b border-[#454545]">
                        <h3 className="font-semibold text-white text-xs md:text-sm">{day}</h3>
                      </div>

                      {/* Workout Card */}
                      <div className="rounded-lg bg-[#212121] border border-[#454545] p-2 md:p-3 space-y-2 md:space-y-3">
                        <div>
                          <p className="font-medium text-white text-xs md:text-sm">{workout.name}</p>
                          <p className="text-xs text-[#AFAFAF] mt-1">{workout.duration}</p>
                        </div>
                        <div className="space-y-1 md:space-y-2">
                          {workout.exercises.map((exercise, i) => (
                            <p key={i} className="text-xs text-[#AFAFAF] flex items-center gap-2">
                              <span className="h-1 w-1 rounded-full bg-primary flex-shrink-0" />
                              <span className="truncate">{exercise}</span>
                            </p>
                          ))}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          ) : (
            <>
              {/* Personalized Suggestions */}
              <div className="space-y-3 md:space-y-4">
                <div>
                  <h3 className="font-semibold text-white mb-2 md:mb-3 text-sm md:text-base">✨ Personalized Suggestions</h3>
                  <div className="rounded-lg bg-[#212121] border border-[#454545] p-3 md:p-4 space-y-2">
                    <p className="text-xs md:text-sm text-primary font-medium">Recommended for your goal</p>
                    <p className="text-xs text-[#AFAFAF]">
                      Consuming 1 to the 1.8 g/body weight "Only opt."
                    </p>
                  </div>
                </div>

                {/* Suggested Products */}
                <div>
                  <div className="flex items-center justify-between mb-2 md:mb-4">
                    <h3 className="font-semibold text-white text-sm md:text-base">Suggested products</h3>
                    <button className="text-xs text-primary hover:text-primary/80 transition-all">View all</button>
                  </div>
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-2 md:gap-3 lg:gap-4">
                    {SUGGESTED_PRODUCTS.map((product, idx) => (
                      <div
                        key={idx}
                        className="rounded-lg bg-[#212121] border border-[#454545] p-2 md:p-4 text-center space-y-2 md:space-y-3 hover:border-primary/50 transition-all cursor-pointer"
                      >
                        <div className="text-2xl md:text-4xl">{product.image}</div>
                        <p className="text-xs text-white font-medium line-clamp-2">{product.name}</p>
                        <p className="text-xs text-primary font-semibold">{product.price}</p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Bottom Nav */}
      <BottomNav />
    </div>
  );
}
