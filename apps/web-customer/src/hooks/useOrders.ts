"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Invoice, toInvoice } from "@/types/invoice";

export interface UseOrders {
  orders: Invoice[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useOrders(wallet: string | null): UseOrders {
  const { read } = useEcommerce();
  const [orders, setOrders] = useState<Invoice[]>([]);
  const [isLoading, setIsLoading] = useState(wallet !== null);
  const [error, setError] = useState<string | null>(null);

  const fetchOrders = useCallback(async () => {
    // 🇪🇸 Guard: sin wallet no hay pedidos que consultar.
    if (wallet === null || wallet === "") {
      setOrders([]);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setError(null);
    try {
      // 🇪🇸 getCustomerInvoices devuelve solo los ids; traemos cada invoice (con sus líneas) en
      // PARALELO con getInvoice. Mismo patrón que useCustomerInvoices en web-admin. Reusa toInvoice.
      const ids = (await read.getCustomerInvoices(wallet)) as bigint[];
      const raws = await Promise.all(ids.map((id) => read.getInvoice(id)));
      setOrders(raws.map(toInvoice));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load orders.");
      setOrders([]);
    } finally {
      setIsLoading(false);
    }
  }, [read, wallet]);

  useEffect(() => {
    void fetchOrders();
  }, [fetchOrders]);

  return { orders, isLoading, error, refetch: () => void fetchOrders() };
}
