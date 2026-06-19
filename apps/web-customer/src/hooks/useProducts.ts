"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Product, toProduct } from "@/types/product";

export interface UseProducts {
  products: Product[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useProducts(): UseProducts {
  const { read } = useEcommerce();
  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  // 🇪🇸 nonce: refetch() lo incrementa para re-disparar el efecto. Así el fetch vive dentro del
  // useEffect (con su flag `cancelled`) y evitamos setState sobre un componente desmontado.
  const [nonce, setNonce] = useState(0);
  const refetch = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      setIsLoading(true);
      setError(null);
      try {
        // 🇪🇸 getAllProducts() trae TODO el catálogo en 1 RTT. El comprador solo ve los activos
        // (active === true); no filtramos por empresa (ve el catálogo completo de la plataforma).
        const raws = await read.getAllProducts();
        if (cancelled) return;
        setProducts(raws.map(toProduct).filter((p: Product) => p.active));
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Failed to load products.");
        setProducts([]);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }
    void run();
    return () => {
      cancelled = true;
    };
  }, [read, nonce]);

  return { products, isLoading, error, refetch };
}
