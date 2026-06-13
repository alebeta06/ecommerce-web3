import type { Metadata } from "next";
import "./globals.css";
import { WalletProvider } from "@/hooks/useWallet";
import { WalletConnect } from "@/components/WalletConnect";

// 🇪🇸 NOTA: layout raíz (App Router). Envolvemos toda la app en WalletProvider para que el estado
// de la wallet sea único y compartido (header + hooks). El header muestra el estado de conexión.
export const metadata: Metadata = {
  title: "web-admin",
  description: "Merchant back-office for the Web3 e-commerce (Component 5).",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-white text-gray-900 antialiased">
        <WalletProvider>
          <header className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
            <span className="text-lg font-semibold">web-admin</span>
            <WalletConnect />
          </header>
          {children}
        </WalletProvider>
      </body>
    </html>
  );
}
