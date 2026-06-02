import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Sparkles } from 'lucide-react';
import { BottomNav } from '@/components/BottomNav';

export default function Index() {
  const [goal, setGoal] = useState('');
  const navigate = useNavigate();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (goal.trim()) {
      navigate('/ai-coach/welcome');
    }
  };

  return (
    <div className="relative min-h-screen w-full overflow-hidden">
      {/* Hero Background Image */}
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{
          backgroundImage: `url('https://api.builder.io/api/v1/image/assets/TEMP/9d42c2049ddccd559d54aea55fddfcc4840c2365?width=2560')`,
        }}
      />

      {/* Content Container */}
      <div className="relative z-10 flex min-h-screen items-center justify-center px-4">
        {/* AI Coach Card */}
        <div className="w-full max-w-[649px] rounded-2xl border border-primary bg-[#0D0D0D] p-16">
          <div className="flex flex-col items-center gap-7">
            {/* AI Coach Badge */}
            <div className="flex items-center gap-2 rounded-full bg-primary px-4 py-2">
              <Sparkles className="h-4 w-4 text-black" />
              <span className="text-base font-medium text-black">AI Coach</span>
            </div>

            {/* Heading */}
            <h1 className="text-center text-xl font-bold leading-normal text-[#E1E1E1]">
              <span className="text-primary">EleFit AI</span> creates{' '}
              <span className="font-bold text-white">personalised meal & workout plans</span> to
              help you reach your fitness goals.
            </h1>

            {/* Input and Button */}
            <form onSubmit={handleSubmit} className="w-full max-w-md space-y-4">
              <div>
                <label
                  htmlFor="fitness-goal"
                  className="mb-2 flex items-center gap-2 text-base font-medium text-white"
                >
                  Enter your fitness goal 🔥
                </label>
                <p className="text-sm text-[#898989]">Takes less than 2 minutes</p>
              </div>

              <div className="flex items-center gap-3">
                <input
                  id="fitness-goal"
                  type="text"
                  value={goal}
                  onChange={e => setGoal(e.target.value)}
                  placeholder="e.g., Lose 5kg in 3 months"
                  className="flex-1 rounded-lg border border-[#454545] bg-[#212121] px-4 py-3 text-white placeholder:text-[#666] focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                />
                <button
                  type="submit"
                  disabled={!goal.trim()}
                  className="rounded-lg bg-primary px-8 py-3 font-medium text-black transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Go
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      {/* Bottom Navigation */}
      <BottomNav />
    </div>
  );
}
