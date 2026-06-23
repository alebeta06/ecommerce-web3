"use client";

import { useCallback, useEffect, useState } from "react";
import { JsonRpcProvider } from "ethers";
import { getEuroTokenContract } from "@/lib/contracts";
import { env } from "@/lib/env";

export interface UseEuroTokenBalance {
  balance: bigint | null;
  isLoading: boolean;
  refetch: () => Promise<void>;
}

export function useEuroTokenBalance(address: string | null): UseEuroTokenBalance {
  const [balance, setBalance] = useState<bigint | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const refetch = useCallback(async () => {
    if (address === null || address === "") {
      setBalance(null);
      return;
    }
    setIsLoading(true);
    try {
      // 🇪🇸 Lectura sin wallet: JsonRpcProvider directo (igual que el `read` de useEcommerce).
      const euroToken = getEuroTokenContract(new JsonRpcProvider(env.rpcUrl));
      const raw = (await euroToken.balanceOf(address)) as bigint;
      setBalance(raw);
    } catch {
      setBalance(null);
    } finally {
      setIsLoading(false);
    }
  }, [address]);

  useEffect(() => {
    void refetch();
  }, [refetch]);

  return { balance, isLoading, refetch };
}
