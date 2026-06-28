import type { ReactNode } from "react";

type FeatureCardProps = {
  title: string;
  description: string;
  icon: ReactNode;
  accent?: string;
};

export function FeatureCard({ title, description, icon, accent = "from-teal-400/20 to-cyan-500/20" }: FeatureCardProps) {
  return (
    <div className="group rounded-[1.75rem] border border-white/10 bg-white/5 p-6 shadow-[0_20px_80px_rgba(0,0,0,0.25)] backdrop-blur-xl transition-all duration-300 hover:-translate-y-1 hover:border-teal-400/30 hover:bg-white/8">
      <div className={`mb-4 inline-flex rounded-2xl bg-gradient-to-br ${accent} p-3 text-teal-300`}>
        {icon}
      </div>
      <h3 className="text-xl font-semibold text-white">{title}</h3>
      <p className="mt-3 text-sm leading-7 text-slate-300">{description}</p>
    </div>
  );
}
