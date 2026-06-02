import { Header } from '@/components/Header';
import { BottomNav } from '@/components/BottomNav';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { CheckCircle2 } from 'lucide-react';

export default function ApplyExpert() {
  const requirements = [
    'Valid fitness certification (NASM, ACE, ISSA, etc.)',
    'First aid/CPR certification',
    'At least 2 years of fitness experience',
    'Liability insurance',
    'Pass background check',
    'Professional references'
  ];

  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <div className="flex-1 px-4 py-8 md:px-8 pb-32">
        <div className="max-w-4xl mx-auto">
          <div className="mb-12">
            <h1 className="text-4xl font-bold text-white mb-3">Become a Fitness Expert</h1>
            <p className="text-lg text-muted-foreground">Join our community and start earning by sharing your expertise</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
            <Card className="p-6 bg-card border-border">
              <h3 className="text-2xl font-bold text-primary mb-4">₹1,000+</h3>
              <p className="text-muted-foreground mb-4">Average earnings per session</p>
              <p className="text-sm text-muted-foreground">Set your own rates and build your client base</p>
            </Card>
            
            <Card className="p-6 bg-card border-border">
              <h3 className="text-2xl font-bold text-primary mb-4">Flexible Hours</h3>
              <p className="text-muted-foreground mb-4">Create your own schedule</p>
              <p className="text-sm text-muted-foreground">Work whenever it suits you best</p>
            </Card>
          </div>

          <Card className="p-8 bg-card border-border mb-12">
            <h2 className="text-2xl font-bold text-white mb-6">Eligibility Requirements</h2>
            <div className="space-y-4">
              {requirements.map((req, i) => (
                <div key={i} className="flex items-start gap-3">
                  <CheckCircle2 className="w-5 h-5 text-primary mt-0.5 flex-shrink-0" />
                  <span className="text-muted-foreground">{req}</span>
                </div>
              ))}
            </div>
          </Card>

          <Card className="p-8 bg-card border-border">
            <h2 className="text-2xl font-bold text-white mb-6">Application Form</h2>
            <form className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-muted-foreground mb-2">First Name</label>
                  <input
                    type="text"
                    className="w-full rounded-lg bg-background border border-border px-4 py-2 text-white"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-muted-foreground mb-2">Last Name</label>
                  <input
                    type="text"
                    className="w-full rounded-lg bg-background border border-border px-4 py-2 text-white"
                  />
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-muted-foreground mb-2">Email</label>
                <input
                  type="email"
                  className="w-full rounded-lg bg-background border border-border px-4 py-2 text-white"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-muted-foreground mb-2">Specialties</label>
                <select className="w-full rounded-lg bg-background border border-border px-4 py-2 text-white">
                  <option>Strength Training</option>
                  <option>Yoga</option>
                  <option>Cardio</option>
                  <option>HIIT</option>
                  <option>Nutrition</option>
                  <option>Other</option>
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-muted-foreground mb-2">Experience (Years)</label>
                <input
                  type="number"
                  className="w-full rounded-lg bg-background border border-border px-4 py-2 text-white"
                />
              </div>
              
              <Button className="w-full bg-primary hover:bg-primary/90 text-black font-semibold py-2">Submit Application</Button>
            </form>
          </Card>
        </div>
      </div>

      <BottomNav />
    </div>
  );
}
