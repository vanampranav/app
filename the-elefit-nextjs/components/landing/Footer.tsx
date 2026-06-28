import Link from "next/link";

export function Footer() {
  return (
    <footer className="border-t border-white/10 bg-[#03060f] px-4 py-10 sm:px-6 lg:px-8">
      <div className="mx-auto flex max-w-7xl flex-col gap-6 rounded-[2rem] border border-white/10 bg-white/5 px-6 py-8 shadow-[0_20px_80px_rgba(0,0,0,0.2)] backdrop-blur-xl md:flex-row md:items-center md:justify-between">
        <div>
          <p className="text-lg font-semibold text-white">EleFit</p>
          <p className="mt-2 max-w-lg text-sm leading-7 text-slate-400">
            A community-first fitness platform blending AI coaching, accountability, and transformation challenges.
          </p>
        </div>

        <div className="flex flex-wrap gap-5 text-sm text-slate-400">
          <Link href="#how-it-works" className="transition hover:text-white">
            How it works
          </Link>
          <Link href="#community" className="transition hover:text-white">
            Community
          </Link>
          <Link href="#early-access" className="transition hover:text-white">
            Early access
          </Link>
        </div>
      </div>
    </footer>
  );
}
