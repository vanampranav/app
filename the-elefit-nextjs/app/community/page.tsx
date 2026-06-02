"use client";

import { Header } from '@/components/Header';
import BottomNavNew from '@/components/BottomNavNew';
import { Users, MessageCircle, TrendingUp } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { ProtectedRoute } from '@/components/ProtectedRoute';

export default function CommunityPage() {
    return (
        <ProtectedRoute>
            <CommunityContent />
        </ProtectedRoute>
    );
}

function CommunityContent() {
    return (
        <div className="min-h-screen bg-black">
            <Header />

            <div className="flex-1 px-4 py-8 md:px-8 pb-32">
                <div className="max-w-6xl mx-auto">
                    <div className="mb-12">
                        <h1 className="text-4xl font-bold text-white mb-3">Community</h1>
                        <p className="text-lg text-[#AFAFAF]">Connect with fitness enthusiasts and share your journey</p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
                        <Card className="p-6 bg-[#0D0D0D] border-[#212121]">
                            <div className="flex items-center gap-4">
                                <Users className="w-10 h-10 text-primary" />
                                <div>
                                    <p className="text-[#AFAFAF] text-sm">Total Members</p>
                                    <p className="text-3xl font-bold text-white">2,453</p>
                                </div>
                            </div>
                        </Card>
                        <Card className="p-6 bg-[#0D0D0D] border-[#212121]">
                            <div className="flex items-center gap-4">
                                <MessageCircle className="w-10 h-10 text-primary" />
                                <div>
                                    <p className="text-[#AFAFAF] text-sm">Discussions</p>
                                    <p className="text-3xl font-bold text-white">1,847</p>
                                </div>
                            </div>
                        </Card>
                        <Card className="p-6 bg-[#0D0D0D] border-[#212121]">
                            <div className="flex items-center gap-4">
                                <TrendingUp className="w-10 h-10 text-primary" />
                                <div>
                                    <p className="text-[#AFAFAF] text-sm">Active This Week</p>
                                    <p className="text-3xl font-bold text-white">892</p>
                                </div>
                            </div>
                        </Card>
                    </div>

                    <div className="bg-[#0D0D0D] border border-[#212121] rounded-2xl p-12 text-center">
                        <p className="text-white text-xl mb-4">Coming Soon: Interactive Forums & Groups</p>
                        <p className="text-[#AFAFAF]">We're building a vibrant community for all EleFit users.</p>
                    </div>
                </div>
            </div>
            <BottomNavNew />
        </div>
    );
}
