"use client";

import { useCallback, useEffect, useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { useEcommerce } from "@/hooks/useEcommerce";
import { friendlyError } from "@/lib/errors";

export type RegisterStatus = "idle" | "pending" | "success" | "error";

// 🇪🇸 NOTA: vista mínima del cliente para la tienda (no necesitamos el struct completo).
export interface CustomerInfo {
  wallet: string;
  name: string;
  createdAt: bigint;
}

export interface UseCustomer {
  customer: CustomerInfo | null;
  isRegistered: boolean;
  isLoading: boolean;
  status: RegisterStatus;
  message: string | null;
  register: (name: string) => Promise<boolean>;
  refetch: () => void;
}

export function useCustomer(wallet: string | null): UseCustomer {
  const { read, write } = useEcommerce();
  const [customer, setCustomer] = useState<CustomerInfo | null>(null);
  const [isRegistered, setIsRegistered] = useState(false);
  const [isLoading, setIsLoading] = useState(wallet !== null);
  const [status, setStatus] = useState<RegisterStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);
  // 🇪🇸 nonce: refetch() lo incrementa para re-leer getCustomer (p.ej. tras registrar).
  const [nonce, setNonce] = useState(0);
  const refetch = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      // 🇪🇸 Sin wallet conectada no hay nada que leer.
      if (wallet === null) {
        setCustomer(null);
        setIsRegistered(false);
        setIsLoading(false);
        return;
      }
      setIsLoading(true);
      try {
        // 🇪🇸 getCustomer REVIERTE CustomerNotFound si la wallet no está registrada (CustomerLib.get).
        // Por eso el camino feliz = registrado; el catch = no registrado.
        const raw = await read.getCustomer(wallet);
        if (cancelled) return;
        setCustomer({
          wallet: String(raw.wallet),
          name: String(raw.name),
          createdAt: raw.createdAt,
        });
        setIsRegistered(true);
      } catch {
        if (cancelled) return;
        setCustomer(null);
        setIsRegistered(false);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }
    void run();
    return () => {
      cancelled = true;
    };
  }, [read, wallet, nonce]);

  // 🇪🇸 register: registra a la wallet conectada (registerCustomer(name) actúa sobre msg.sender).
  // Devuelve true si la tx mina OK, para que el llamador (modal) sepa cuándo proceder.
  const register = useCallback(
    async (name: string): Promise<boolean> => {
      if (write === null) {
        setStatus("error");
        setMessage("Connect your wallet first.");
        return false;
      }
      if (name.trim() === "") {
        setStatus("error");
        setMessage("Name is required.");
        return false;
      }
      setStatus("pending");
      setMessage(null);
      try {
        const tx = (await write.registerCustomer(name.trim())) as ContractTransactionResponse;
        await tx.wait();
        setStatus("success");
        setMessage("Registered.");
        refetch();
        return true;
      } catch (err) {
        setStatus("error");
        setMessage(friendlyError(err));
        return false;
      }
    },
    [write, refetch],
  );

  return { customer, isRegistered, isLoading, status, message, register, refetch };
}
