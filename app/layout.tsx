import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Bejuco — Descarga la app",
  description:
    "Comunicación cuando la red cae. Bejuco detecta sismos vía USGS y transmite tu ubicación por malla Bluetooth, sin necesidad de internet.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es" className={inter.variable}>
      <body className="bg-white font-sans text-ink antialiased">
        {children}
      </body>
    </html>
  );
}
