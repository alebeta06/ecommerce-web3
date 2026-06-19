"use client";

import { Fragment, useState } from "react";
import { useWallet } from "@/hooks/useWallet";
import { useOrders } from "@/hooks/useOrders";
import { type Invoice } from "@/types/invoice";
import { formatEurt, formatTimestamp } from "@/lib/format";

export default function OrdersPage() {
  const { address } = useWallet();
  const { orders, isLoading, error } = useOrders(address);

  // 🇪🇸 Guard: sin wallet no hay historial on-chain que mostrar.
  if (address === null) {
    return (
      <main className="mx-auto max-w-6xl p-8">
        <h1 className="text-2xl font-bold">Orders</h1>
        <p className="mt-2 text-muted">Connect wallet to view your orders.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl p-8">
      <h1 className="text-2xl font-bold">Orders</h1>

      <div className="mt-6">
        {isLoading ? (
          <p className="text-sm text-muted">Loading…</p>
        ) : error !== null ? (
          <p className="text-sm text-red-400">{error}</p>
        ) : orders.length === 0 ? (
          <p className="text-sm text-muted">No orders yet.</p>
        ) : (
          <OrdersTable orders={orders} />
        )}
      </div>
    </main>
  );
}

// 🇪🇸 NOTA: tabla con expand inline (patrón InvoiceList de web-admin). Una orden abierta a la vez.
function OrdersTable({ orders }: { orders: Invoice[] }) {
  const [expandedId, setExpandedId] = useState<number | null>(null);

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-line text-left text-muted">
          <th className="py-2 pr-4 font-medium">ID</th>
          <th className="py-2 pr-4 font-medium">Total</th>
          <th className="py-2 pr-4 font-medium">Date</th>
          <th className="py-2 pr-4 font-medium">Status</th>
          <th className="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        {orders.map((order) => {
          const isExpanded = expandedId === order.id;
          return (
            <Fragment key={order.id}>
              <tr className="border-b border-line">
                <td className="py-2 pr-4">{order.id}</td>
                <td className="py-2 pr-4">{formatEurt(order.total)}</td>
                <td className="py-2 pr-4">{formatTimestamp(order.createdAt)}</td>
                <td className="py-2 pr-4">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      order.isPaid ? "bg-success/15 text-success" : "bg-accent-2/25 text-fg"
                    }`}
                  >
                    {order.isPaid ? "Paid" : "Unpaid"}
                  </span>
                </td>
                <td className="py-2">
                  <button
                    type="button"
                    onClick={() => setExpandedId(isExpanded ? null : order.id)}
                    className="text-accent hover:underline"
                  >
                    {isExpanded ? "Hide" : "Details"}
                  </button>
                </td>
              </tr>
              {isExpanded ? (
                <tr className="border-b border-line bg-card">
                  {/* 🇪🇸 Líneas inline: ya vienen en el objeto invoice, sin lecturas extra. El
                      subtotal se calcula en bigint (quantity * unitPrice) para no perder precisión. */}
                  <td colSpan={5} className="px-4 py-3">
                    <table className="w-full border-collapse text-xs">
                      <thead>
                        <tr className="text-left text-muted">
                          <th className="py-1 pr-4 font-medium">Product</th>
                          <th className="py-1 pr-4 font-medium">Qty</th>
                          <th className="py-1 pr-4 font-medium">Unit price</th>
                          <th className="py-1 font-medium">Subtotal</th>
                        </tr>
                      </thead>
                      <tbody>
                        {order.lines.map((line, i) => (
                          <tr key={i}>
                            <td className="py-1 pr-4">#{line.productId}</td>
                            <td className="py-1 pr-4">{line.quantity.toString()}</td>
                            <td className="py-1 pr-4">{formatEurt(line.unitPrice)}</td>
                            <td className="py-1">{formatEurt(line.quantity * line.unitPrice)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </td>
                </tr>
              ) : null}
            </Fragment>
          );
        })}
      </tbody>
    </table>
  );
}
