import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "./providers";
import { Navbar } from "@/components/layout/Navbar";
import { Background } from "@/components/layout/Background";

export const metadata: Metadata = {
  title: "BC400 Token Portal | Bitcoin Cultivator 400",
  description: "Migrate, bridge, and manage your BC400 tokens across multiple chains. Secure multi-chain token portal with LayerZero cross-chain bridging.",
  keywords: ["BC400", "Bitcoin Cultivator", "token migration", "cross-chain bridge", "LayerZero", "OFT"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <Background />
          <div style={{ position: 'relative', zIndex: 1, minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
            <Navbar />
            <main style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
              {children}
            </main>
          </div>
        </Providers>
      </body>
    </html>
  );
}
