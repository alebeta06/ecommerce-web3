import type { Metadata } from "next";
import "./globals.css";

// 🇪🇸 NOTA: layout raíz mínimo (App Router). El header con WalletConnect se añade en un
// commit posterior; aquí solo dejamos la estructura html/body y los estilos globales.
export const metadata: Metadata = {
  title: "web-admin",
  description: "Merchant back-office for the Web3 e-commerce (Component 5).",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-white text-gray-900 antialiased">{children}</body>
    </html>
  );
}
