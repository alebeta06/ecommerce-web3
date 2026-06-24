import type { Metadata } from "next";
import "./globals.css";
import { WalletProvider } from "@/hooks/useWallet";

// 🇪🇸 NOTA: layout raíz. Envolvemos en WalletProvider para que useWallet comparta un único estado.
// El header solo muestra el título; conectar wallet y pagar viven en la página (dos columnas).
export const metadata: Metadata = {
  title: "compra-stablecoin",
  description:
    "Buy the EUR-pegged stablecoin (EURT) with a credit card via Stripe (Component 2).",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">
        <WalletProvider>
          <header className="flex items-center justify-between border-b border-line bg-sidebar px-6 py-4">
            <span className="text-lg font-semibold text-fg">compra-stablecoin</span>
          </header>
          <main>{children}</main>
        </WalletProvider>
      </body>
    </html>
  );
}
