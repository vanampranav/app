"use client";

import { motion, useReducedMotion } from "framer-motion";
import Image from "next/image";
import {
  ArrowRight,
  BrainCircuit,
  CheckCircle2,
  Compass,
  MessageCircleHeart,
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

// progressPoints removed; replaced by focused "Progress and Feedback" chips in the section

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
  const prefersReducedMotion = useReducedMotion();

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
          className="px-4 py-10 sm:px-6 lg:px-8 lg:py-14"
        >
          <div className="mx-auto flex min-h-[calc(100svh-6rem)] max-w-7xl flex-col justify-center rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-slate-950/95 via-[#071221]/90 to-[#09192a]/90 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.3)] lg:p-12">
            <div className="grid gap-10 lg:grid-cols-[1.02fr_0.98fr] lg:items-center">
              <div className="max-w-2xl">
                <p className="text-sm font-medium uppercase tracking-[0.32em] text-teal-200">The reality</p>
                <h2 className="mt-4 text-4xl font-semibold leading-[0.95] tracking-[-0.03em] text-white sm:text-5xl lg:text-6xl">
                  Most health plans break because life breaks first.
                </h2>
                <p className="mt-6 max-w-xl text-lg leading-8 text-slate-300 sm:text-xl">
                  When work shifts, the kids need you, and energy gets thin, motivation alone is not enough. What people need is a system that can bend without breaking.
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  {[
                    "Busy calendars",
                    "Unpredictable days",
                    "No guilt, just rhythm",
                  ].map((point) => (
                    <div key={point} className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300 backdrop-blur-xl">
                      {point}
                    </div>
                  ))}
                </div>
              </div>

              <div className="rounded-[2rem] border border-white/10 bg-white/5 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] backdrop-blur-xl">
                <div className="space-y-4">
                  {[
                    {
                      title: "Morning rush",
                      copy: "The day starts before you have a minute to breathe.",
                    },
                    {
                      title: "Midday reset",
                      copy: "A small pause can make the rest of the day feel manageable.",
                    },
                    {
                      title: "Evening recovery",
                      copy: "Real health is built in the quiet moments, not just the hard ones.",
                    },
                  ].map((item) => (
                    <div key={item.title} className="rounded-[1.25rem] border border-white/10 bg-slate-950/60 p-5">
                      <p className="text-sm font-semibold text-white">{item.title}</p>
                      <p className="mt-2 text-sm leading-7 text-slate-300">{item.copy}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </motion.section>

        <motion.section
          id="better-systems"
          initial={prefersReducedMotion ? false : { opacity: 0, y: 24 }}
          whileInView={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: prefersReducedMotion ? 0 : 0.6 }}
          className="px-4 py-10 sm:px-6 lg:px-8 lg:py-14"
        >
          <div className="mx-auto flex min-h-[calc(100svh-6rem)] max-w-7xl flex-col justify-center rounded-[2.5rem] border border-white/10 bg-[radial-gradient(circle_at_top_left,_rgba(45,212,191,0.14),_transparent_38%),linear-gradient(135deg,_rgba(3,10,24,0.98),_rgba(7,17,33,0.92)_55%,_rgba(12,24,42,0.9))] p-8 shadow-[0_30px_120px_rgba(0,0,0,0.28)] lg:p-12">
            <div className="grid gap-10 lg:grid-cols-[0.95fr_1.05fr] lg:items-center">
              <div className="max-w-2xl">
                <p className="text-sm font-medium uppercase tracking-[0.32em] text-teal-200">Better systems matter</p>
                <h2 className="mt-4 text-4xl font-semibold leading-[0.95] tracking-[-0.03em] text-white sm:text-5xl lg:text-6xl">
                  Health feels easier when the system is built for your life.
                </h2>
                <p className="mt-6 max-w-xl text-lg leading-8 text-slate-300 sm:text-xl">
                  EleFit is not about doing more. It is about creating a rhythm that is realistic, sustainable, and supportive enough to last beyond a good week.
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  {[
                    "Designed around real routines",
                    "Flexible enough to adapt",
                    "Calm enough to maintain",
                  ].map((point) => (
                    <div key={point} className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300 backdrop-blur-xl">
                      {point}
                    </div>
                  ))}
                </div>
              </div>

              <motion.div
                initial={prefersReducedMotion ? false : { opacity: 0, x: 24 }}
                whileInView={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, x: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: prefersReducedMotion ? 0 : 0.7, delay: prefersReducedMotion ? 0 : 0.08 }}
                className="rounded-[2rem] border border-white/10 bg-slate-950/70 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)] backdrop-blur-xl"
              >
                <div className="grid gap-4 md:grid-cols-2">
                  <div className="rounded-[1.25rem] border border-rose-400/20 bg-rose-500/10 p-5">
                    <p className="text-sm font-semibold uppercase tracking-[0.28em] text-rose-200">Before</p>
                    <p className="mt-3 text-lg leading-7 text-slate-100">
                      Too many decisions. Too much friction. Too much guilt when life changes.
                    </p>
                  </div>

                  <div className="rounded-[1.25rem] border border-teal-400/20 bg-teal-400/10 p-5">
                    <p className="text-sm font-semibold uppercase tracking-[0.28em] text-teal-200">After</p>
                    <p className="mt-3 text-lg leading-7 text-slate-100">
                      A rhythm that bends without breaking and feels simple to return to.
                    </p>
                  </div>
                </div>

                <div className="mt-4 rounded-[1.25rem] border border-white/10 bg-white/5 p-5">
                  <div className="flex flex-wrap gap-3">
                    {[
                      "Plan once",
                      "Adjust gently",
                      "Stay steady",
                    ].map((step) => (
                      <div key={step} className="rounded-full border border-white/10 bg-slate-900/70 px-3 py-2 text-sm text-slate-300">
                        {step}
                      </div>
                    ))}
                  </div>
                  <p className="mt-4 text-sm leading-7 text-slate-300">
                    The goal is not perfection. It is a system that feels calm enough to come back to after a hard day.
                  </p>
                </div>
              </motion.div>
            </div>
          </div>
        </motion.section>

        <motion.section
          id="founder-story"
          initial={prefersReducedMotion ? false : { opacity: 0, y: 24 }}
          whileInView={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: prefersReducedMotion ? 0 : 0.6 }}
          className="px-4 py-16 sm:px-6 lg:px-8"
        >
          <div className="mx-auto flex min-h-[calc(100svh-6rem)] max-w-7xl items-center rounded-[2rem] border border-white/8 bg-gradient-to-br from-[#031018]/90 to-[#071421]/90 p-6 lg:p-12">
            <div className="grid w-full items-center gap-8 lg:grid-cols-2">
              <div className="order-1 lg:order-1">
                <div className="relative h-[360px] w-full rounded-[1.5rem] overflow-hidden shadow-[0_30px_80px_rgba(0,0,0,0.5)] sm:h-[420px] lg:h-[520px]">
                  <Image
                    src="/images/founder.jpg"
                    alt="Founder and family"
                    fill
                    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 520px"
                    className="object-cover"
                    priority
                  />
                </div>
              </div>

              <motion.div
                initial={prefersReducedMotion ? false : { opacity: 0, x: 18 }}
                whileInView={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, x: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: prefersReducedMotion ? 0 : 0.7, delay: prefersReducedMotion ? 0 : 0.06 }}
                className="order-2 max-w-2xl lg:order-2"
              >
                <p className="text-sm font-medium uppercase tracking-[0.32em] text-teal-200">Why EleFit exists</p>
                <h2 className="mt-4 text-3xl font-semibold leading-[1.02] tracking-[-0.02em] text-white sm:text-4xl lg:text-5xl">
                  Built from the reality of everyday life.
                </h2>

                <div className="mt-6 space-y-4 text-lg leading-7 text-slate-300">
                  <p>
                    Parenthood changed everything. Careers grew. Responsibilities multiplied. Health slowly moved to the bottom of the list.
                  </p>
                  <p>
                    We realized that if we did not take care of ourselves, we could not show up as the parents, partners, and people we wanted to become.
                  </p>
                  <p>
                    EleFit was born from that realization — to help busy people build health systems that fit real life.
                  </p>
                </div>

                <div className="mt-8 flex flex-wrap gap-3">
                  {[
                    "Built from lived experience",
                    "Created for busy families",
                    "Designed around real routines",
                  ].map((chip) => (
                    <div key={chip} className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300 backdrop-blur-xl">
                      {chip}
                    </div>
                  ))}
                </div>
              </motion.div>
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
              {howItWorks.map((item) => (
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
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-[#07111f] to-slate-900/90 p-8 shadow-[0_30px_120px_rgba(0,0,0,0.24)] lg:grid-cols-[0.95fr_1.05fr] lg:p-12 items-center">
            <div className="order-2 lg:order-1">
              <SectionHeader
                eyebrow="Community & Accountability"
                title="Progress feels easier when you're not carrying it alone."
                description="A warm, human place to share wins, ask for help, and keep moving together — built around relationships, not metrics."
              />

              <div className="mt-6 max-w-xl text-lg leading-7 text-slate-300">
                <p>
                  EleFit brings you into small circles that fit your life — friends, partners, or a coach — so weekly progress feels shared and sustainable.
                </p>
              </div>

              <ul className="mt-8 space-y-4">
                {communityPoints.map((point) => (
                  <li key={point} className="flex items-start gap-3 text-slate-300">
                    <MessageCircleHeart className="mt-0.5 h-5 w-5 flex-none text-cyan-300" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div className="order-1 lg:order-2">
              <PhoneMockup imageSrc="/images/community.jpg" alt="EleFit community experience" />
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
          <div className="mx-auto grid max-w-7xl gap-10 rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-[#061018] to-[#0b1728] p-8 shadow-[0_30px_120px_rgba(0,0,0,0.24)] lg:grid-cols-[0.95fr_1.05fr] lg:p-12 items-center">
            <div className="max-w-xl">
              <SectionHeader
                eyebrow="Progress"
                title="Better insight creates better consistency."
                description="When people can clearly see their habits, trends, and momentum, they feel more grounded and more likely to keep going. Progress becomes encouraging instead of confusing."
              />

              <div className="mt-6 space-y-4 text-lg leading-7 text-slate-300">
                <p>
                  A calm view of your routine and momentum — not a dense dashboard, but gentle clarity that helps you make better choices.
                </p>
              </div>

              <div className="mt-8 flex flex-wrap gap-3">
                {[
                  "Clear visibility into your routine",
                  "A better view of momentum over time",
                  "Support that helps you adjust with ease",
                ].map((chip) => (
                  <div key={chip} className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300 backdrop-blur-xl">
                    {chip}
                  </div>
                ))}
              </div>
            </div>

            <div>
              <div className="rounded-[1.75rem] border border-white/8 bg-slate-950/60 p-6 shadow-[0_20px_80px_rgba(0,0,0,0.35)]">
                <div className="flex items-center justify-between gap-4">
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-teal-200">Weekly momentum</p>
                    <p className="mt-2 text-sm text-slate-300">Simple trends that show whether your habits are improving week over week.</p>
                  </div>

                  <div className="ml-4 h-20 w-44">
                    <svg viewBox="0 0 220 80" fill="none" xmlns="http://www.w3.org/2000/svg" className="h-full w-full" aria-hidden>
                      <defs>
                        <linearGradient id="g" x1="0" x2="1">
                          <stop offset="0%" stopColor="#06b6d4" stopOpacity="0.9" />
                          <stop offset="100%" stopColor="#60a5fa" stopOpacity="0.9" />
                        </linearGradient>
                      </defs>
                      <rect width="220" height="80" rx="10" fill="rgba(255,255,255,0.02)"/>
                      <path d="M10 55 C40 40, 70 30, 100 35 C130 40, 160 28, 190 22" stroke="url(#g)" strokeWidth="4" strokeLinecap="round" fill="none" opacity="0.95"/>
                      <circle cx="190" cy="22" r="3.5" fill="#60a5fa" />
                    </svg>
                  </div>
                </div>
              </div>
            </div>
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
