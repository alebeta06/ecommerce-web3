"use client";

import { useCallback, useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { type CartItem, toCartItem } from "@/types/cart";
import { type Product, toProduct } from "@/types/product";

// 🇪🇸 NOTA: línea del carrito enriquecida = item on-chain (companyId/productId/quantity) + datos del
// producto cruzados del catálogo (name/price) + subtotal calculado. price y subtotal en bigint
// (montos on-chain de 6 decimales); el formateo a "€X.XX" se hace al mostrar.
export interface CartLineItem extends CartItem {
  name: string;
  price: bigint;
  subtotal: bigint;
}

export interface UseCart {
  items: CartLineItem[];
  total: bigint;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useCart(wallet: string | null): UseCart {
  const { read } = useEcommerce();
  const [items, setItems] = useState<CartLineItem[]>([]);
  const [total, setTotal] = useState<bigint>(0n);
  const [isLoading, setIsLoading] = useState(wallet !== null);
  const [error, setError] = useState<string | null>(null);
  // 🇪🇸 nonce: refetch() lo incrementa para re-disparar el efecto (p.ej. tras quitar una línea).
  const [nonce, setNonce] = useState(0);
  const refetch = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      // 🇪🇸 Sin wallet conectada no hay carrito que leer.
      if (wallet === null) {
        setItems([]);
        setTotal(0n);
        setIsLoading(false);
        return;
      }
      setIsLoading(true);
      setError(null);
      try {
        // 🇪🇸 Decisión de diseño: en vez de N llamadas getProduct (una por línea), traemos el carrito
        // y TODO el catálogo en paralelo (1 RTT) y cruzamos en memoria. Más eficiente para carritos
        // con varias líneas.
        const [rawCart, rawProducts] = await Promise.all([
          read.getCart(wallet),
          read.getAllProducts(),
        ]);
        if (cancelled) return;

        const cartItems: CartItem[] = rawCart.map(toCartItem);
        const products: Product[] = rawProducts.map(toProduct);

        // 🇪🇸 Índice por "companyId-productId" para cruzar cada línea en O(1).
        const byKey = new Map<string, Product>();
        for (const p of products) byKey.set(`${p.companyId}-${p.id}`, p);

        let runningTotal = 0n;
        const lines: CartLineItem[] = cartItems.map((item) => {
          const product = byKey.get(`${item.companyId}-${item.productId}`);
          // 🇪🇸 Si el producto ya no existe en el catálogo (borrado/inactivo tras añadirlo), mostramos
          // un placeholder con precio 0 en vez de romper la vista.
          const name = product?.name ?? `Product #${item.productId}`;
          const price = product?.price ?? 0n;
          const subtotal = price * item.quantity;
          runningTotal += subtotal;
          return { ...item, name, price, subtotal };
        });

        setItems(lines);
        setTotal(runningTotal);
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Failed to load cart.");
        setItems([]);
        setTotal(0n);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }
    void run();
    return () => {
      cancelled = true;
    };
  }, [read, wallet, nonce]);

  return { items, total, isLoading, error, refetch };
}
