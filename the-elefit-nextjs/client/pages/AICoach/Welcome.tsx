import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Dumbbell, Sparkles } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';
import { GoalModal } from '@/components/GoalModal';
import { ContinueJourneyModal } from '@/components/ContinueJourneyModal';
import BottomNavNew from '@/components/BottomNavNew';

export default function Welcome() {
  const [showGoalModal, setShowGoalModal] = useState(false);
  const [showContinueModal, setShowContinueModal] = useState(false);
  const navigate = useNavigate();

  const handleGoalSubmit = (goal: string) => {
    setShowGoalModal(false);
    navigate('/ai-coach/details');
  };

  const handleContinuePlan = () => {
    setShowContinueModal(false);
    navigate('/schedule');
  };

  const handleChangeGoal = () => {
    setShowContinueModal(false);
    setShowGoalModal(true);
  };

  return (
    <div
      className="relative min-h-screen w-full md:h-[1495px] md:w-[1920px] md:mx-auto"
      style={{
        background:
          'linear-gradient(0deg, rgba(23, 23, 23, 0.93) 0%, rgba(23, 23, 23, 0.93) 100%), url(https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=1920&h=1080&fit=crop) center/cover no-repeat',
      }}
    >
      {/* Glow Effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -top-1/4 left-1/2 -translate-x-1/2 w-[200%] h-[200%] opacity-90 blur-[250px] bg-primary/20" />
      </div>

      {/* Content */}
      <div className="relative z-10 flex min-h-screen flex-col items-center justify-center px-4 pb-32">
        <div className="w-full max-w-[753px] space-y-14">
          {/* Header */}
          <div className="space-y-3">
            <div className="flex items-center gap-1">
              <h1 className="text-2xl font-semibold text-white">Welcome Back!</h1>
              <span className="text-2xl">👋</span>
            </div>
            <p className="text-sm text-[#AFAFAF]">Ready to continue your fitness journey?</p>
          </div>

          {/* Options */}
          <div className="flex gap-8">
            {/* My Fitness Plan */}
            <Link
              to="/schedule"
              className="group relative flex-1 overflow-hidden rounded-2xl border border-[#4A4A4A] bg-[#212121] p-6 transition-all hover:border-primary/50"
            >
              {/* Gradient Glow */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#0BB1D3]/60 to-[#5965EE]/60 opacity-0 blur-[30px] transition-opacity group-hover:opacity-100" />

              <div className="relative flex items-center gap-4">
                <div className="flex h-[60px] w-[60px] items-center justify-center rounded-full">
                  <span className="text-4xl">🏋🏻</span>
                </div>
                <div className="flex-1 space-y-2">
                  <h3 className="text-base font-bold text-white">My fitness plan</h3>
                  <p className="text-xs text-[#898989]">View your personalized schedule</p>
                </div>
                <svg
                  className="h-6 w-6 text-white transition-transform group-hover:translate-x-1"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </Link>

            {/* Start New Plan */}
            <Link
              to="/ai-coach/goal"
              className="group relative flex-1 overflow-hidden rounded-2xl border border-[#4A4A4A] bg-[#212121] p-6 transition-all hover:border-primary/50"
            >
              {/* Gradient Glow */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#0BD397]/60 to-[#B5EE59]/60 opacity-0 blur-[30px] transition-opacity group-hover:opacity-100" />

              <div className="relative flex items-center gap-4">
                <div className="flex h-[60px] w-[60px] items-center justify-center rounded-full">
                  <span className="text-4xl">✨</span>
                </div>
                <div className="flex-1 space-y-2">
                  <h3 className="text-base font-bold text-white">Start a new plan</h3>
                  <p className="text-xs text-[#898989]">Create a fresh fitness goal</p>
                </div>
                <svg
                  className="h-6 w-6 text-white transition-transform group-hover:translate-x-1"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </Link>
          </div>
        </div>
      </div>

      <BottomNavNew />
    </div>
  );
}
