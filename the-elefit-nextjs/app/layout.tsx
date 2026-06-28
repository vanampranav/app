import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { AnalyticsProvider } from "@/components/AnalyticsProvider";
import { Providers } from "@/components/Providers";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "EleFit App | AI Fitness Coach, Challenges & Community",
  description:
    "EleFit helps you stay consistent with AI-powered fitness coaching, transformation challenges, smart tracking, and community accountability.",
  icons: {
    icon: "/logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.className} antialiased`} suppressHydrationWarning>
        <AnalyticsProvider>
          <Providers>{children}</Providers>
        </AnalyticsProvider>
      </body>
    </html>
  );
}
