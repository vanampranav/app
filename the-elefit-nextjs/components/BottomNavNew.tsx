import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
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
  const pathname = usePathname();
  const router = useRouter();

  // Check if current page should hide the bottom nav
  const shouldHide = hideOnPages.some(page => pathname.includes(page));

  if (shouldHide) {
    return null;
  }

  const navItems: NavItem[] = [
    {
      id: 'ai-assistant',
      icon: Sparkles,
      label: 'AI Assistant',
      path: '/ai-coach/welcome',
      isActive: pathname === '/ai-coach/welcome' || pathname.startsWith('/ai-coach/'),
    },
    {
      id: 'weekly-schedule',
      icon: Calendar,
      label: 'Weekly Schedule',
      path: '/schedule',
      isActive: pathname === '/schedule',
    },
    {
      id: 'profile',
      icon: User,
      label: 'Profile',
      path: '/profile',
      isActive: pathname === '/profile',
    },
  ];

  const aiCoachSteps = ['/ai-coach/goal', '/ai-coach/details', '/ai-coach/preferences', '/ai-coach/calories'];
  const isAiCoachStep = aiCoachSteps.some(step => pathname.includes(step));

  return (
    <nav
      className={`fixed bottom-0 left-0 right-0 w-full flex items-center justify-center z-50 ${isAiCoachStep ? 'hidden md:flex' : 'flex'
        }`}
      role="navigation"
      aria-label="Main navigation"
    >
      <div className="flex h-[100px] md:h-[85px] w-full md:w-auto md:max-w-max items-center justify-around md:justify-center md:gap-12 bg-[#0c0c0c] rounded-t-[32px] px-6 md:px-12 py-4 shadow-2xl border border-[#212121] border-b-0 mx-auto transition-all duration-500">
        {navItems.map(item => {
          const IconComponent = item.icon;
          return (
            <button
              key={item.id}
              onClick={() => router.push(item.path)}
              className="flex flex-col items-center gap-2 group outline-none"
              aria-label={item.label}
              aria-current={item.isActive ? 'page' : undefined}
            >
              <div className={`flex h-[42px] w-[80px] items-center justify-center rounded-full transition-all duration-300 ${item.isActive ? 'bg-[#ccd853]' : 'hover:bg-white/5'
                }`}
              >
                <IconComponent
                  className={`w-6 h-6 transition-colors duration-300 ${item.isActive ? 'text-black' : 'text-[#898989] group-hover:text-white'}`}
                />
              </div>
              <span
                className={`text-[10px] text-center font-bold uppercase tracking-widest transition-colors duration-300 ${item.isActive ? 'text-[#ccd853]' : 'text-[#898989] group-hover:text-white'
                  }`}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}
