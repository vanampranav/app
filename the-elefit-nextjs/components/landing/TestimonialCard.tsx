type TestimonialCardProps = {
  quote: string;
  name: string;
  role: string;
};

export function TestimonialCard({ quote, name, role }: TestimonialCardProps) {
  return (
    <div className="rounded-[1.75rem] border border-white/10 bg-white/5 p-7 shadow-[0_20px_80px_rgba(0,0,0,0.2)] backdrop-blur-xl">
      <p className="text-lg leading-8 text-slate-200">“{quote}”</p>
      <div className="mt-6">
        <p className="font-semibold text-white">{name}</p>
        <p className="text-sm text-slate-400">{role}</p>
      </div>
    </div>
  );
}
