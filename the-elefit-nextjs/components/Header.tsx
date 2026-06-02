"use client";

import Link from 'next/link';
import Image from 'next/image';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { LogOut } from 'lucide-react';

export function Header() {
  const { user: currentUserByAuth, isAuthenticated, logout } = useAuth();
  const router = useRouter();

  const handleLogout = async () => {
    try {
      await logout();
      router.push('/auth');
    } catch (error) {
      console.error('Logout failed:', error);
    }
  };

  return (
    <header className="fixed top-0 left-0 right-0 z-50 w-full border-b border-[#212121] bg-[#0D0D0D]">
      <div className="container flex h-[68px] w-full items-center justify-between px-4 md:px-[119px] max-w-full">
        {/* Logo */}
        <Link href="/" className="flex items-center">
          <div className="relative w-[120px] h-[40px]">
            <Image
              src="/logo.png"
              alt="ELEFIT"
              fill
              sizes="120px"
              className="object-contain"
              priority
            />
          </div>
        </Link>

        {/* Navigation */}
        <nav className="hidden md:flex items-center gap-6">
          <Link
            href="/ai-coach/welcome"
            className="px-4 py-2 text-sm font-medium text-white hover:bg-primary hover:text-black rounded-full transition-all active:scale-95"
          >
            AI Coach
          </Link>

          {isAuthenticated && currentUserByAuth ? (
            <div className="flex items-center gap-4">
              <Link
                href="/profile"
                className="px-4 py-2 text-sm font-medium text-white hover:bg-primary hover:text-black rounded-full transition-all"
              >
                Dashboard
              </Link>
              <button
                onClick={handleLogout}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-red-500 hover:text-red-400 transition-colors"
              >
                <LogOut className="w-4 h-4" />
                <span>Logout</span>
              </button>
            </div>
          ) : (
            <Link
              href="/auth"
              className="px-4 py-2 text-sm font-medium text-white hover:bg-primary hover:text-black rounded-full transition-all"
            >
              Login / Register
            </Link>
          )}
        </nav>
      </div>
    </header>
  );
}
