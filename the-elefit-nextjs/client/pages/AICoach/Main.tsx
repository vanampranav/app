import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Sparkles, Calendar, User } from 'lucide-react';
import aiCoachBackground from '@/assets/images/ai-coach-background.jpeg';
import BottomNav from '@/components/BottomNavNew';

export default function AICoach() {
  const [fitnessGoal, setFitnessGoal] = useState('');
  const navigate = useNavigate();

  const handleGoClick = () => {
    if (fitnessGoal.trim()) {
      console.log('Fitness goal submitted:', fitnessGoal);
      // Navigate to the existing AI Coach flow
      navigate('/ai-coach/goal');
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleGoClick();
    }
  };

  return (
    <div className="relative min-h-screen w-full overflow-hidden">
      {/* Background Image */}
      <div className="absolute inset-0">
        <img
          src={aiCoachBackground}
          alt="AI Coach Background"
          className="w-full h-full object-cover"
        />
        {/* Dark overlay for better text readability */}
        <div className="absolute inset-0 bg-black/70"></div>
      </div>

      {/* Main Content */}
      <div className="relative z-10 min-h-screen flex flex-col pt-8">
        {/* Hero Section */}
        <div className="flex-1 flex items-center justify-center px-4">
          <div className="w-full max-w-2xl">
            {/* AI Coach Badge */}
            <div className="flex items-center gap-3 mb-8 justify-center">
              <div className="bg-[#ccd853] rounded-full px-4 py-2 flex items-center gap-2 shadow-lg">
                <Sparkles className="w-5 h-5 text-[#1e1e1e]" />
                <span className="text-[#1e1e1e] font-medium">AI Coach</span>
              </div>
            </div>

            {/* Main Card */}
            <div className="bg-[#0c0c0c]/90 backdrop-blur-lg rounded-2xl border border-[#ccd853] p-8 md:p-12">
              <div className="text-center space-y-6">
                <h1 className="text-2xl md:text-3xl font-bold">
                  <span className="text-[#ccd853]">EleFit AI</span>{' '}
                  <span className="text-[#e1e1e1]">
                    creates <span className="font-bold">personalised meal & workout plans</span> to
                    help you reach your fitness goals.
                  </span>
                </h1>

                <div className="bg-[#0c0c0c] rounded-xl border border-[#212121] p-4">
                  <div className="flex flex-col md:flex-row items-center gap-4">
                    <div className="flex-1 w-full">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-[#dedede] font-medium">Enter your fitness goal</span>
                        <span className="text-lg">🔥</span>
                      </div>
                      <input
                        type="text"
                        value={fitnessGoal}
                        onChange={e => setFitnessGoal(e.target.value)}
                        onKeyPress={handleKeyPress}
                        placeholder="Takes less than 2 minutes"
                        className="w-full bg-transparent text-[#6b6b6b] placeholder:text-[#6b6b6b] text-sm focus:outline-none"
                      />
                    </div>
                    <button
                      onClick={handleGoClick}
                      disabled={!fitnessGoal.trim()}
                      className="bg-[#ccd853] text-[#212121] font-bold px-6 py-3 rounded-[18px] hover:bg-[#d4e05f] transition-colors disabled:opacity-50 disabled:cursor-not-allowed min-w-[89px]"
                    >
                      Go
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Navigation */}
        <BottomNav />
      </div>
    </div>
  );
}
