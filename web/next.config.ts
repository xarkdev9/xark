import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  turbopack: {
    root: ".",
  },
  serverExternalPackages: ["apify-client", "proxy-agent", "pac-proxy-agent", "socks-proxy-agent"],
  images: {
    remotePatterns: [
      { hostname: "images.unsplash.com" },
      { hostname: "firebasestorage.googleapis.com" },
    ],
  },
  async headers() {
    return [
      {
        source: "/s/:code*",
        headers: [
          { key: "Cache-Control", value: "no-store, max-age=0, must-revalidate" },
        ],
      },
    ];
  },
};

export default nextConfig;
