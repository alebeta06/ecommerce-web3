import type { Eip1193Provider } from "ethers";

// 🇪🇸 NOTA: tipado de las env vars para que TypeScript las conozca y autocomplete. Aquí declaramos
// TANTO las NEXT_PUBLIC_* (expuestas al navegador) COMO las server-only (sin prefijo: solo existen
// en el servidor / API routes). Esto es solo TIPADO; la validación en runtime de las públicas vive
// en src/lib/env.ts (boundary). Las server-only se leen directamente con process.env en las API
// routes (NUNCA desde el cliente), por eso no pasan por env.ts.
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      // ── Públicas (navegador + servidor) ──────────────────────────────
      readonly NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY: string;
      readonly NEXT_PUBLIC_EUROTOKEN_ADDRESS: string;
      readonly NEXT_PUBLIC_RPC_URL: string;
      readonly NEXT_PUBLIC_CHAIN_ID: string;
      readonly NEXT_PUBLIC_PAYMENT_GATEWAY_URL: string;
      // ── Server-only (solo API routes; NUNCA al cliente) ──────────────
      readonly STRIPE_SECRET_KEY: string;
      readonly WALLET_PRIVATE_KEY: string;
      readonly RPC_URL: string;
    }
  }

  // 🇪🇸 NOTA: window.ethereum lo inyecta MetaMask (proveedor EIP-1193). ethers v6 exporta el
  // tipo Eip1193Provider, que es justo la forma que consume BrowserProvider.
  interface Window {
    ethereum?: Eip1193Provider;
  }
}

export {};
