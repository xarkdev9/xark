import type { Metadata, Viewport } from "next";
import { Syne, Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/components/os/ThemeProvider";
import { GlobalCaret } from "@/components/os/GlobalCaret";
import { GlobalUserMenu } from "@/components/os/GlobalUserMenu";
import { ServiceWorkerRegistration } from "@/components/os/ServiceWorkerRegistration";

const syne = Syne({
  variable: "--font-syne",
  subsets: ["latin"],
  weight: "variable",
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: "variable",
});

// Force dynamic rendering for ALL pages — required for CSP nonce injection.
// Static pages are pre-built without nonces → CSP blocks all JS → blank page.
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "XARK OS",
  description: "Privacy focussed group operating system",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "xark",
    startupImage: [
      // iPhone 15 Pro Max / 16 Pro Max (1290×2796)
      { url: "/splash/splash-1290x2796.png", media: "(device-width: 430px) and (device-height: 932px) and (-webkit-device-pixel-ratio: 3)" },
      // iPhone 15 Pro / 16 Pro (1179×2556)
      { url: "/splash/splash-1179x2556.png", media: "(device-width: 393px) and (device-height: 852px) and (-webkit-device-pixel-ratio: 3)" },
      // iPhone 14/15/16 (1170×2532)
      { url: "/splash/splash-1170x2532.png", media: "(device-width: 390px) and (device-height: 844px) and (-webkit-device-pixel-ratio: 3)" },
      // iPhone SE 3 (750×1334)
      { url: "/splash/splash-750x1334.png", media: "(device-width: 375px) and (device-height: 667px) and (-webkit-device-pixel-ratio: 2)" },
    ],
  },
  icons: [
    { rel: "apple-touch-icon", url: "/apple-touch-icon.png", sizes: "180x180" },
  ],
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  // themeColor removed — ThemeProvider sets it dynamically per theme
  colorScheme: "light",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${syne.variable} ${inter.variable}`}>
        <ThemeProvider>
          {children}
          <GlobalUserMenu />
          <GlobalCaret />
          <ServiceWorkerRegistration />
        </ThemeProvider>
      </body>
    </html>
  );
}
