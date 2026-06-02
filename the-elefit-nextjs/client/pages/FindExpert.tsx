import { Header } from '@/components/Header';
import { BottomNav } from '@/components/BottomNav';
import { Star, MapPin, Award } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

export default function FindExpert() {
  const experts = [
    { id: 1, name: 'Sarah Johnson', specialty: 'Strength Training', rating: 4.9, reviews: 234, location: '2 km away' },
    { id: 2, name: 'Mike Chen', specialty: 'Yoga & Flexibility', rating: 4.8, reviews: 189, location: '3 km away' },
    { id: 3, name: 'Emma Wilson', specialty: 'Cardio & HIIT', rating: 4.7, reviews: 156, location: '1 km away' },
    { id: 4, name: 'Alex Rodriguez', specialty: 'Nutrition & Diet', rating: 4.9, reviews: 201, location: '4 km away' },
  ];

  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <div className="flex-1 px-4 py-8 md:px-8 pb-32">
        <div className="max-w-6xl mx-auto">
          <div className="mb-12">
            <h1 className="text-4xl font-bold text-white mb-3">Find Expert</h1>
            <p className="text-lg text-muted-foreground">Discover certified fitness experts and book your sessions</p>
          </div>

          <Card className="p-6 bg-card border-border mb-8">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <input
                type="text"
                placeholder="Search experts..."
                className="rounded-lg bg-background border border-border px-4 py-2 text-white placeholder-muted-foreground"
              />
              <select className="rounded-lg bg-background border border-border px-4 py-2 text-white">
                <option>All Specialties</option>
                <option>Strength Training</option>
                <option>Yoga</option>
                <option>Cardio</option>
                <option>Nutrition</option>
              </select>
              <Button className="w-full bg-primary hover:bg-primary/90 text-black font-semibold">Search</Button>
            </div>
          </Card>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {experts.map((expert) => (
              <Card key={expert.id} className="p-6 bg-card border-border hover:border-primary/50 transition-colors">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-xl font-bold text-white">{expert.name}</h3>
                    <p className="text-primary text-sm font-medium">{expert.specialty}</p>
                  </div>
                  <Award className="w-6 h-6 text-primary" />
                </div>
                
                <div className="space-y-3">
                  <div className="flex items-center gap-2 text-muted-foreground">
                    <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                    <span className="font-semibold text-white">{expert.rating}</span>
                    <span>({expert.reviews} reviews)</span>
                  </div>
                  
                  <div className="flex items-center gap-2 text-muted-foreground">
                    <MapPin className="w-4 h-4" />
                    <span>{expert.location}</span>
                  </div>
                </div>
                
                <Button className="w-full mt-4 bg-primary hover:bg-primary/90 text-black font-semibold">Book Session</Button>
              </Card>
            ))}
          </div>
        </div>
      </div>

      <BottomNav />
    </div>
  );
}
