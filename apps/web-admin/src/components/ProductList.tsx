"use client";

import { useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { type Product } from "@/types/product";
import { formatEurt } from "@/lib/format";
import { useEcommerce } from "@/hooks/useEcommerce";

export function ProductList({
  products,
  isLoading,
  error,
  companyId,
  onUpdated,
}: {
  products: Product[];
  isLoading: boolean;
  error: string | null;
  companyId: number;
  onUpdated: () => void;
}) {
  if (isLoading) return <p className="text-sm text-gray-500">Loading…</p>;
  if (error !== null) return <p className="text-sm text-red-600">{error}</p>;
  if (products.length === 0) return <p className="text-sm text-gray-500">No products yet.</p>;

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-gray-200 text-left text-gray-500">
          <th className="py-2 pr-4 font-medium">Name</th>
          <th className="py-2 pr-4 font-medium">Price</th>
          <th className="py-2 pr-4 font-medium">Stock</th>
          <th className="py-2 pr-4 font-medium">Active</th>
          <th className="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        {products.map((p) => (
          <ProductRow key={p.id} product={p} companyId={companyId} onUpdated={onUpdated} />
        ))}
      </tbody>
    </table>
  );
}

// 🇪🇸 NOTA: cada fila gestiona su propio tx-state para que togglear un producto no bloquee la
// tabla entera. updateProduct revierte si no sos owner/admin → cae en el catch y mostramos error.
type TxStatus = "idle" | "pending" | "error";

function ProductRow({
  product,
  companyId,
  onUpdated,
}: {
  product: Product;
  companyId: number;
  onUpdated: () => void;
}) {
  const { write } = useEcommerce();
  const [status, setStatus] = useState<TxStatus>("idle");

  async function toggleActive() {
    // 🇪🇸 Guard: sin wallet no hay signer (write === null); el botón ya está disabled, doble check.
    if (write === null) return;
    setStatus("pending");
    try {
      // 🇪🇸 Reusamos price/stock actuales (bigint) y sólo invertimos active. Orden del ABI:
      // updateProduct(companyId, productId, newPrice, newStock, active).
      const tx = (await write.updateProduct(
        companyId,
        product.id,
        product.price,
        product.stock,
        !product.active,
      )) as ContractTransactionResponse;
      await tx.wait();
      setStatus("idle");
      onUpdated(); // 🇪🇸 refetch de la lista
    } catch {
      setStatus("error");
    }
  }

  return (
    <tr className="border-b border-gray-100">
      <td className="py-2 pr-4">{product.name}</td>
      <td className="py-2 pr-4">{formatEurt(product.price)}</td>
      <td className="py-2 pr-4">{product.stock.toString()}</td>
      <td className="py-2 pr-4">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            product.active ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"
          }`}
        >
          {product.active ? "Active" : "Inactive"}
        </span>
      </td>
      <td className="py-2">
        <button
          type="button"
          onClick={toggleActive}
          disabled={write === null || status === "pending"}
          title={write === null ? "Connect wallet first" : undefined}
          className="text-blue-600 hover:underline disabled:opacity-50 disabled:no-underline"
        >
          {status === "pending"
            ? "Saving…"
            : status === "error"
              ? "Retry"
              : product.active
                ? "Deactivate"
                : "Activate"}
        </button>
      </td>
    </tr>
  );
}
