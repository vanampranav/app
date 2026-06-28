"use client";

import { useEffect, useState } from "react";
import { addDoc, collection, getDocs, query, serverTimestamp, where } from "firebase/firestore";
import { CheckCircle2, Loader2, Mail } from "lucide-react";
import { usePathname } from "next/navigation";
import { trackEvent } from "@/lib/analytics";
import { getFirebaseDb } from "@/shared/firebase";

type EarlyAccessFormProps = {
  compact?: boolean;
  className?: string;
};

const storageKey = "elefit-waitlist-guard";

export function EarlyAccessForm({ compact = false, className = "" }: EarlyAccessFormProps) {
  const pathname = usePathname();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [message, setMessage] = useState("");
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    setIsReady(true);
  }, []);

  const normalizeEmail = (value: string) => value.trim().toLowerCase();

  const hasRecentSubmission = (value: string) => {
    if (typeof window === "undefined") return false;

    try {
      const raw = window.localStorage.getItem(storageKey);
      if (!raw) return false;

      const parsed = JSON.parse(raw) as { email?: string; timestamp?: number };
      if (!parsed?.email || !parsed.timestamp) return false;

      const isSameEmail = parsed.email === value;
      const isRecent = Date.now() - parsed.timestamp < 1000 * 60 * 5;
      return isSameEmail && isRecent;
    } catch {
      return false;
    }
  };

  const persistSubmission = (value: string) => {
    if (typeof window === "undefined") return;

    window.localStorage.setItem(
      storageKey,
      JSON.stringify({ email: value, timestamp: Date.now() })
    );
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (status === "loading") return;

    const trimmedName = name.trim();
    const normalizedEmail = normalizeEmail(email);

    trackEvent("waitlist_form_submit", {
      page_path: pathname || "/",
      source: "landing-page",
    });

    if (!normalizedEmail) {
      setStatus("error");
      setMessage("Please enter your email address.");
      trackEvent("waitlist_form_error", {
        reason: "missing_email",
        page_path: pathname || "/",
      });
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      setStatus("error");
      setMessage("Please enter a valid email address.");
      trackEvent("waitlist_form_error", {
        reason: "invalid_email",
        page_path: pathname || "/",
      });
      return;
    }

    if (hasRecentSubmission(normalizedEmail)) {
      setStatus("success");
      setMessage("Thanks! We already received your email and will be in touch soon.");
      trackEvent("waitlist_form_success", {
        result: "duplicate_guard",
        page_path: pathname || "/",
      });
      return;
    }

    setStatus("loading");
    setMessage("");

    try {
      const db = getFirebaseDb();
      if (!db) {
        throw new Error("Firebase is not configured for waitlist submissions yet.");
      }

      const existingQuery = query(collection(db, "earlyAccessLeads"), where("email", "==", normalizedEmail));
      const existingSnapshot = await getDocs(existingQuery);

      if (!existingSnapshot.empty) {
        persistSubmission(normalizedEmail);
        setStatus("success");
        setMessage("Thanks! We already have your email on the list.");
        setEmail("");
        setName("");
        trackEvent("waitlist_form_success", {
          result: "existing_lead",
          page_path: pathname || "/",
        });
        return;
      }

      await addDoc(collection(db, "earlyAccessLeads"), {
        name: trimmedName || null,
        email: normalizedEmail,
        source: "landing-page",
        pagePath: pathname || "/",
        createdAt: serverTimestamp(),
      });

      persistSubmission(normalizedEmail);
      setStatus("success");
      setMessage("You’re on the list. We’ll share early access soon.");
      setEmail("");
      setName("");
      trackEvent("waitlist_form_success", {
        result: "new_lead",
        page_path: pathname || "/",
      });
    } catch (error) {
      console.error("Early access submission failed", error);
      setStatus("error");
      setMessage(error instanceof Error ? error.message : "Something went wrong. Please try again.");
      trackEvent("waitlist_form_error", {
        reason: "submission_failed",
        page_path: pathname || "/",
      });
    }
  };

  return (
    <div className={`rounded-[1.75rem] border border-white/10 bg-slate-950/70 p-5 shadow-[0_20px_80px_rgba(0,0,0,0.25)] backdrop-blur-xl ${className}`}>
      <div className="flex items-center gap-2 text-sm font-semibold text-teal-300">
        <Mail className="h-4 w-4" />
        Early access waitlist
      </div>
      <p className="mt-3 text-sm leading-7 text-slate-300">
        {compact
          ? "Get first access to the EleFit app and launch updates."
          : "Join the waitlist to get first access to EleFit and the next launch updates."}
      </p>

      <form onSubmit={handleSubmit} className="mt-5 space-y-3">
        <input
          type="text"
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Your name (optional)"
          className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none transition focus:border-teal-400/50"
        />
        <input
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="Email address"
          required
          className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none transition focus:border-teal-400/50"
        />

        <button
          type="submit"
          disabled={status === "loading" || !isReady}
          className="flex w-full items-center justify-center gap-2 rounded-full bg-gradient-to-r from-teal-400 via-cyan-400 to-blue-500 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-70"
        >
          {status === "loading" ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Joining waitlist...
            </>
          ) : (
            <>Join the waitlist</>
          )}
        </button>
      </form>

      {message ? (
        <div
          className={`mt-4 flex items-start gap-2 rounded-2xl border px-3 py-3 text-sm ${
            status === "success"
              ? "border-emerald-400/20 bg-emerald-400/10 text-emerald-200"
              : "border-rose-400/20 bg-rose-400/10 text-rose-200"
          }`}
        >
          {status === "success" ? <CheckCircle2 className="mt-0.5 h-4 w-4" /> : <Mail className="mt-0.5 h-4 w-4" />}
          <span>{message}</span>
        </div>
      ) : null}
    </div>
  );
}
