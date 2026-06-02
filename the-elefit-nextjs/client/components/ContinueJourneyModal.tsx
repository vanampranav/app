import { X } from 'lucide-react';

interface ContinueJourneyModalProps {
  isOpen: boolean;
  onClose: () => void;
  onContinue: () => void;
  onNewGoal: () => void;
}

export function ContinueJourneyModal({
  isOpen,
  onClose,
  onContinue,
  onNewGoal,
}: ContinueJourneyModalProps) {
  if (!isOpen) return null;

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
          <div className="space-y-3">
            <h2 className="text-xl font-bold text-white">Continue your journey?</h2>
            <p className="text-sm font-medium text-[#898989]">
              Would you like to view your current plan or change your fitness goal?
            </p>
          </div>

          <div className="space-y-3.5">
            <button
              onClick={onContinue}
              className="w-full rounded-full bg-primary py-4 font-bold text-black transition-colors hover:bg-primary/90"
            >
              Continue with current plan
            </button>
            <button
              onClick={onNewGoal}
              className="w-full rounded-full border border-primary bg-transparent py-4 font-bold text-primary transition-colors hover:bg-primary/10"
            >
              Change my goal
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
