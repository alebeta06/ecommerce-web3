import type { Metadata } from "next";
import "./globals.css";

// 🇪🇸 NOTA: layout raíz mínimo (App Router) para el scaffold. El header con WalletConnect y el
// WalletProvider se añaden en un commit posterior; por ahora solo establecemos <html>/<body> y el
// fondo/tipografía base. La tienda (web-customer) NO lleva sidebar (a diferencia de web-admin).
export const metadata: Metadata = {
  title: "web-customer",
  description: "Storefront for the Web3 e-commerce (Component 3) — browse, cart and checkout.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-bg antialiased">{children}</body>
    </html>
  );
}
