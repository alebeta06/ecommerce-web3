"use client";

import { useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { toInvoice, type Invoice } from "@/types/invoice";

export interface UseInvoices {
  invoices: Invoice[];
  isLoading: boolean;
  error: string | null;
}

export function useInvoices(ids: number[]): UseInvoices {
  const { read } = useEcommerce();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 🇪🇸 ids llega como array nuevo en cada render; dependemos de su CONTENIDO (key), no de su
  // identidad, para no disparar el efecto en bucle. read es estable (useMemo en useEcommerce).
  const key = ids.join(",");

  useEffect(() => {
    let cancelled = false;
    const idList = key === "" ? [] : key.split(",").map(Number);

    async function load() {
      if (idList.length === 0) {
        setInvoices([]);
        setIsLoading(false);
        return;
      }
      setIsLoading(true);
      setError(null);
      try {
        // 🇪🇸 getInvoice por cada id EN PARALELO (mismo patrón que useOrders). toInvoice aísla el casteo.
        const raws = await Promise.all(idList.map((id) => read.getInvoice(id)));
        if (!cancelled) setInvoices(raws.map(toInvoice));
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Failed to load invoices.");
          setInvoices([]);
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [key, read]);

  return { invoices, isLoading, error };
}
