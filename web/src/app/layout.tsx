import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";
import { SITE } from "@/lib/config";

// Gövde fontu (humanist sans)
const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-jakarta",
  display: "swap",
});

// Başlık fontu: Korolev (self-hosted, web/public/fonts). Başlıklarda 700 ve 900 kullanılıyor.
const korolev = localFont({
  src: [
    { path: "../../public/fonts/Korolev Medium.otf", weight: "500", style: "normal" },
    { path: "../../public/fonts/Korolev Bold.otf", weight: "700", style: "normal" },
    { path: "../../public/fonts/Korolev Heavy.otf", weight: "900", style: "normal" },
  ],
  variable: "--font-korolev",
  display: "swap",
  fallback: ["Arial Black", "system-ui", "sans-serif"],
});

export const metadata: Metadata = {
  title: {
    default: `${SITE.name} — ${SITE.tagline}`,
    template: `%s · ${SITE.name}`,
  },
  description: SITE.description,
  metadataBase: new URL("https://bitirgitsin.com"),
  openGraph: {
    title: `${SITE.name} — ${SITE.tagline}`,
    description: SITE.description,
    type: "website",
    locale: "tr_TR",
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="tr" className={`${jakarta.variable} ${korolev.variable}`}>
      <body className="font-sans antialiased text-ink">{children}</body>
    </html>
  );
}
