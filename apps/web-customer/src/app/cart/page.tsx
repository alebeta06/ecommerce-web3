"use client";

import { useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { useWallet } from "@/hooks/useWallet";
import { useCart, type CartLineItem } from "@/hooks/useCart";
import { useEcommerce } from "@/hooks/useEcommerce";
import { formatEurt } from "@/lib/format";
import { friendlyError } from "@/lib/errors";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: estado de tx por acción (quitar línea / checkout). Mismo patrón que ProductRow en
// web-admin: idle → pending → error (el éxito refetchea o navega, así que no necesita estado propio).
type TxStatus = "idle" | "pending" | "error";

export default function CartPage() {
  const { address } = useWallet();
  const { items, total, isLoading, error, refetch } = useCart(address);

  // 🇪🇸 Guard: sin wallet no hay carrito on-chain que mostrar.
  if (address === null) {
    return (
      <main className="mx-auto max-w-6xl p-8">
        <h1 className="text-2xl font-bold">Cart</h1>
        <p className="mt-2 text-muted">Connect wallet to view your cart.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl p-8">
      <h1 className="text-2xl font-bold">Cart</h1>

      <div className="mt-6">
        {isLoading ? (
          // 🇪🇸 Skeleton: 4 filas en gris con pulso mientras carga el carrito.
          <div className="space-y-3">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="h-10 animate-pulse rounded-md border border-line bg-card" />
            ))}
          </div>
        ) : error !== null ? (
          <p className="text-sm text-red-400">{error}</p>
        ) : items.length === 0 ? (
          <p className="text-sm text-muted">Your cart is empty.</p>
        ) : (
          <CartTable items={items} total={total} address={address} refetch={refetch} />
        )}
      </div>
    </main>
  );
}

// 🇪🇸 NOTA: la tabla + el checkout viven en un sub-componente que SOLO se monta con líneas reales.
// Así useEcommerce (write) se usa con un carrito ya cargado y `address` ya garantizada no-null.
function CartTable({
  items,
  total,
  address,
  refetch,
}: {
  items: CartLineItem[];
  total: bigint;
  address: string;
  refetch: () => void;
}) {
  const { read, write } = useEcommerce();
  const [status, setStatus] = useState<TxStatus>("idle");
  const [checkoutError, setCheckoutError] = useState<string | null>(null);

  async function handleCheckout() {
    // 🇪🇸 Guard: sin signer no se puede checkout; el botón ya está disabled, doble check.
    if (write === null) return;
    setStatus("pending");
    setCheckoutError(null);
    try {
      // 🇪🇸 Diff de invoices antes/después: checkout() devuelve uint256[] por `return`, pero ethers v6
      // NO entrega return values de funciones que mutan estado y checkout no emite evento. Capturamos
      // el set previo y restamos para aislar EXACTAMENTE las facturas nuevas de este checkout.
      const before = new Set<number>(
        ((await read.getCustomerInvoices(address)) as bigint[]).map(Number),
      );
      const tx = (await write.checkout()) as ContractTransactionResponse;
      await tx.wait();
      const after = ((await read.getCustomerInvoices(address)) as bigint[]).map(Number);
      const newIds = after.filter((id) => !before.has(id));

      // 🇪🇸 URL de la pasarela. URLSearchParams codifica los valores (incl. la redirect-back a esta
      // app). window.location.origin evita hardcodear el :6004. Es navegación CROSS-ORIGIN (otra app
      // en :6002), por eso window.location.href y no router.push (que es para rutas internas).
      const params = new URLSearchParams({
        invoices: newIds.join(","),
        redirect: `${window.location.origin}/orders`,
      });
      window.location.href = `${env.paymentGatewayUrl}?${params.toString()}`;
    } catch (err) {
      setStatus("error");
      setCheckoutError(friendlyError(err));
    }
  }

  return (
    <>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b border-line text-left text-muted">
            <th className="py-2 pr-4 font-medium">Product</th>
            <th className="py-2 pr-4 font-medium">Qty</th>
            <th className="py-2 pr-4 font-medium">Unit price</th>
            <th className="py-2 pr-4 font-medium">Subtotal</th>
            <th className="py-2 font-medium" />
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <CartRow key={`${item.companyId}-${item.productId}`} item={item} refetch={refetch} />
          ))}
        </tbody>
      </table>

      <div className="mt-6 flex items-center justify-between">
        <p className="text-xl font-semibold">
          Total: <span className="text-accent">{formatEurt(total)}</span>
        </p>
        <button
          type="button"
          onClick={handleCheckout}
          disabled={items.length === 0 || write === null || status === "pending"}
          title={write === null ? "Connect wallet first" : undefined}
          className="rounded-md bg-accent px-5 py-2.5 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
        >
          {status === "pending" ? "Processing…" : "Proceed to checkout"}
        </button>
      </div>

      {checkoutError !== null ? <p className="mt-3 text-sm text-red-400">{checkoutError}</p> : null}
    </>
  );
}

// 🇪🇸 NOTA: cada fila gestiona su propio tx-state para que quitar una línea no bloquee la tabla
// entera (mismo patrón que ProductRow). removeFromCart(companyId, productId) — ambos uint256.
function CartRow({ item, refetch }: { item: CartLineItem; refetch: () => void }) {
  const { write } = useEcommerce();
  const [status, setStatus] = useState<TxStatus>("idle");

  async function remove() {
    if (write === null) return;
    setStatus("pending");
    try {
      const tx = (await write.removeFromCart(
        BigInt(item.companyId),
        BigInt(item.productId),
      )) as ContractTransactionResponse;
      await tx.wait();
      setStatus("idle");
      refetch();
    } catch {
      setStatus("error");
    }
  }

  return (
    <tr className="border-b border-line">
      <td className="py-2 pr-4">{item.name}</td>
      <td className="py-2 pr-4">{item.quantity.toString()}</td>
      <td className="py-2 pr-4">{formatEurt(item.price)}</td>
      <td className="py-2 pr-4">{formatEurt(item.subtotal)}</td>
      <td className="py-2">
        <button
          type="button"
          onClick={remove}
          disabled={write === null || status === "pending"}
          title={write === null ? "Connect wallet first" : undefined}
          className="text-red-400 hover:underline disabled:opacity-50 disabled:no-underline"
        >
          {status === "pending" ? "Removing…" : status === "error" ? "Retry" : "Remove"}
        </button>
      </td>
    </tr>
  );
}
