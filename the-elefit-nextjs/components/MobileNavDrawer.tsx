"use client";

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { X } from 'lucide-react';

interface MobileNavDrawerProps {
    title?: string;
}

export default function MobileNavDrawer({ title }: MobileNavDrawerProps) {
    const [isOpen, setIsOpen] = useState(false);
    const { user: currentUserByAuth, isAuthenticated, logout } = useAuth();
    const router = useRouter();
    const pathname = usePathname();

    const handleLogout = async () => {
        try {
            await logout();
            router.push('/auth');
        } catch (error) {
            console.error('Logout failed:', error);
        }
    };

    return (
        <>
            {/* Mobile Top Bar */}
            <header className="md:hidden sticky top-0 z-50 flex items-center justify-between h-16 px-4 bg-[#0D0D0D] border-b border-[#212121]">
                <Link href="/" className="flex items-center">
                    <div className="relative w-[100px] h-[32px]">
                        <Image
                            src="/logo.png"
                            alt="ELEFIT"
                            fill
                            className="object-contain"
                            priority
                        />
                    </div>
                </Link>

                {title && (
                    <span className="absolute left-1/2 -translate-x-1/2 text-base font-bold text-white">{title}</span>
                )}

                {/* Two-Line Hamburger Button (same as welcome page) */}
                <button
                    onClick={() => setIsOpen(true)}
                    className="h-10 w-10 flex items-center justify-center rounded-full bg-black/20 backdrop-blur-md border border-white/10 group"
                    aria-label="Open navigation menu"
                >
                    <div className="flex flex-col gap-1 items-end">
                        <div className="h-[2px] w-5 bg-primary group-hover:w-6 transition-all" />
                        <div className="h-[2px] w-4 bg-primary group-hover:w-6 transition-all" />
                    </div>
                </button>
            </header>

            {/* Overlay Backdrop */}
            <div
                className={`md:hidden fixed inset-0 z-[60] bg-black/60 backdrop-blur-sm transition-opacity duration-300 ${isOpen ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
                onClick={() => setIsOpen(false)}
            />

            {/* Slide-In Drawer from Right */}
            <div
                className={`md:hidden fixed top-0 right-0 bottom-0 z-[70] w-[75vw] max-w-[300px] bg-[#0c0c0c] border-l border-white/10 flex flex-col transition-transform duration-500 ease-out ${isOpen ? 'translate-x-0' : 'translate-x-full'}`}
            >
                {/* Drawer Header */}
                <div className="flex items-center justify-between px-5 h-16 border-b border-white/10">
                    <div className="relative w-[90px] h-[28px]">
                        <Image src="/logo.png" alt="ELEFIT" fill className="object-contain" />
                    </div>
                    <button
                        onClick={() => setIsOpen(false)}
                        className="h-9 w-9 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-colors"
                        aria-label="Close menu"
                    >
                        <X className="w-4 h-4 text-white" />
                    </button>
                </div>

                {/* Nav Links */}
                <nav className="flex flex-col flex-1 px-4 py-6 gap-1">
                    {/* AI Coach – highlighted only when active */}
                    <Link
                        href="/ai-coach/welcome"
                        onClick={() => setIsOpen(false)}
                        className={`flex items-center px-4 py-3.5 rounded-2xl text-sm transition-all ${pathname?.startsWith('/ai-coach')
                                ? 'font-black text-black bg-primary'
                                : 'font-semibold text-white/70 hover:text-white hover:bg-white/5'
                            }`}
                    >
                        AI Coach
                    </Link>

                    {isAuthenticated && currentUserByAuth ? (
                        <>
                            <Link
                                href="/profile"
                                onClick={() => setIsOpen(false)}
                                className="flex items-center px-4 py-3.5 rounded-2xl text-sm font-semibold text-white/70 hover:text-white hover:bg-white/5 transition-all mt-1"
                            >
                                Dashboard
                            </Link>
                            <button
                                onClick={handleLogout}
                                className="flex items-center px-4 py-3.5 rounded-2xl text-sm font-semibold text-red-400 hover:text-red-300 hover:bg-red-500/5 transition-all"
                            >
                                Logout
                            </button>
                        </>
                    ) : (
                        <Link
                            href="/auth"
                            onClick={() => setIsOpen(false)}
                            className="flex items-center px-4 py-3.5 rounded-2xl text-sm font-semibold text-white/70 hover:text-white hover:bg-white/5 transition-all mt-1"
                        >
                            Login / Register
                        </Link>
                    )}
                </nav>
            </div>
        </>
    );
}
