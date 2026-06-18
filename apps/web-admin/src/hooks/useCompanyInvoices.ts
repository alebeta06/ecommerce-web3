"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Invoice, toInvoice } from "@/types/invoice";

export interface UseCompanyInvoices {
  invoices: Invoice[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useCompanyInvoices(companyId: number): UseCompanyInvoices {
  const { read } = useEcommerce();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchInvoices = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // 🇪🇸 getCompanyInvoices devuelve solo los ids de las invoices de esta empresa. Luego
      // traemos cada invoice con getInvoice en PARALELO (Promise.all): N invoices ≈ 1 RTT en vez
      // de N secuenciales. Cada invoice ya incluye sus líneas, así que no hay más lecturas.
      const ids = (await read.getCompanyInvoices(companyId)) as bigint[];
      const raws = await Promise.all(ids.map((id) => read.getInvoice(id)));
      setInvoices(raws.map(toInvoice));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load invoices.");
      setInvoices([]);
    } finally {
      setIsLoading(false);
    }
  }, [read, companyId]);

  useEffect(() => {
    void fetchInvoices();
  }, [fetchInvoices]);

  return { invoices, isLoading, error, refetch: () => void fetchInvoices() };
}
