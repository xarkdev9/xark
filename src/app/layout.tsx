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

export const metadata: Metadata = {
  title: "XARK OS",
  description: "Privacy focussed group operating system",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "xark",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  themeColor: "#0A0A0A",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${syne.variable} ${inter.variable} font-syne`}>
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
