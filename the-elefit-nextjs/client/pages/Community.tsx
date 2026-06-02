import { Header } from '@/components/Header';
import { BottomNav } from '@/components/BottomNav';
import { Users, MessageCircle, TrendingUp } from 'lucide-react';
import { Card } from '@/components/ui/card';

export default function Community() {
  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <div className="flex-1 px-4 py-8 md:px-8 pb-32">
        <div className="max-w-6xl mx-auto">
          <div className="mb-12">
            <h1 className="text-4xl font-bold text-white mb-3">Community</h1>
            <p className="text-lg text-muted-foreground">Connect with fitness enthusiasts and share your journey</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
            <Card className="p-6 bg-card border-border">
              <div className="flex items-center gap-4">
                <Users className="w-10 h-10 text-primary" />
                <div>
                  <p className="text-muted-foreground text-sm">Total Members</p>
                  <p className="text-3xl font-bold text-white">2,453</p>
                </div>
              </div>
            </Card>
            <Card className="p-6 bg-card border-border">
              <div className="flex items-center gap-4">
                <MessageCircle className="w-10 h-10 text-primary" />
                <div>
                  <p className="text-muted-foreground text-sm">Discussions</p>
                  <p className="text-3xl font-bold text-white">1,847</p>
                </div>
              </div>
            </Card>
            <Card className="p-6 bg-card border-border">
              <div className="flex items-center gap-4">
                <TrendingUp className="w-10 h-10 text-primary" />
                <div>
                  <p className="text-muted-foreground text-sm">Active This Week</p>
                  <p className="text-3xl font-bold text-white">892</p>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
      <BottomNav />
    </div>
  );
}
