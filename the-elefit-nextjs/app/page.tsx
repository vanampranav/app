"use client";

import { motion } from "framer-motion";
import {
  ArrowRight,
  BrainCircuit,
  CheckCircle2,
  Compass,
  HeartPulse,
  MessageCircleHeart,
  Sparkles,
  TrendingUp,
  Users,
} from "lucide-react";
import { CTAButton } from "@/components/landing/CTAButton";
import { EarlyAccessForm } from "@/components/landing/EarlyAccessForm";
import { FeatureCard } from "@/components/landing/FeatureCard";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { Navbar } from "@/components/landing/Navbar";
import { PhoneMockup } from "@/components/landing/PhoneMockup";
import { SectionHeader } from "@/components/landing/SectionHeader";
import { TestimonialCard } from "@/components/landing/TestimonialCard";

const howItWorks = [
  {
    title: "Get Your Plan",
    description: "AI-powered guidance for meals, workouts, and daily choices that fit your schedule and goals.",
    icon: <Compass className="h-5 w-5" />,
    accent: "from-teal-400/20 to-cyan-500/20",
  },
  {
    title: "Stay Accountable",
    description: "Join challenges, complete check-ins, and keep momentum with your people and your coach.",
    icon: <Users className="h-5 w-5" />,
    accent: "from-cyan-400/20 to-blue-500/20",
  },
  {
    title: "Transform Consistently",
    description: "Track progress, build habits, and celebrate results without the overwhelm of doing it alone.",
    icon: <TrendingUp className="h-5 w-5" />,
    accent: "from-blue-400/20 to-slate-500/20",
  },
];

const problemPoints = [
  "No clear weekly rhythm or structure",
  "Hard-to-maintain accountability and feedback",
  "Too much noise from generic advice",
  "Motivation fades without a real community",
];

const challengePoints = [
  "Weekly transformation sprints built around behavior change",
  "Meal logging, check-ins, and habit streaks in one flow",
  "Shared wins and encouraging accountability from the group",
];

const communityPoints = [
  "Private circles for friends, partners, or accountability pods",
  "Meaningful check-ins that feel human, not transactional",
  "A calm space to share wins, setbacks, and momentum",
];

const progressPoints = [
  "Body composition and weight trends in one dashboard",
  "Workout consistency and recovery insights over time",
  "Simple weekly summaries so progress feels clear and motivating",
];

const testimonials = [
  {
    quote: "I finally feel like I have a system that fits my real life. The coaching feels personal and the community keeps me going.",
    name: "Maya, 41",
    role: "Parent of two and marketing lead",
  },
  {
    quote: "EleFit helped me stop starting over every Monday. I’m stronger, leaner, and more consistent than I’ve been in years.",
    name: "Daniel, 47",
    role: "Operations director",
  },
  {
    quote: "The mix of AI guidance, challenges, and real accountability changed everything for me. It feels calm, clear, and doable.",
    name: "Lina, 35",
    role: "Product designer",
  },
];

