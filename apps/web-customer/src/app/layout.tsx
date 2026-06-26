import type { Metadata } from "next";
import "./globals.css";
import { WalletProvider } from "@/hooks/useWallet";
import { WalletConnect } from "@/components/WalletConnect";
import { NavLinks } from "@/components/NavLinks";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: layout raíz (App Router). Envolvemos toda la app en WalletProvider para que el estado
// de la wallet sea único y compartido (header + hooks). El header muestra el estado de conexión.
// A diferencia de web-admin, la tienda NO tiene sidebar: el contenido ocupa todo el ancho.
export const metadata: Metadata = {
  title: "web-customer",
  description: "Storefront for the Web3 e-commerce (Component 3) — browse, cart and checkout.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">
        <WalletProvider>
          <header className="flex items-center justify-between border-b border-line bg-sidebar px-6 py-4">
            <div className="flex items-center gap-8">
              <span className="text-lg font-semibold text-fg">web-customer</span>
              <NavLinks />
            </div>
            <div className="flex items-center gap-3">
              {/* 🇪🇸 Acceso a compra-stablecoin (comprar EURT con tarjeta). Pestaña nueva: es un
                  desvío para conseguir fondos y volver; deja la tienda abierta detrás. */}
              <a
                href={env.buyTokensUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-md border border-line bg-card px-3 py-1.5 text-sm font-medium text-accent hover:text-fg"
              >
                Buy EURT
              </a>
              <WalletConnect />
            </div>
          </header>
          <main>{children}</main>
        </WalletProvider>
      </body>
    </html>
  );
}
