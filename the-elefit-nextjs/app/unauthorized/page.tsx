"use client";

import { Header } from '@/components/Header';
import BottomNavNew from '@/components/BottomNavNew';
import { Button } from '@/components/ui/button';
import Link from 'next/link';

export default function UnauthorizedPage() {
    return (
        <div className="min-h-screen bg-black flex flex-col">
            <Header />

            <div className="flex-1 flex flex-col items-center justify-center p-4">
                <div className="text-center space-y-6 max-w-md">
                    <h1 className="text-9xl font-extrabold text-primary opacity-20">403</h1>
                    <div className="space-y-2">
                        <h2 className="text-3xl font-bold text-white">Access Denied</h2>
                        <p className="text-[#AFAFAF]">
                            You don't have permission to access this page. Please contact administration if you believe this is an error.
                        </p>
                    </div>

                    <div className="flex gap-4 justify-center">
                        <Button asChild className="bg-primary text-black hover:bg-primary/90">
                            <Link href="/">Go Home</Link>
                        </Button>
                        <Button asChild variant="outline" className="border-[#212121] text-white">
                            <Link href="/auth">Sign In</Link>
                        </Button>
                    </div>
                </div>
            </div>

            <BottomNavNew />
        </div>
    );
}
