import type { Metadata } from "next";
import "./globals.css";

// 🇪🇸 NOTA: layout raíz mínimo (scaffold). El estado de wallet (WalletProvider) y el botón de
// conexión se añaden en un commit posterior; aquí solo el header con el título y el <main>.
export const metadata: Metadata = {
  title: "payment-gateway",
  description:
    "Payment gateway for the Web3 e-commerce (Component 3) — approve EURT and pay invoices.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">
        <header className="flex items-center justify-between border-b border-line bg-sidebar px-6 py-4">
          <span className="text-lg font-semibold text-fg">payment-gateway</span>
        </header>
        <main>{children}</main>
      </body>
    </html>
  );
}
