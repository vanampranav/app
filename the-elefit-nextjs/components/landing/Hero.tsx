"use client";

import { ArrowRight, Sparkles } from "lucide-react";
import { motion, useReducedMotion } from "framer-motion";
import { CTAButton } from "./CTAButton";
import { PhoneMockup } from "./PhoneMockup";

const supportingPoints = [
  "Built for busy professionals and parents",
  "Gentle guidance that fits real routines",
  "Support that helps you stay consistent",
];

export function Hero() {
  const prefersReducedMotion = useReducedMotion();

  return (
    <section id="top" className="relative isolate overflow-hidden px-4 pb-10 pt-8 sm:px-6 sm:pb-16 sm:pt-10 lg:px-8 lg:pb-24 lg:pt-16">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,_rgba(45,212,191,0.16),_transparent_45%),radial-gradient(circle_at_88%_12%,_rgba(59,130,246,0.16),_transparent_35%)]" />
      <div className="absolute left-1/2 top-0 h-[34rem] w-[34rem] -translate-x-1/2 rounded-full bg-teal-400/10 blur-3xl" />

      <div className="mx-auto flex min-h-[calc(100svh-4rem)] max-w-7xl flex-col justify-center gap-10 sm:gap-12 lg:grid lg:grid-cols-[1.02fr_0.98fr] lg:items-center lg:gap-14">
        <motion.div
          initial={prefersReducedMotion ? false : { opacity: 0, y: 22 }}
          animate={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, y: 0 }}
          transition={{ duration: prefersReducedMotion ? 0 : 0.7, ease: "easeOut" }}
          className="max-w-2xl"
        >
          <div className="inline-flex items-center gap-2 rounded-full border border-teal-400/20 bg-teal-400/10 px-3 py-2 text-sm text-teal-200 backdrop-blur-xl">
            <Sparkles className="h-4 w-4" />
            EleFit for real life
          </div>

          <h1 className="mt-5 text-4xl font-semibold leading-[0.94] tracking-[-0.03em] text-white sm:mt-7 sm:text-5xl lg:text-7xl">
            Health that fits the life you already have.
          </h1>

          <p className="mt-4 max-w-xl text-base leading-7 text-slate-200 sm:mt-6 sm:text-lg sm:leading-8 lg:text-xl">
            EleFit brings calm structure to meals, movement, and momentum so healthy habits feel sustainable, not overwhelming.
          </p>

          <div className="mt-6 flex flex-col gap-3 sm:mt-8 sm:flex-row">
            <CTAButton href="#early-access">Join Early Access</CTAButton>
            <CTAButton href="#problem" variant="secondary">
              See the story <ArrowRight className="ml-2 h-4 w-4" />
            </CTAButton>
          </div>

          <div className="mt-6 flex flex-wrap gap-2 sm:mt-8">
            {supportingPoints.map((point) => (
              <span key={point} className="rounded-full border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-300 backdrop-blur-xl">
                {point}
              </span>
            ))}
          </div>
        </motion.div>

        <motion.div
          initial={prefersReducedMotion ? false : { opacity: 0, y: 28 }}
          animate={prefersReducedMotion ? { opacity: 1 } : { opacity: 1, y: 0 }}
          transition={{ duration: prefersReducedMotion ? 0 : 0.8, delay: prefersReducedMotion ? 0 : 0.1, ease: "easeOut" }}
          className="relative mx-auto w-full max-w-[500px]"
        >
          <div className="absolute inset-0 rounded-[2.25rem] bg-gradient-to-br from-teal-400/20 via-transparent to-blue-500/15 blur-3xl" />
          <PhoneMockup imageSrc="/images/app-dashboard.png" alt="EleFit app dashboard preview" className="relative scale-[0.95]" />

          <div className="absolute -left-3 bottom-10 hidden rounded-2xl border border-white/10 bg-slate-950/80 p-4 shadow-[0_30px_80px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:block">
            <p className="text-sm font-semibold text-white">A calmer rhythm</p>
            <p className="mt-1 text-sm text-slate-300">Meals • movement • recovery</p>
          </div>

          <div className="absolute -right-2 top-8 hidden rounded-2xl border border-teal-400/20 bg-gradient-to-br from-teal-400/15 to-blue-500/15 p-4 shadow-[0_30px_80px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:block">
            <p className="text-sm font-semibold text-white">Consistency score</p>
            <p className="mt-1 text-2xl font-semibold text-teal-300">92%</p>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
