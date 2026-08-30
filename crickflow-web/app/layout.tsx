import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { Plus_Jakarta_Sans } from "next/font/google";
import { AppProviders } from "@/components/providers";
import { Analytics } from "@/components/analytics";
import { SkipToContent } from "@/components/layout/skip-to-content";
import { SiteFooter, SiteHeader } from "@/components/layout/site-header";
import { siteConfig } from "@/config/site";
import "./globals.css";

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-plus-jakarta",
});

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#1565c0" },
    { media: "(prefers-color-scheme: dark)", color: "#42a5f5" },
  ],
  width: "device-width",
  initialScale: 1,
};

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: `${siteConfig.name} — ${siteConfig.tagline}`,
    template: `%s · ${siteConfig.name}`,
  },
  description: siteConfig.description,
  applicationName: siteConfig.name,
  manifest: "/manifest.webmanifest",
  icons: {
    icon: "/favicon.ico",
    apple: siteConfig.logoUrl,
  },
  appleWebApp: {
    capable: true,
    title: siteConfig.name,
    statusBarStyle: "default",
  },
  openGraph: {
    title: siteConfig.name,
    description: siteConfig.description,
    url: siteConfig.url,
    siteName: siteConfig.name,
    type: "website",
    images: [{ url: siteConfig.logoUrl, alt: siteConfig.name }],
  },
  twitter: {
    card: "summary_large_image",
    title: siteConfig.name,
    description: siteConfig.description,
    images: [siteConfig.logoUrl],
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en" className={`${plusJakarta.variable} h-full`} suppressHydrationWarning>
      <body className="flex min-h-full flex-col antialiased">
        <SkipToContent />
        <AppProviders>
          <SiteHeader />
          <main id="main" className="mx-auto w-full max-w-7xl flex-1 px-4 py-8">
            {children}
          </main>
          <SiteFooter />
          <Analytics />
        </AppProviders>
      </body>
    </html>
  );
}
