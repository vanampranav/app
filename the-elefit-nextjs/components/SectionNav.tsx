"use client";

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Sparkles, Calendar, User } from 'lucide-react';

export function SectionNav() {
    const pathname = usePathname();

    const navItems = [
        {
            id: 'ai-assistant',
            icon: Sparkles,
            label: 'AI Assistant',
            path: '/ai-coach',
            isActive: pathname === '/ai-coach' || pathname.startsWith('/ai-coach/'),
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

    return (
        <nav className="w-full bg-[#0D0D0D] border-b border-[#212121] pt-4">
            <div className="flex items-center justify-center gap-8 md:gap-16">
                {navItems.map((item) => {
                    const Icon = item.icon;
                    return (
                        <Link
                            key={item.id}
                            href={item.path}
                            className="flex flex-col items-center gap-2 group pb-2 relative"
                        >
                            <div
                                className={`flex h-12 w-20 md:w-24 items-center justify-center rounded-2xl transition-all ${item.isActive ? 'bg-[#ccd853]' : 'hover:bg-[#212121]'
                                    }`}
                            >
                                <Icon
                                    className={`w-5 h-5 ${item.isActive ? 'text-[#1e1e1e]' : 'text-[#828282]'}`}
                                />
                            </div>
                            <span
                                className={`text-[10px] md:text-xs font-semibold ${item.isActive ? 'text-[#ccd853]' : 'text-[#828282]'
                                    }`}
                            >
                                {item.label}
                            </span>
                            {item.isActive && (
                                <div className="absolute -bottom-[1px] left-0 right-0 h-[2px] bg-[#ccd853] hidden md:block" />
                            )}
                        </Link>
                    );
                })}
            </div>
        </nav>
    );
}
