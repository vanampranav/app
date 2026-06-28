"use client";

import { Suspense, useEffect } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { initGoogleAnalytics, trackPageView, GA_MEASUREMENT_ID } from "@/lib/analytics";

function AnalyticsClient({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    initGoogleAnalytics();
  }, []);

  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const url = `${pathname}${searchParams?.toString() ? `?${searchParams.toString()}` : ""}`;
    trackPageView(url);
  }, [pathname, searchParams]);

  return <>{children}</>;
}

export function AnalyticsProvider({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={null}>
      <AnalyticsClient>{children}</AnalyticsClient>
    </Suspense>
  );
}
