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

export function useProducts(companyId: number): UseProducts {
  const { read } = useEcommerce();
  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProducts = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // 🇪🇸 NOTA: getAllProducts() devuelve TODO el catálogo en una sola lectura (1 RTT). Filtrar
      // por companyId en cliente es más simple que iterar getProduct por id, y con catálogos de
      // este tamaño el coste de traer todo es despreciable.
      const raws = await read.getAllProducts();
      setProducts(raws.map(toProduct).filter((p: Product) => p.companyId === companyId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load products.");
      setProducts([]);
    } finally {
      setIsLoading(false);
    }
  }, [read, companyId]);

  useEffect(() => {
    void fetchProducts();
  }, [fetchProducts]);

  return { products, isLoading, error, refetch: () => void fetchProducts() };
}
