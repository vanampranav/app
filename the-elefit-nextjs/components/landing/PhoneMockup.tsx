import Image from "next/image";

type PhoneMockupProps = {
  imageSrc: string;
  alt: string;
  className?: string;
};

export function PhoneMockup({ imageSrc, alt, className = "" }: PhoneMockupProps) {
  return (
    <div className={`relative mx-auto w-full max-w-[320px] ${className}`}>
      <div className="absolute inset-0 -translate-x-4 translate-y-4 rounded-[2.5rem] bg-gradient-to-br from-teal-400/20 via-cyan-400/10 to-blue-500/20 blur-3xl" />
      <div className="relative rounded-[2.5rem] border border-white/12 bg-slate-950/95 p-3 shadow-[0_30px_100px_rgba(0,0,0,0.45)]">
        <div className="rounded-[2rem] border border-white/10 bg-slate-900/90 p-2">
          <div className="mb-3 flex items-center justify-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-rose-400" />
            <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
            <span className="h-2.5 w-2.5 rounded-full bg-emerald-400" />
          </div>
          <div className="overflow-hidden rounded-[1.4rem] border border-white/10">
            <Image src={imageSrc} alt={alt} width={640} height={1200} className="h-auto w-full object-cover" />
          </div>
        </div>
      </div>
    </div>
  );
}
