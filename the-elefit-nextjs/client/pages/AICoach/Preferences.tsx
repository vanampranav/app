import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';

type HelpType = 'meal' | 'workout' | 'both';
type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active';

export default function Preferences() {
  const navigate = useNavigate();
  const [helpType, setHelpType] = useState<HelpType>('both');
  const [activityLevel, setActivityLevel] = useState<ActivityLevel>('moderate');
  const [workoutDays, setWorkoutDays] = useState(4);
  const [dietary, setDietary] = useState('');
  const [dietaryTags, setDietaryTags] = useState<string[]>([]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    navigate('/ai-coach/calories');
  };

  const activityLevels = [
    { id: 'sedentary', label: 'Sedentary', icon: '🪑', desc: 'Little to no exercise' },
    { id: 'light', label: 'Light', icon: '🚶', desc: 'Exercise 1-2 days/week' },
    { id: 'moderate', label: 'Moderate', icon: '🏃', desc: 'Exercise 3-5 days/week' },
    { id: 'active', label: 'Active', icon: '💪', desc: 'Exercise 6-7 days/week' },
    { id: 'very-active', label: 'Very Active', icon: '🔥', desc: 'Intense daily exercise' },
  ];

  const dietTags = ['Veg / Non-veg', 'Vegan', 'No dairy', 'No eggs'];

  return (
    <div className="relative min-h-screen w-full bg-[#3D3D3D] md:h-[1495px] md:w-[1920px] md:mx-auto">
      {/* Glow Effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[200%] h-[100%] opacity-90 blur-[250px] bg-primary/20" />
      </div>

      {/* Header */}
      <div className="relative z-10 border-b border-[#454545] bg-[#212121] px-4 md:px-32 py-4 md:py-7">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div className="flex items-center gap-4 md:gap-28">
            <Link to="/ai-coach/details" className="flex h-9 w-9 items-center justify-center rounded-full bg-primary flex-shrink-0">
              <ArrowLeft className="h-6 w-6 text-black" />
            </Link>
            <div className="flex items-center gap-3 min-w-0">
              <svg className="h-5 w-5 md:h-6 md:w-6 flex-shrink-0" viewBox="0 0 24 24" fill="none">
                <path d="M19.5 13.5C19.5019 13.8058 19.409 14.1047 19.2341 14.3555C19.0591 14.6063 18.8108 14.7968 18.5232 14.9006L13.6875 16.6875L11.9063 21.5269C11.8008 21.8134 11.6099 22.0608 11.3595 22.2355C11.109 22.4101 10.811 22.5038 10.5057 22.5038C10.2003 22.5038 9.90227 22.4101 9.65181 22.2355C9.40136 22.0608 9.21051 21.8134 9.10503 21.5269L7.31253 16.6875L2.47315 14.9062C2.18659 14.8008 1.93927 14.6099 1.76458 14.3595C1.58988 14.109 1.49622 13.811 1.49622 13.5056C1.49622 13.2003 1.58988 12.9022 1.76458 12.6518C1.93927 12.4013 2.18659 12.2105 2.47315 12.105L7.31253 10.3125L9.09378 5.47313C9.19926 5.18656 9.39011 4.93924 9.64056 4.76455C9.89102 4.58985 10.189 4.49619 10.4944 4.49619C10.7998 4.49619 11.0978 4.58985 11.3482 4.76455C11.5987 4.93924 11.7895 5.18656 11.895 5.47313L13.6875 10.3125L18.5269 12.0938C18.8147 12.1986 19.0629 12.3901 19.2372 12.642C19.4116 12.8939 19.5034 13.1937 19.5 13.5Z" fill="#E1E1E1"/>
                <path d="M14.25 4.5H15.75V6C15.75 6.19891 15.829 6.38968 15.9697 6.53033C16.1103 6.67098 16.3011 6.75 16.5 6.75C16.6989 6.75 16.8897 6.67098 17.0304 6.53033C17.171 6.38968 17.25 6.19891 17.25 6V4.5H18.75C18.9489 4.5 19.1397 4.42098 19.2804 4.28033C19.421 4.13968 19.5 3.94891 19.5 3.75C19.5 3.55109 19.421 3.36032 19.2804 3.21967C19.1397 3.07902 18.9489 3 18.75 3H17.25V1.5C17.25 1.30109 17.171 1.11032 17.0304 0.96967C16.8897 0.829018 16.6989 0.75 16.5 0.75C16.3011 0.75 16.1103 0.829018 15.9697 0.96967C15.829 1.11032 15.75 1.30109 15.75 1.5V3H14.25C14.0511 3 13.8603 3.07902 13.7197 3.21967C13.579 3.36032 13.5 3.55109 13.5 3.75C13.5 3.94891 13.579 4.13968 13.7197 4.28033C13.8603 4.42098 14.0511 4.5 14.25 4.5Z" fill="#E1E1E1"/>
              </svg>
              <h2 className="text-lg md:text-2xl font-bold text-[#E1E1E1] truncate">AI Coach</h2>
            </div>
          </div>
          <div className="flex flex-col items-end gap-2">
            <p className="text-xs md:text-sm text-[#898989]">Step 2 of 3</p>
            <div className="h-2 w-full md:w-[402px] rounded-full bg-[#2A2A2A]">
              <div className="h-full w-2/3 rounded-full bg-primary" />
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="relative z-10 px-4 md:px-0 pb-24 md:pb-32 pt-8 md:pt-12">
        <div className="mx-auto w-full max-w-[528px]">
          <form onSubmit={handleSubmit} className="space-y-8 md:space-y-16">
            {/* Help Type */}
            <div className="space-y-3 md:space-y-4">
              <div className="flex items-center gap-1">
                <h2 className="text-lg md:text-xl font-bold text-white">What would you like help with?</h2>
              </div>
              <div className="flex gap-2 md:gap-3">
                {[
                  { id: 'meal', icon: '🍽️', label: 'Meal' },
                  { id: 'workout', icon: '🏋️', label: 'Workout' },
                  { id: 'both', icon: '🔥', label: 'Both', badge: 'Best' },
                ].map((option) => (
                  <button
                    key={option.id}
                    type="button"
                    onClick={() => setHelpType(option.id as HelpType)}
                    className={`relative flex flex-1 flex-col items-center gap-1 md:gap-2 rounded-2xl border p-3 md:p-6 transition-colors min-h-[100px] md:min-h-auto ${
                      helpType === option.id
                        ? 'border-primary bg-[#212121]'
                        : 'border-[#454545] bg-[#212121] hover:border-[#666]'
                    }`}
                  >
                    {option.badge && (
                      <span className="absolute -top-2 right-2 rounded-full bg-primary px-2 py-0.5 text-xs font-medium text-black">
                        {option.badge}
                      </span>
                    )}
                    <span className="text-2xl md:text-4xl">{option.icon}</span>
                    <span className="text-xs md:text-sm font-semibold text-white text-center">{option.label}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Activity Level */}
            <div className="space-y-3 md:space-y-4">
              <h2 className="text-sm md:text-base font-medium text-white">Activity Level</h2>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-2 md:gap-3">
                {activityLevels.map((level) => (
                  <button
                    key={level.id}
                    type="button"
                    onClick={() => setActivityLevel(level.id as ActivityLevel)}
                    className={`flex flex-col items-center gap-1 rounded-2xl border p-2 md:p-4 transition-colors min-h-[110px] md:min-h-auto ${
                      activityLevel === level.id
                        ? 'border-primary bg-[#212121]'
                        : 'border-[#454545] bg-[#212121] hover:border-[#666]'
                    }`}
                  >
                    <span className="text-xl md:text-3xl">{level.icon}</span>
                    <span className="text-xs md:text-sm font-semibold text-white text-center">{level.label}</span>
                    <span className="text-[10px] md:text-xs text-[#898989] text-center leading-tight">{level.desc}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Workout Days */}
            <div className="space-y-3 md:space-y-4">
              <div>
                <h2 className="text-sm md:text-base font-medium text-white">Workout days per week</h2>
                <p className="text-xs md:text-sm text-primary">{workoutDays} days - balanced & sustainable</p>
              </div>
              <input
                type="range"
                min="1"
                max="7"
                value={workoutDays}
                onChange={(e) => setWorkoutDays(Number(e.target.value))}
                className="w-full accent-primary"
              />
              <div className="flex justify-between text-xs md:text-sm text-[#999]">
                <span>1 Day</span>
                <span>7 Day</span>
              </div>
            </div>

            {/* Dietary Preferences */}
            <div className="space-y-3 md:space-y-4">
              <div>
                <label className="mb-2 block text-sm md:text-base font-medium text-white">Dietary preferences</label>
                <input
                  type="text"
                  value={dietary}
                  onChange={(e) => setDietary(e.target.value)}
                  placeholder="Eg., Vegetarian, no dairy"
                  className="w-full rounded-2xl border border-[#454545] bg-[#212121] px-4 md:px-6 py-3 md:py-4 text-sm md:text-base text-white placeholder:text-[#666] focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary min-h-[44px]"
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
                    className={`rounded-lg px-3 md:px-4 py-2 text-xs md:text-sm transition-colors min-h-[44px] flex items-center ${
                      dietaryTags.includes(tag)
                        ? 'bg-primary text-black'
                        : 'bg-[#2A2A2A] text-white hover:bg-[#333]'
                    }`}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>

            <button
              type="submit"
              className="w-full rounded-full bg-primary py-3 md:py-4 font-bold text-black text-sm md:text-base transition-colors hover:bg-primary/90 min-h-[44px]"
            >
              Save profile & proceed
            </button>
          </form>
        </div>
      </div>

      <BottomNav />
    </div>
  );
}
