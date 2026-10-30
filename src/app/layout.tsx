import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from "sonner";
import { LanguageProvider } from "@/components/providers/language-provider";
import { AutoTranslator } from "@/components/providers/auto-translator";

export const metadata: Metadata = { title: "CoffeeFlow POS", description: "Premium coffee shop point of sale" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body><LanguageProvider><AutoTranslator/><Toaster richColors position="top-right" />{children}</LanguageProvider></body></html>;
}
