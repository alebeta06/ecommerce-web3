import type { Metadata } from "next";
import "./globals.css";

// 🇪🇸 NOTA: layout raíz (App Router), minimal. Esta app compra EURT con tarjeta (Stripe) y mintea
// on-chain. El header solo muestra el título; la conexión de wallet y el flujo de pago viven en la
// página (dos columnas). El WalletProvider se añadirá junto con los hooks en el siguiente commit.
export const metadata: Metadata = {
  title: "compra-stablecoin",
  description:
    "Buy the EUR-pegged stablecoin (EURT) with a credit card via Stripe (Component 2).",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">
        <header className="flex items-center justify-between border-b border-line bg-sidebar px-6 py-4">
          <span className="text-lg font-semibold text-fg">compra-stablecoin</span>
        </header>
        <main>{children}</main>
      </body>
    </html>
  );
}
