import Link from "next/link";
import type { ReactNode } from "react";
import { trackEvent } from "@/lib/analytics";

type CTAButtonProps = {
  href: string;
  children: ReactNode;
  variant?: "primary" | "secondary";
  className?: string;
};

export function CTAButton({ href, children, variant = "primary", className = "" }: CTAButtonProps) {
  const baseClasses =
    "inline-flex items-center justify-center rounded-full px-5 py-3 text-sm font-semibold transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-teal-400/70 focus:ring-offset-2 focus:ring-offset-[#050816]";

  const variants = {
    primary: "bg-gradient-to-r from-teal-400 via-cyan-400 to-blue-500 text-slate-950 shadow-[0_0_40px_rgba(45,212,191,0.2)] hover:-translate-y-0.5 hover:shadow-[0_0_50px_rgba(45,212,191,0.3)]",
    secondary:
      "border border-white/15 bg-white/5 text-white/90 backdrop-blur-xl hover:border-teal-400/40 hover:bg-white/10",
  };

  const handleClick = () => {
    trackEvent("early_access_cta_click", {
      destination: href,
      variant,
    });
  };

  return (
    <Link href={href} className={`${baseClasses} ${variants[variant]} ${className}`} onClick={handleClick}>
      {children}
    </Link>
  );
}
