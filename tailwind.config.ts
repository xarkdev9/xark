import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/**/*.{ts,tsx}",
  ],
  theme: {
    fontWeight: {
      // NO-BOLD MANDATE: Only 300 and 400 permitted.
      // Weights 500+ are BANNED per Constitution.
      light: "300",
      normal: "400",
    },
    extend: {
      colors: {
        amber: { DEFAULT: "#F5A623" },
        gold: { DEFAULT: "#FFD700" },
        green: { DEFAULT: "#10B981" },
        cyan: { DEFAULT: "#40E0FF" },
        "cloud-dancer": "#F0EEE9",
      },
      fontFamily: {
        syne: ["var(--font-syne)", "sans-serif"],
      },
      animation: {
        "ambient-breath": "ambientBreath 4.5s ease-in-out infinite",
      },
      keyframes: {
        ambientBreath: {
          "0%, 100%": { opacity: "0.4" },
          "50%": { opacity: "1" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
