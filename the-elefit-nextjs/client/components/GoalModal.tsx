import { useState } from 'react';
import { X } from 'lucide-react';

interface GoalModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (goal: string) => void;
}

export function GoalModal({ isOpen, onClose, onSubmit }: GoalModalProps) {
  const [goal, setGoal] = useState('');

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (goal.trim()) {
      onSubmit(goal);
    }
  };

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/60 z-40" onClick={onClose} />

      {/* Modal */}
      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 z-50 w-full max-w-[393px] rounded-t-[40px] bg-[#171717] pb-8">
        {/* Glow Effect */}
        <div className="absolute inset-0 overflow-hidden rounded-t-[40px]">
          <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[200%] h-[200%] opacity-90 blur-[75px] bg-primary/20" />
        </div>

        {/* Handle */}
        <div className="relative flex justify-center pt-2.5 pb-4">
          <div className="w-[88px] h-1 rounded-full bg-[#A6A6A6]" />
        </div>

        {/* Content */}
        <div className="relative px-5 space-y-8">
          <div className="space-y-6">
            <div className="flex items-center gap-2.5">
              <h2 className="text-xl font-bold text-white">What's your fitness goal?</h2>
              <span className="text-2xl">🔥</span>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="flex items-center gap-2.5 rounded-2xl border border-[#454545] px-5.5 py-6">
                <input
                  type="text"
                  value={goal}
                  onChange={e => setGoal(e.target.value)}
                  placeholder="Lose 6 kg in 3 months 🏋️"
                  className="flex-1 bg-transparent text-white placeholder:text-[#666] focus:outline-none"
                />
                {goal && (
                  <button
                    type="button"
                    onClick={() => setGoal('')}
                    className="flex h-5 w-5 items-center justify-center rounded-full bg-[#A6A6A6] hover:bg-[#999]"
                  >
                    <X className="h-3 w-3 text-white" />
                  </button>
                )}
              </div>

              <button
                type="submit"
                disabled={!goal.trim()}
                className="w-full rounded-full bg-primary py-4 font-bold text-black transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Create my plan
              </button>
            </form>
          </div>
        </div>
      </div>
    </>
  );
}
