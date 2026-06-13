"use client";

import { useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Company, toCompany } from "@/types/company";

export interface UseCompany {
  company: Company | null;
  isLoading: boolean;
  error: string | null;
}

export function useCompany(id: number): UseCompany {
  const { read } = useEcommerce();
  const [company, setCompany] = useState<Company | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 🇪🇸 NOTA: flag para descartar el resultado si el componente se desmonta o cambia el id
    // antes de que resuelva la lectura (evita setState sobre un fetch obsoleto).
    let cancelled = false;

    async function load() {
      setIsLoading(true);
      setError(null);
      try {
        // 🇪🇸 getCompany revierte CompanyNotFound si el id no existe → cae en el catch.
        const raw = await read.getCompany(id);
        if (!cancelled) setCompany(toCompany(raw));
      } catch (err) {
        if (!cancelled) {
          setCompany(null);
          setError(err instanceof Error ? err.message : "Failed to load company.");
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [read, id]);

  return { company, isLoading, error };
}
