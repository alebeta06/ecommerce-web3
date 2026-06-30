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
  // 🇪🇸 `logsRead` es un Contract de solo-lectura apuntando al RPC de escaneo de logs (env.logsRpcUrl).
  // Solo se usa para queryFilter/eventos (ver useCustomers); el resto de lecturas usan `read`.
  // Si logsRpcUrl === rpcUrl (p.ej. Anvil), reutilizamos `read` sin crear un segundo provider.
  logsRead: Contract;
  write: Contract | null;
}

export function useEcommerce(): UseEcommerce {
  const { signer } = useWallet();

  const read = useMemo(() => getEcommerceContract(new JsonRpcProvider(env.rpcUrl)), []);
  // 🇪🇸 batchMaxCount:1 → desactiva el JSON-RPC batching de ethers (default 100) SOLO en el provider
  // de logs. ethers agrupa varias llamadas en un único HTTP request (array JSON-RPC); dRPC free tier
  // rechaza batches > 3 ("Batch of more than 3 requests"). Con 1, cada petición va en su propio HTTP
  // request. Solo afecta al transporte, no a los datos (Anvil idéntico). `read` (Alchemy) conserva su
  // batching: ahí es beneficioso y no tiene este límite.
  const logsRead = useMemo(
    () =>
      env.logsRpcUrl === env.rpcUrl
        ? read
        : getEcommerceContract(new JsonRpcProvider(env.logsRpcUrl, undefined, { batchMaxCount: 1 })),
    [read],
  );
  const write = useMemo(() => (signer ? getEcommerceContract(signer) : null), [signer]);

  return { read, logsRead, write };
}