export default function Home() {
  return (
    <div className="min-h-screen bg-[#050816] text-white">
      <Navbar />
      <main>
        <Hero />

        <motion.section
          id="problem"
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.6 }}
          className="px-4 py-20 sm:px-6 lg:px-8"
        >
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-slate-950/90 via-slate-900/80 to-[#071324] p-8 shadow-[0_30px_120px_rgba(0,0,0,0.3)] lg:grid-cols-[0.95fr_1.05fr] lg:p-12">
            <div>
              <SectionHeader
                eyebrow="The problem"
                title="Fitness fails when you do it alone."
                description="Most people don’t fail because they lack motivation. They fail because they lack structure, accountability, feedback, and community. EleFit turns your fitness journey into a simple weekly system."
              />
              <div className="mt-8 flex flex-wrap gap-3">
                {problemPoints.map((point) => (
                  <div key={point} className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">
                    {point}
                  </div>
                ))}
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-[1.75rem] border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-teal-400/15 text-teal-300">
                  <HeartPulse className="h-6 w-6" />
                </div>
                <h3 className="mt-5 text-xl font-semibold text-white">A calmer path</h3>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Replace hustle with a sustainable rhythm built around consistency, not punishment.
                </p>
              </div>
              <div className="rounded-[1.75rem] border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-cyan-400/15 text-cyan-300">
                  <Sparkles className="h-6 w-6" />
                </div>
                <h3 className="mt-5 text-xl font-semibold text-white">Adaptive coaching</h3>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Your plan adjusts with your life so you can stay on track during busy seasons.
                </p>
              </div>
            </div>
          </div>
        </motion.section>

        <motion.section id="how-it-works" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <SectionHeader
              eyebrow="How EleFit works"
              title="Three simple steps to stay consistent."
              description="The experience is designed to feel clear, calm, and motivating from the first week onward."
              centered
            />

            <div className="mt-12 grid gap-6 lg:grid-cols-3">
              {howItWorks.map((item, index) => (
                <FeatureCard key={item.title} title={item.title} description={item.description} icon={item.icon} accent={item.accent} />
              ))}
            </div>
          </div>
        </motion.section>

        <motion.section id="challenges" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-white/5 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.2)] backdrop-blur-xl lg:grid-cols-[0.95fr_1.05fr] lg:p-12">
            <div>
              <SectionHeader
                eyebrow="Transformation challenges"
                title="Challenges that keep you moving."
                description="Weekly challenges make progress feel tangible, energizing, and shared with people who understand the journey."
              />
              <ul className="mt-8 space-y-4">
                {challengePoints.map((point) => (
                  <li key={point} className="flex items-start gap-3 text-slate-300">
                    <CheckCircle2 className="mt-0.5 h-5 w-5 flex-none text-teal-300" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </div>
            <PhoneMockup imageSrc="/images/challenge-dashboard.png" alt="EleFit transformation challenge experience" />
          </div>
        </motion.section>

        <motion.section id="community" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-[#07111f] to-slate-900/90 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.24)] lg:grid-cols-[1.05fr_0.95fr] lg:p-12">
            <PhoneMockup imageSrc="/images/community.jpg" alt="EleFit community experience" />
            <div>
              <SectionHeader
                eyebrow="Community"
                title="Built around people, not just data."
                description="The app combines smart guidance with human connection so your progress feels supported in real life."
              />
              <ul className="mt-8 space-y-4">
                {communityPoints.map((point) => (
                  <li key={point} className="flex items-start gap-3 text-slate-300">
                    <MessageCircleHeart className="mt-0.5 h-5 w-5 flex-none text-cyan-300" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </motion.section>

        <motion.section id="ai-coach" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-white/5 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.2)] backdrop-blur-xl lg:grid-cols-[0.95fr_1.05fr] lg:p-12">
            <div>
              <SectionHeader
                eyebrow="AI Coach"
                title="Guidance when you need it."
                description="EleFit gives you personalized nudges, meal suggestions, and fitness support without you having to think through every decision."
              />
              <div className="mt-8 rounded-[1.75rem] border border-teal-400/20 bg-gradient-to-br from-teal-400/10 to-cyan-400/10 p-6">
                <div className="flex items-center gap-3 text-teal-200">
                  <BrainCircuit className="h-5 w-5" />
                  <p className="font-semibold">Adaptive support for busy weeks</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Your coach helps you decide what to do next, whether your goal is to lose fat, move more, or build sustainable consistency.
                </p>
              </div>
            </div>
            <PhoneMockup imageSrc="/images/ai-coach.png" alt="EleFit AI coach experience" />
          </div>
        </motion.section>

        <motion.section id="progress" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-[#07111f] to-[#111c34] p-8 shadow-[0_30px_120px_rgba(0,0,0,0.24)] lg:grid-cols-[1.05fr_0.95fr] lg:p-12">
            <div>
              <SectionHeader
                eyebrow="Progress tracking"
                title="See your progress clearly."
                description="The app turns your habits and measurements into a clear weekly story you can actually trust."
              />
              <div className="mt-8 grid gap-4 sm:grid-cols-2">
                {progressPoints.map((point) => (
                  <div key={point} className="rounded-[1.25rem] border border-white/10 bg-white/5 p-4 text-sm text-slate-300 backdrop-blur-xl">
                    {point}
                  </div>
                ))}
              </div>
            </div>
            <PhoneMockup imageSrc="/images/app-dashboard.png" alt="EleFit progress tracking dashboard" />
          </div>
        </motion.section>

        <motion.section id="app-experience" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl rounded-[2.5rem] border border-white/10 bg-white/5 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.2)] backdrop-blur-xl lg:p-12">
            <SectionHeader
              eyebrow="App experience"
              title="A premium experience made for real life."
              description="Every touchpoint feels intentional, with a calm interface, strong visual feedback, and beautifully simple flows."
              centered
            />
            <div className="mt-12 grid gap-8 lg:grid-cols-[0.9fr_1.1fr]">
              <div className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-6">
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-teal-300">Mobile-first, premium feel</p>
                <p className="mt-4 text-lg leading-8 text-slate-300">
                  The interface is designed for quick check-ins, low friction logging, and meaningful weekly reflections.
                </p>
                <div className="mt-8 flex flex-wrap gap-3">
                  <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Meal logging</div>
                  <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Workout tracking</div>
                  <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Body metrics</div>
                </div>
              </div>
              <div className="grid gap-6 sm:grid-cols-2">
                <PhoneMockup imageSrc="/images/app-dashboard.png" alt="EleFit dashboard preview" />
                <PhoneMockup imageSrc="/images/ai-coach.png" alt="EleFit coach preview" />
              </div>
            </div>
          </div>
        </motion.section>

        <motion.section id="founder-story" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-[#0a1222] to-[#060b16] p-8 shadow-[0_30px_120px_rgba(0,0,0,0.22)] lg:grid-cols-[0.95fr_1.05fr] lg:p-12">
            <div>
              <SectionHeader
                eyebrow="Founder story"
                title="Built by people on the same journey."
                description="EleFit was created for adults who want to feel healthy, strong, and energized without turning fitness into a second job."
              />
              <p className="mt-8 text-lg leading-8 text-slate-300">
                We built this experience from the perspective of busy professionals and parents who need structure, not shame. The goal is simple: make consistency feel natural.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Evidence-based coaching</div>
                <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Human accountability</div>
                <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">Long-term change</div>
              </div>
            </div>
            <PhoneMockup imageSrc="/images/founder.jpg" alt="Founder story visual" />
          </div>
        </motion.section>

        <motion.section id="testimonials" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 py-20 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <SectionHeader
              eyebrow="Testimonials"
              title="Real stories from people building consistency."
              description="The best feedback comes from people who finally feel a system working with their life, not against it."
              centered
            />
            <div className="mt-12 grid gap-6 lg:grid-cols-3">
              {testimonials.map((testimonial) => (
                <TestimonialCard key={testimonial.name} quote={testimonial.quote} name={testimonial.name} role={testimonial.role} />
              ))}
            </div>
          </div>
        </motion.section>

        <motion.section id="early-access" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.2 }} transition={{ duration: 0.6 }} className="px-4 pb-20 pt-10 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl rounded-[2.5rem] border border-teal-400/20 bg-gradient-to-br from-teal-500/10 via-cyan-500/10 to-blue-500/10 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.28)] lg:p-12">
            <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
              <div className="max-w-2xl">
                <p className="text-sm font-semibold uppercase tracking-[0.35em] text-teal-300">Early access</p>
                <h2 className="mt-4 text-3xl font-semibold tracking-tight text-white sm:text-4xl">Start your transformation today.</h2>
                <p className="mt-4 text-lg leading-8 text-slate-300">
                  Join the waitlist for EleFit and be first to hear when the app opens for public access.
                </p>
              </div>
              <div className="flex flex-col gap-3 sm:flex-row">
                <CTAButton href="#top">Join Early Access</CTAButton>
                <CTAButton href="#app-experience" variant="secondary">
                  Explore the app <ArrowRight className="ml-2 h-4 w-4" />
                </CTAButton>
              </div>
            </div>
            <div className="mt-8 max-w-2xl">
              <EarlyAccessForm compact className="max-w-2xl" />
            </div>
          </div>
        </motion.section>
      </main>
      <Footer />
    </div>
  );
}
