"use client";

import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { usePathname } from "next/navigation";
import { AuthProvider } from "@/contexts/AuthContext";
import { AiCoachProvider } from "@/contexts/AiCoachContext";
import { TooltipProvider } from "@/components/ui/tooltip";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const disableAuth = pathname === "/";
    const content = (
        <TooltipProvider>
            {children}
            <Toaster />
            <Sonner />
        </TooltipProvider>
    );

    return (
        <QueryClientProvider client={queryClient}>
            {disableAuth ? (
                content
            ) : (
                <AuthProvider>
                    <AiCoachProvider>{content}</AiCoachProvider>
                </AuthProvider>
            )}
        </QueryClientProvider>
    );
}
