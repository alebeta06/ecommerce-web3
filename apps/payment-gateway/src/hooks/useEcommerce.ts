"use client";

import { useMemo } from "react";
import { Contract, JsonRpcProvider } from "ethers";
import { getEcommerceContract } from "@/lib/contracts";
import { env } from "@/lib/env";
import { useWallet } from "@/hooks/useWallet";

// 🇪🇸 NOTA: separamos lectura y escritura. Las lecturas (catálogo, invoices) NO necesitan wallet:
// usan un JsonRpcProvider apuntando al RPC. Las escrituras (registrar empresa, crear producto) SÍ
// necesitan el Signer de MetaMask, por eso `write` es null hasta que la wallet esté conectada.
export interface UseEcommerce {
  read: Contract;
  write: Contract | null;
}

export function useEcommerce(): UseEcommerce {
  const { signer } = useWallet();

  const read = useMemo(() => getEcommerceContract(new JsonRpcProvider(env.rpcUrl)), []);
  const write = useMemo(() => (signer ? getEcommerceContract(signer) : null), [signer]);

  return { read, write };
}
