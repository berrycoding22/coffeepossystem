import type { Config } from "tailwindcss";

export default {
  darkMode: ["class"],
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: { espresso: "#4B2E2B", gold: "#C9A66B", cream: "#F8F5F0", ink: "#151515" },
      boxShadow: { soft: "0 12px 35px rgba(75,46,43,.08)" }
    }
  },
  plugins: []
} satisfies Config;
