import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Sparkles, Calendar, User } from 'lucide-react';

interface NavItem {
  id: string;
  icon: React.ElementType;
  label: string;
  path: string;
  isActive: boolean;
}

interface BottomNavProps {
  hideOnPages?: string[];
}

export default function BottomNavNew({ hideOnPages = [] }: BottomNavProps) {
  const location = useLocation();
  const navigate = useNavigate();

  // Check if current page should hide the bottom nav
  const shouldHide = hideOnPages.some(page => location.pathname.includes(page));

  if (shouldHide) {
    return null;
  }

  const navItems: NavItem[] = [
    {
      id: 'ai-assistant',
      icon: Sparkles,
      label: 'AI Assistant',
      path: '/ai-coach',
      isActive: location.pathname === '/ai-coach' || location.pathname.startsWith('/ai-coach/'),
    },
    {
      id: 'weekly-schedule',
      icon: Calendar,
      label: 'Weekly Schedule',
      path: '/schedule',
      isActive: location.pathname === '/schedule',
    },
    {
      id: 'profile',
      icon: User,
      label: 'Profile',
      path: '/user-dashboard',
      isActive: location.pathname === '/user-dashboard' || location.pathname === '/profile',
    },
  ];

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 w-full flex items-center justify-center z-50"
      role="navigation"
      aria-label="Main navigation"
    >
      <div className="flex h-[80px] w-full max-w-md items-center justify-center gap-8 bg-[#0c0c0c] rounded-t-3xl px-6 py-4 shadow-2xl border border-[#212121] border-b-0 mx-auto">
        {navItems.map(item => {
          const IconComponent = item.icon;
          return (
            <div key={item.id} className="flex flex-col items-center gap-2 flex-1">
              <button
                onClick={() => navigate(item.path)}
                className={`flex h-12 items-center justify-center gap-2 px-5 py-2 w-full rounded-2xl transition-all ${
                  item.isActive ? 'bg-[#ccd853]' : 'hover:bg-[#212121]'
                }`}
                aria-label={item.label}
                aria-current={item.isActive ? 'page' : undefined}
              >
                <IconComponent
                  className={`w-5 h-5 ${item.isActive ? 'text-[#1e1e1e]' : 'text-[#e4e4e4]'}`}
                />
              </button>

              <div
                className={`text-xs text-center font-medium ${
                  item.isActive ? 'text-[#ccd853]' : 'text-[#e4e4e4]'
                }`}
              >
                {item.label}
              </div>
            </div>
          );
        })}
      </div>
    </nav>
  );
}
