import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  serverExternalPackages: ["apify-client", "proxy-agent", "pac-proxy-agent", "socks-proxy-agent"],
};

export default nextConfig;
