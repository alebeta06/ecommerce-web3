"use client";

import { Fragment, useState } from "react";
import { type Customer } from "@/types/customer";
import { useCustomerInvoices } from "@/hooks/useCustomerInvoices";
import { InvoiceList } from "@/components/InvoiceList";
import { shortenAddress, formatTimestamp } from "@/lib/format";

// 🇪🇸 NOTA: sub-componente que vive en su PROPIO ciclo de montaje. Al renderizarse SOLO cuando la
// fila está expandida, useCustomerInvoices se dispara únicamente en ese momento (no N fetches a la
// vez al cargar la tabla) y respeta las reglas de hooks (nada de hooks dentro de un map condicional).
// Reusa InvoiceList tal cual: la vista de facturas es idéntica a la de la pestaña Invoices de empresa.
function CustomerInvoices({ wallet }: { wallet: string }) {
  const { invoices, isLoading, error } = useCustomerInvoices(wallet);
  return <InvoiceList invoices={invoices} isLoading={isLoading} error={error} />;
}

export function CustomerList({
  customers,
  isLoading,
  error,
}: {
  customers: Customer[];
  isLoading: boolean;
  error: string | null;
}) {
  // 🇪🇸 Un cliente expandido a la vez. null = ninguno. Clave = wallet (su identidad on-chain).
  const [expandedWallet, setExpandedWallet] = useState<string | null>(null);

  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (error !== null) return <p className="text-sm text-red-400">{error}</p>;
  if (customers.length === 0) return <p className="text-sm text-muted">No customers yet.</p>;

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-line text-left text-muted">
          <th className="py-2 pr-4 font-medium">Wallet</th>
          <th className="py-2 pr-4 font-medium">Name</th>
          <th className="py-2 pr-4 font-medium">Registered</th>
          <th className="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        {customers.map((c) => {
          const isExpanded = expandedWallet === c.wallet;
          return (
            <Fragment key={c.wallet}>
              <tr className="border-b border-line">
                <td className="py-2 pr-4 font-mono">{shortenAddress(c.wallet)}</td>
                <td className="py-2 pr-4">{c.name}</td>
                <td className="py-2 pr-4">{formatTimestamp(c.createdAt)}</td>
                <td className="py-2">
                  <button
                    type="button"
                    onClick={() => setExpandedWallet(isExpanded ? null : c.wallet)}
                    className="text-accent hover:underline"
                  >
                    {isExpanded ? "Hide" : "Details"}
                  </button>
                </td>
              </tr>
              {isExpanded ? (
                <tr className="border-b border-line bg-card">
                  {/* 🇪🇸 Facturas del cliente: el hook se monta aquí (lazy) y reusa InvoiceList. */}
                  <td colSpan={4} className="px-4 py-3">
                    <CustomerInvoices wallet={c.wallet} />
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
