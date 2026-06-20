import type { Metadata } from "next";
import "./globals.css";
import { WalletProvider } from "@/hooks/useWallet";
import { WalletConnect } from "@/components/WalletConnect";

// 🇪🇸 NOTA: layout raíz (App Router). Envolvemos toda la app en WalletProvider para que el estado
// de la wallet sea único y compartido (header + hooks). La pasarela NO tiene sidebar ni navegación
// entre páginas (es una pantalla única de pago): el header solo muestra el título y el estado de
// conexión, y el contenido ocupa todo el ancho.
export const metadata: Metadata = {
  title: "payment-gateway",
  description:
    "Payment gateway for the Web3 e-commerce (Component 3) — approve EURT and pay invoices.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">
        <WalletProvider>
          <header className="flex items-center justify-between border-b border-line bg-sidebar px-6 py-4">
            <span className="text-lg font-semibold text-fg">payment-gateway</span>
            <WalletConnect />
          </header>
          <main>{children}</main>
        </WalletProvider>
      </body>
    </html>
  );
}
