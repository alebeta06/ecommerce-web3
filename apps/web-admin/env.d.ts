import type { Eip1193Provider } from "ethers";

// 🇪🇸 NOTA: tipado de las env vars públicas para que TypeScript las conozca y autocomplete.
// Solo declaramos las NEXT_PUBLIC_* (expuestas al navegador). Esto es solo tipado: la
// validación en runtime vive en src/lib/env.ts (boundary). Las secretas (PINATA_JWT) se
// tipan donde se usen, en código de servidor.
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      readonly NEXT_PUBLIC_RPC_URL: string;
      readonly NEXT_PUBLIC_CHAIN_ID: string;
      readonly NEXT_PUBLIC_ECOMMERCE_ADDRESS: string;
      readonly NEXT_PUBLIC_EURO_TOKEN_ADDRESS: string;
      readonly NEXT_PUBLIC_IPFS_GATEWAY: string;
    }
  }

  // 🇪🇸 NOTA: window.ethereum lo inyecta MetaMask (proveedor EIP-1193). ethers v6 exporta el
  // tipo Eip1193Provider, que es justo la forma que consume BrowserProvider.
  interface Window {
    ethereum?: Eip1193Provider;
  }
}

export {};
