import type { Eip1193Provider } from "ethers";

// 🇪🇸 NOTA: tipado de las env vars públicas para que TypeScript las conozca y autocomplete.
// Solo declaramos las NEXT_PUBLIC_* (expuestas al navegador). Esto es solo tipado: la
// validación en runtime vive en src/lib/env.ts (boundary). La pasarela no maneja secretos de
// servidor ni IPFS: todas sus variables son públicas y on-chain.
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      readonly NEXT_PUBLIC_RPC_URL: string;
      readonly NEXT_PUBLIC_CHAIN_ID: string;
      readonly NEXT_PUBLIC_ECOMMERCE_ADDRESS: string;
      readonly NEXT_PUBLIC_EURO_TOKEN_ADDRESS: string;
    }
  }

  // 🇪🇸 NOTA: window.ethereum lo inyecta MetaMask (proveedor EIP-1193). ethers v6 exporta el
  // tipo Eip1193Provider, que es justo la forma que consume BrowserProvider.
  interface Window {
    ethereum?: Eip1193Provider;
  }
}

export {};
