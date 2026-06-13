"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Company, toCompany } from "@/types/company";

export interface UseCompanies {
  companies: Company[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useCompanies(): UseCompanies {
  const { read } = useEcommerce();
  const [companies, setCompanies] = useState<Company[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCompanies = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const count = Number(await read.companyCount());
      // 🇪🇸 NOTA: ids de 1 a count. Lanzamos todas las lecturas en PARALELO (Promise.all) en vez
      // de un for-await secuencial: con N empresas la latencia baja de O(N) RTT a ~1 RTT.
      const ids = Array.from({ length: count }, (_, i) => i + 1);
      const raws = await Promise.all(ids.map((id) => read.getCompany(id)));
      setCompanies(raws.map(toCompany));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load companies.");
      setCompanies([]);
    } finally {
      setIsLoading(false);
    }
  }, [read]);

  useEffect(() => {
    void fetchCompanies();
  }, [fetchCompanies]);

  return { companies, isLoading, error, refetch: () => void fetchCompanies() };
}
