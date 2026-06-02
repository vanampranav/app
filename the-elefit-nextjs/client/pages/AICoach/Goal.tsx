import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';

export default function Goal() {
  const [goal, setGoal] = useState('');
  const navigate = useNavigate();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (goal.trim()) {
      navigate('/ai-coach/details');
    }
  };

  return (
    <div className="relative min-h-screen w-full bg-[#3D3D3D] md:h-[1495px] md:w-[1920px] md:mx-auto">
      {/* Glow Effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[200%] h-[100%] opacity-90 blur-[250px] bg-primary/20" />
      </div>

      {/* Header with Back Button */}
      <div className="relative z-10 border-b border-[#454545] bg-[#212121] px-4 md:px-32 py-4 md:py-7">
        <div className="flex items-center gap-4 md:gap-28">
          <Link
            to="/ai-coach/welcome"
            className="flex h-9 w-9 items-center justify-center rounded-full bg-primary flex-shrink-0"
          >
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
      </div>

      {/* Content */}
      <div className="relative z-10 flex min-h-[calc(100vh-154px)] items-center justify-center px-4 md:px-0 pb-24 md:pb-32">
        <div className="w-full max-w-[353px] space-y-8 md:space-y-10">
          <div className="space-y-4 md:space-y-6">
            <div className="flex items-center gap-2">
              <h1 className="text-xl md:text-2xl font-bold text-white">What's your fitness goal?</h1>
              <span className="text-2xl flex-shrink-0">🔥</span>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4 md:space-y-6">
              <input
                type="text"
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
                placeholder="Lose 6 kg in 3 months 🏋️"
                className="w-full rounded-2xl border border-[#454545] bg-[#212121] px-4 md:px-6 py-4 md:py-5 text-white placeholder:text-[#666] focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary text-sm md:text-base"
              />

              <button
                type="submit"
                disabled={!goal.trim()}
                className="w-full rounded-full bg-primary py-3 md:py-4 font-bold text-black transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px]"
              >
                Create my plan
              </button>
            </form>
          </div>
        </div>
      </div>

      <BottomNav />
    </div>
  );
}
