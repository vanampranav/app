import Link from "next/link";
import { CTAButton } from "./CTAButton";

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-[#050816]/70 px-4 py-4 backdrop-blur-2xl sm:px-6 lg:px-8">
      <div className="mx-auto flex max-w-7xl items-center justify-between rounded-full border border-white/10 bg-slate-950/70 px-4 py-3 shadow-[0_20px_70px_rgba(0,0,0,0.3)] backdrop-blur-xl">
        <Link href="#top" className="flex items-center gap-3 text-sm font-semibold text-white">
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-teal-400 to-blue-500 text-base font-bold text-slate-950">
            E
          </span>
          <span className="text-lg tracking-[0.2em]">ELEFIT</span>
        </Link>

        <nav className="hidden items-center gap-7 text-sm text-slate-300 md:flex">
          <Link href="#how-it-works" className="transition hover:text-white">
            How it works
          </Link>
          <Link href="#community" className="transition hover:text-white">
            Community
          </Link>
          <Link href="#progress" className="transition hover:text-white">
            Progress
          </Link>
        </nav>

        <div className="flex items-center gap-3">
          <CTAButton href="#early-access" variant="secondary" className="hidden sm:inline-flex">
            Explore the App
          </CTAButton>
          <CTAButton href="#early-access">Join Early Access</CTAButton>
        </div>
      </div>
    </header>
  );
}
