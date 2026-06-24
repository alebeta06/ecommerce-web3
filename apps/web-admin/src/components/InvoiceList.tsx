"use client";

import { Fragment, useState } from "react";
import { type Invoice } from "@/types/invoice";
import { type Product } from "@/types/product";
import { formatEurt, shortenAddress } from "@/lib/format";

export function InvoiceList({
  invoices,
  products = [],
  isLoading,
  error,
}: {
  invoices: Invoice[];
  // 🇪🇸 Opcional: CompanyDetail pasa los productos de la empresa (muestra nombres). Otros consumidores
  // (p.ej. facturas de cliente, que cruzan empresas) pueden omitirlo y caer al fallback "#id".
  products?: Product[];
  isLoading: boolean;
  error: string | null;
}) {
  // 🇪🇸 Una sola invoice expandida a la vez. null = ninguna. Toggle por id al pulsar "Details".
  const [expandedId, setExpandedId] = useState<number | null>(null);
  // 🇪🇸 productId→name para mostrar el nombre en las líneas (fallback "#id" si no está cargado aún).
  const productNames = new Map<number, string>(products.map((p) => [p.id, p.name]));

  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (error !== null) return <p className="text-sm text-red-400">{error}</p>;
  if (invoices.length === 0) return <p className="text-sm text-muted">No invoices yet.</p>;

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-line text-left text-muted">
          <th className="py-2 pr-4 font-medium">ID</th>
          <th className="py-2 pr-4 font-medium">Customer</th>
          <th className="py-2 pr-4 font-medium">Total</th>
          <th className="py-2 pr-4 font-medium">Paid</th>
          <th className="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        {invoices.map((inv) => {
          const isExpanded = expandedId === inv.id;
          return (
            <Fragment key={inv.id}>
              <tr className="border-b border-line">
                <td className="py-2 pr-4">{inv.id}</td>
                <td className="py-2 pr-4 font-mono">{shortenAddress(inv.customer)}</td>
                <td className="py-2 pr-4">{formatEurt(inv.total)}</td>
                <td className="py-2 pr-4">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      inv.isPaid ? "bg-success/15 text-success" : "bg-accent-2/25 text-fg"
                    }`}
                  >
                    {inv.isPaid ? "Paid" : "Unpaid"}
                  </span>
                </td>
                <td className="py-2">
                  <button
                    type="button"
                    onClick={() => setExpandedId(isExpanded ? null : inv.id)}
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
                        {inv.lines.map((line, i) => (
                          <tr key={i}>
                            <td className="py-1 pr-4">
                              {productNames.get(line.productId) ?? `#${line.productId}`}
                            </td>
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
