import { Link, useLocation } from 'react-router-dom';
import { Sparkles, Calendar, User } from 'lucide-react';

export function BottomNav() {
  const location = useLocation();
  
  const isActive = (path: string) => location.pathname === path;

  return (
    <div className="md:hidden fixed bottom-0 left-0 right-0 z-50 w-full p-3 bg-gradient-to-t from-[#1A1A1A] via-[#212121] to-transparent backdrop-blur-[42.5px] border-t border-[#454545]">
      <div className="flex items-center justify-around gap-4">
        {/* AI Assistant */}
        <Link to="/ai-coach" className="flex flex-col items-center gap-1">
          <div className={`flex h-10 items-center justify-center gap-1 rounded-3xl px-4 transition-all ${
            isActive('/ai-coach') || location.pathname.startsWith('/ai-coach') 
              ? 'bg-primary' 
              : ''
          }`}>
            <Sparkles className={`w-5 h-5 ${
              isActive('/ai-coach') || location.pathname.startsWith('/ai-coach')
                ? 'text-black fill-black' 
                : 'text-[#E4E4E4]'
            }`} />
          </div>
          <span className={`text-xs font-medium ${
            isActive('/ai-coach') || location.pathname.startsWith('/ai-coach')
              ? 'text-primary' 
              : 'text-[#E4E4E4]'
          }`}>
            AI
          </span>
        </Link>

        {/* Weekly Schedule */}
        <Link to="/schedule" className="flex flex-col items-center gap-1">
          <div className={`flex h-10 items-center justify-center gap-1 rounded-3xl px-4 transition-all ${
            isActive('/schedule') ? 'bg-primary' : ''
          }`}>
            <Calendar className={`w-5 h-5 ${
              isActive('/schedule') ? 'text-black' : 'text-[#E4E4E4]'
            }`} />
          </div>
          <span className={`text-xs font-medium ${
            isActive('/schedule') ? 'text-primary' : 'text-[#E4E4E4]'
          }`}>
            Schedule
          </span>
        </Link>

        {/* Profile */}
        <Link to="/profile" className="flex flex-col items-center gap-1">
          <div className={`flex h-10 items-center justify-center gap-1 rounded-3xl px-4 transition-all ${
            isActive('/profile') ? 'bg-primary' : ''
          }`}>
            <User className={`w-5 h-5 ${
              isActive('/profile') ? 'text-black' : 'text-[#E4E4E4]'
            }`} />
          </div>
          <span className={`text-xs font-medium ${
            isActive('/profile') ? 'text-primary' : 'text-[#E4E4E4]'
          }`}>
            Profile
          </span>
        </Link>
      </div>
    </div>
  );
}
