import { ArrowRight, Sparkles, TrendingUp, Users } from "lucide-react";
import { CTAButton } from "./CTAButton";
import { EarlyAccessForm } from "./EarlyAccessForm";
import { PhoneMockup } from "./PhoneMockup";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden px-4 pb-20 pt-10 sm:px-6 lg:px-8 lg:pt-16">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,_rgba(45,212,191,0.15),_transparent_45%),radial-gradient(circle_at_90%_20%,_rgba(59,130,246,0.18),_transparent_35%)]" />

      <div className="mx-auto grid max-w-7xl items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
        <div>
          <div className="inline-flex items-center gap-2 rounded-full border border-teal-400/20 bg-teal-400/10 px-3 py-2 text-sm text-teal-200">
            <Sparkles className="h-4 w-4" />
            AI-powered fitness, community-first accountability
          </div>

          <h1 className="mt-8 max-w-3xl text-5xl font-semibold leading-[0.95] tracking-[-0.03em] text-white sm:text-6xl lg:text-7xl">
            Transform Together. Stay Consistent for Life.
          </h1>

          <p className="mt-7 max-w-2xl text-lg leading-8 text-slate-300 sm:text-xl">
            Personalized AI coaching, transformation challenges, and a supportive community designed to help you finally stay consistent.
          </p>

          <div className="mt-10 flex flex-col gap-3 sm:flex-row">
            <CTAButton href="#early-access">Join Early Access</CTAButton>
            <CTAButton href="#app-experience" variant="secondary">
              Explore the App <ArrowRight className="ml-2 h-4 w-4" />
            </CTAButton>
          </div>

          <div className="mt-10">
            <EarlyAccessForm className="max-w-xl" />
          </div>

          <div className="mt-10 grid gap-4 sm:grid-cols-3">
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl">
              <div className="flex items-center gap-2 text-teal-300">
                <TrendingUp className="h-4 w-4" />
                <span className="text-sm font-semibold">Progress</span>
              </div>
              <p className="mt-2 text-sm text-slate-300">Weekly rhythm and body-composition insight.</p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl">
              <div className="flex items-center gap-2 text-cyan-300">
                <Users className="h-4 w-4" />
                <span className="text-sm font-semibold">Support</span>
              </div>
              <p className="mt-2 text-sm text-slate-300">Real accountability from your people.</p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl">
              <div className="flex items-center gap-2 text-blue-300">
                <Sparkles className="h-4 w-4" />
                <span className="text-sm font-semibold">AI Coach</span>
              </div>
              <p className="mt-2 text-sm text-slate-300">Actionable guidance every day.</p>
            </div>
          </div>
        </div>

        <div className="relative mx-auto w-full max-w-[480px]">
          <PhoneMockup imageSrc="/images/app-dashboard.png" alt="EleFit app dashboard preview" className="scale-[0.95]" />
          <div className="absolute -left-5 bottom-10 hidden rounded-2xl border border-white/12 bg-slate-950/80 p-4 shadow-[0_30px_80px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:block">
            <p className="text-sm font-semibold text-white">Weekly challenge</p>
            <p className="mt-1 text-sm text-slate-300">6 workouts • 3 meal logs • 1 check-in</p>
          </div>
          <div className="absolute -right-2 top-10 hidden rounded-2xl border border-teal-400/20 bg-gradient-to-br from-teal-400/15 to-blue-500/15 p-4 shadow-[0_30px_80px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:block">
            <p className="text-sm font-semibold text-white">Consistency score</p>
            <p className="mt-1 text-2xl font-semibold text-teal-300">92%</p>
          </div>
        </div>
      </div>
    </section>
  );
}
