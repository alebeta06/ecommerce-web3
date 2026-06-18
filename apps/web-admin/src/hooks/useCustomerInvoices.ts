"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Invoice, toInvoice } from "@/types/invoice";

export interface UseCustomerInvoices {
  invoices: Invoice[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useCustomerInvoices(wallet: string): UseCustomerInvoices {
  const { read } = useEcommerce();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchInvoices = useCallback(async () => {
    // 🇪🇸 Guard: sin wallet no hay nada que consultar (evita una llamada con address vacía).
    if (wallet === "") {
      setInvoices([]);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setError(null);
    try {
      // 🇪🇸 Mismo patrón que useCompanyInvoices: getCustomerInvoices devuelve solo los ids; luego
      // traemos cada invoice (con sus líneas) en PARALELO con getInvoice. Reusa el mapper toInvoice.
      const ids = (await read.getCustomerInvoices(wallet)) as bigint[];
      const raws = await Promise.all(ids.map((id) => read.getInvoice(id)));
      setInvoices(raws.map(toInvoice));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load invoices.");
      setInvoices([]);
    } finally {
      setIsLoading(false);
    }
  }, [read, wallet]);

  useEffect(() => {
    void fetchInvoices();
  }, [fetchInvoices]);

  return { invoices, isLoading, error, refetch: () => void fetchInvoices() };
}
