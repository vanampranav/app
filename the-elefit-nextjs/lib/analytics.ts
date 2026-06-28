export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID || "";

export const isGaEnabled = Boolean(GA_MEASUREMENT_ID);

declare global {
  interface Window {
    gtag?: (command: string, target: string | number | undefined, config?: Record<string, unknown>) => void;
    dataLayer?: unknown[];
  }
}

export const trackPageView = (path: string) => {
  if (!isGaEnabled || typeof window === "undefined") return;

  window.gtag?.("config", GA_MEASUREMENT_ID, {
    page_path: path,
    page_title: document.title,
  });
};

export const trackEvent = (
  action: string,
  params?: Record<string, unknown>
) => {
  if (!isGaEnabled || typeof window === "undefined") return;

  window.gtag?.("event", action, params);
};

export const initGoogleAnalytics = () => {
  if (!isGaEnabled || typeof window === "undefined") return;

  const existingScript = document.querySelector(`script[src*="googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}"]`);
  if (existingScript) return;

  const script = document.createElement("script");
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`;
  document.head.appendChild(script);

  window.dataLayer = window.dataLayer || [];
  window.gtag = function gtag() {
    window.dataLayer?.push(arguments);
  };

  window.gtag("js", new Date().toISOString());
  window.gtag("config", GA_MEASUREMENT_ID, {
    send_page_view: false,
  });
};
