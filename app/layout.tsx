import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://meinkrypto.info"),
  title: {
    default: "meinKrypto.info | Kryptowerte verstehen",
    template: "%s | meinKrypto.info",
  },
  description:
    "Aktuelle Einordnungen, Marktdaten und Kundenveranstaltungen zu Bitcoin, Ethereum, Cardano und Litecoin.",
  keywords: [
    "Bitcoin",
    "Ethereum",
    "Cardano",
    "Litecoin",
    "meinKrypto",
    "Kundenveranstaltung",
    "Kryptowerte",
  ],
  openGraph: {
    title: "meinKrypto.info | Krypto, klarer betrachtet.",
    description:
      "Fundierte Einordnungen, Analysen und Veranstaltungsformate rund um Kryptowerte.",
    url: "https://meinkrypto.info",
    siteName: "meinKrypto.info",
    locale: "de_DE",
    type: "website",
  },
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/assets/logo.png",
    shortcut: "/assets/logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="de">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
