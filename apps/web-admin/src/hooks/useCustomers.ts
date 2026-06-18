"use client";

import { useCallback, useEffect, useState } from "react";
import { type EventLog } from "ethers";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type Customer, toCustomer } from "@/types/customer";

export interface UseCustomers {
  customers: Customer[];
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useCustomers(): UseCustomers {
  const { read } = useEcommerce();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCustomers = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // 🇪🇸 NOTA: el contrato NO expone una lista de clientes (no hay getAllCustomers ni contador).
      // La única forma de descubrirlos es leer el LOG del evento CustomerRegistered con queryFilter,
      // que escanea los bloques de la cadena buscando ese evento. En Anvil escaneamos desde el bloque
      // 0 (barato); en una red real habría que paginar por rangos de bloques para no exceder límites.
      const events = await read.queryFilter(read.filters.CustomerRegistered());
      // 🇪🇸 Sacamos las wallets del primer arg indexado del evento. Set para deduplicar por si acaso
      // (un re-registro revierte en el contrato, así que en la práctica no habrá duplicados).
      const wallets = [
        ...new Set(events.map((e) => String((e as EventLog).args[0]))),
      ];
      // 🇪🇸 Traemos el ESTADO ACTUAL de cada cliente (getCustomer) en PARALELO: así reflejamos el
      // nombre vigente tras posibles renames (CustomerUpdated), no el nombre que tenía al registrarse.
      const raws = await Promise.all(wallets.map((w) => read.getCustomer(w)));
      setCustomers(raws.map(toCustomer));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load customers.");
      setCustomers([]);
    } finally {
      setIsLoading(false);
    }
  }, [read]);

  useEffect(() => {
    void fetchCustomers();
  }, [fetchCustomers]);

  return { customers, isLoading, error, refetch: () => void fetchCustomers() };
}
