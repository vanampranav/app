import { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Flame } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';

export default function Calories() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [calorieData, setCalorieData] = useState({
    dailyCalories: 0,
    proteinGrams: 0,
    carbsGrams: 0,
    fatGrams: 0,
  });

  useEffect(() => {
    // Simulate calorie calculation
    const calculateCalories = () => {
      // Get form data from localStorage (you can pass it via route state instead)
      const age = 25; // Default values for demo
      const height = 170;
      const weight = 75;
      const goalWeight = 70;
      const activityLevel = 'moderate';

      // Harris-Benedict Formula for BMR
      const bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);

      // Activity multipliers
      const activityMultipliers: Record<string, number> = {
        sedentary: 1.2,
        light: 1.375,
        moderate: 1.55,
        active: 1.725,
        'very-active': 1.9,
      };

      const multiplier = activityMultipliers[activityLevel] || 1.55;
      const tdee = Math.round(bmr * multiplier);

      // For weight loss, reduce by 500 calories (0.5kg per week)
      const dailyCalories = Math.round(tdee - 500);

      // Macro breakdown: 30% protein, 40% carbs, 30% fat
      const proteinCalories = dailyCalories * 0.3;
      const carbCalories = dailyCalories * 0.4;
      const fatCalories = dailyCalories * 0.3;

      setCalorieData({
        dailyCalories,
        proteinGrams: Math.round(proteinCalories / 4),
        carbsGrams: Math.round(carbCalories / 4),
        fatGrams: Math.round(fatCalories / 9),
      });

      setLoading(false);
    };

    // Simulate API call delay
    const timer = setTimeout(calculateCalories, 1500);
    return () => clearTimeout(timer);
  }, []);

  const handleContinue = () => {
    navigate('/schedule');
  };

  return (
    <div className="relative min-h-screen w-full bg-[#3D3D3D] md:h-[1495px] md:w-[1920px] md:mx-auto">
      {/* Glow Effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[200%] h-[100%] opacity-90 blur-[250px] bg-primary/20" />
      </div>

      {/* Header */}
      <div className="relative z-10 border-b border-[#454545] bg-[#212121] px-4 md:px-32 py-4 md:py-7">
        <div className="flex items-center gap-4 md:gap-28">
          <Link
            to="/ai-coach/preferences"
            className="flex h-9 w-9 items-center justify-center rounded-full bg-primary flex-shrink-0"
          >
            <ArrowLeft className="h-6 w-6 text-black" />
          </Link>
          <div className="flex items-center gap-3 min-w-0">
            <svg className="h-5 w-5 md:h-6 md:w-6 flex-shrink-0" viewBox="0 0 24 24" fill="none">
              <path d="M19.5 13.5C19.5019 13.8058 19.409 14.1047 19.2341 14.3555C19.0591 14.6063 18.8108 14.7968 18.5232 14.9006L13.6875 16.6875L11.9063 21.5269C11.8008 21.8134 11.6099 22.0608 11.3595 22.2355C11.109 22.4101 10.811 22.5038 10.5057 22.5038C10.2003 22.5038 9.90227 22.4101 9.65181 22.2355C9.40136 22.0608 9.21051 21.8134 9.10503 21.5269L7.31253 16.6875L2.47315 14.9062C2.18659 14.8008 1.93927 14.6099 1.76458 14.3595C1.58988 14.109 1.49622 13.811 1.49622 13.5056C1.49622 13.2003 1.58988 12.9022 1.76458 12.6518C1.93927 12.4013 2.18659 12.2105 2.47315 12.105L7.31253 10.3125L9.09378 5.47313C9.19926 5.18656 9.39011 4.93924 9.64056 4.76455C9.89102 4.58985 10.189 4.49619 10.4944 4.49619C10.7998 4.49619 11.0978 4.58985 11.3482 4.76455C11.5987 4.93924 11.7895 5.18656 11.895 5.47313L13.6875 10.3125L18.5269 12.0938C18.8147 12.1986 19.0629 12.3901 19.2372 12.642C19.4116 12.8939 19.5034 13.1937 19.5 13.5Z" fill="#E1E1E1" />
              <path d="M14.25 4.5H15.75V6C15.75 6.19891 15.829 6.38968 15.9697 6.53033C16.1103 6.67098 16.3011 6.75 16.5 6.75C16.6989 6.75 16.8897 6.67098 17.0304 6.53033C17.171 6.38968 17.25 6.19891 17.25 6V4.5H18.75C18.9489 4.5 19.1397 4.42098 19.2804 4.28033C19.421 4.13968 19.5 3.94891 19.5 3.75C19.5 3.55109 19.421 3.36032 19.2804 3.21967C19.1397 3.07902 18.9489 3 18.75 3H17.25V1.5C17.25 1.30109 17.171 1.11032 17.0304 0.96967C16.8897 0.829018 16.6989 0.75 16.5 0.75C16.3011 0.75 16.1103 0.829018 15.9697 0.96967C15.829 1.11032 15.75 1.30109 15.75 1.5V3H14.25C14.0511 3 13.8603 3.07902 13.7197 3.21967C13.579 3.36032 13.5 3.55109 13.5 3.75C13.5 3.94891 13.579 4.13968 13.7197 4.28033C13.8603 4.42098 14.0511 4.5 14.25 4.5Z" fill="#E1E1E1" />
            </svg>
            <h2 className="text-lg md:text-2xl font-bold text-[#E1E1E1] truncate">AI Coach</h2>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="relative z-10 flex min-h-[calc(100vh-154px)] items-center justify-center px-4 md:px-0 pb-24 md:pb-32">
        <div className="w-full max-w-[600px] space-y-6 md:space-y-10">
          {/* Progress */}
          <div className="flex flex-col items-end gap-2">
            <p className="text-xs md:text-sm text-[#898989]">Step 3 of 3</p>
            <div className="h-2 w-full rounded-full bg-[#2A2A2A]">
              <div className="h-full w-full rounded-full bg-primary" />
            </div>
          </div>

          {/* Title */}
          <div className="space-y-2 md:space-y-3">
            <div className="flex items-center gap-2">
              <h1 className="text-2xl md:text-3xl font-bold text-white">Your Calorie Plan</h1>
              <Flame className="h-6 w-6 md:h-8 md:w-8 text-primary flex-shrink-0" />
            </div>
            <p className="text-xs md:text-sm text-[#AFAFAF]">Based on your profile and goals</p>
          </div>

          {/* Calorie Cards */}
          {loading ? (
            <div className="space-y-3 md:space-y-4">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className="h-16 md:h-20 rounded-2xl bg-gradient-to-r from-[#2A2A2A] to-[#1A1A1A] animate-pulse"
                />
              ))}
            </div>
          ) : (
            <div className="space-y-3 md:space-y-4">
              {/* Daily Calories */}
              <div className="rounded-2xl border border-[#454545] bg-gradient-to-br from-[#1a1a1a] to-[#0f0f0f] p-4 md:p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-xs md:text-sm text-[#AFAFAF]">Daily Calorie Goal</p>
                    <p className="mt-2 text-3xl md:text-4xl font-bold text-primary">
                      {calorieData.dailyCalories}
                    </p>
                  </div>
                  <Flame className="h-10 w-10 md:h-12 md:w-12 text-primary opacity-20 flex-shrink-0" />
                </div>
              </div>

              {/* Macros Grid */}
              <div className="grid grid-cols-3 gap-2 md:gap-3">
                {/* Protein */}
                <div className="rounded-xl border border-[#454545] bg-gradient-to-br from-[#1a1a1a] to-[#0f0f0f] p-3 md:p-4">
                  <p className="text-xs text-[#AFAFAF]">Protein</p>
                  <p className="mt-2 text-xl md:text-2xl font-bold text-[#FF6B6B]">
                    {calorieData.proteinGrams}g
                  </p>
                  <p className="mt-1 text-xs text-[#666]">~30%</p>
                </div>

                {/* Carbs */}
                <div className="rounded-xl border border-[#454545] bg-gradient-to-br from-[#1a1a1a] to-[#0f0f0f] p-3 md:p-4">
                  <p className="text-xs text-[#AFAFAF]">Carbs</p>
                  <p className="mt-2 text-xl md:text-2xl font-bold text-[#4ECDC4]">
                    {calorieData.carbsGrams}g
                  </p>
                  <p className="mt-1 text-xs text-[#666]">~40%</p>
                </div>

                {/* Fat */}
                <div className="rounded-xl border border-[#454545] bg-gradient-to-br from-[#1a1a1a] to-[#0f0f0f] p-3 md:p-4">
                  <p className="text-xs text-[#AFAFAF]">Fat</p>
                  <p className="mt-2 text-xl md:text-2xl font-bold text-[#FFD93D]">
                    {calorieData.fatGrams}g
                  </p>
                  <p className="mt-1 text-xs text-[#666]">~30%</p>
                </div>
              </div>

              {/* Info */}
              <div className="rounded-xl bg-[#1A2A2A] p-3 md:p-4">
                <p className="text-xs text-[#AFAFAF]">
                  💡 This plan is designed to help you lose ~0.5kg per week. Adjust as needed based on your progress.
                </p>
              </div>
            </div>
          )}

          {/* Continue Button */}
          <button
            onClick={handleContinue}
            disabled={loading}
            className="w-full rounded-full bg-primary py-3 md:py-4 font-semibold text-black text-sm md:text-base transition-opacity hover:opacity-90 disabled:opacity-50 min-h-[44px]"
          >
            {loading ? 'Calculating...' : 'View Weekly Schedule'}
          </button>
        </div>
      </div>

      {/* Bottom Nav */}
      <BottomNav />
    </div>
  );
}
