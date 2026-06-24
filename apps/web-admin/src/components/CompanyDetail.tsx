"use client";

import { useState } from "react";
import { useCompany } from "@/hooks/useCompany";
import { useProducts } from "@/hooks/useProducts";
import { useCompanyInvoices } from "@/hooks/useCompanyInvoices";
import { ProductList } from "@/components/ProductList";
import { ProductForm } from "@/components/ProductForm";
import { InvoiceList } from "@/components/InvoiceList";

type Tab = "info" | "products" | "invoices";

const TABS: { key: Tab; label: string }[] = [
  { key: "info", label: "Info" },
  { key: "products", label: "Products" },
  { key: "invoices", label: "Invoices" },
];

export function CompanyDetail({ id }: { id: number }) {
  const { company, isLoading, error } = useCompany(id);
  const [tab, setTab] = useState<Tab>("info");
  // 🇪🇸 companyId = id de la ruta (== company.id). Lo llamamos a nivel top para respetar las
  // reglas de hooks; el filtro por companyId vive dentro de useProducts.
  const products = useProducts(id);
  // 🇪🇸 Mismas reglas de hooks: lo llamamos a nivel top. El hook trae los ids de invoices de la
  // empresa y luego cada invoice (con sus líneas) en paralelo.
  const invoices = useCompanyInvoices(id);

  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (error !== null || company === null) {
    return <p className="text-sm text-red-400">{error ?? "Company not found."}</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold">{company.name}</h1>
      <p className="mt-1 text-sm text-muted">Company #{company.id}</p>

      {/* 🇪🇸 Tab bar: HTML + Tailwind, sin librerías. El activo lleva borde inferior azul. */}
      <div className="mt-6 flex gap-1 border-b border-line">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setTab(t.key)}
            className={`-mb-px border-b-2 px-4 py-2 text-sm font-medium ${
              tab === t.key
                ? "border-accent text-accent"
                : "border-transparent text-muted hover:text-fg"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="mt-6">
        {tab === "info" ? (
          <dl className="space-y-3 text-sm">
            <div>
              <dt className="text-muted">Name</dt>
              <dd className="font-medium">{company.name}</dd>
            </div>
            <div>
              <dt className="text-muted">Owner</dt>
              <dd className="font-mono break-all">{company.owner}</dd>
            </div>
            <div>
              <dt className="text-muted">Payout wallet</dt>
              <dd className="font-mono break-all">{company.payoutWallet}</dd>
            </div>
          </dl>
        ) : null}
        {tab === "products" ? (
          <div className="flex flex-col gap-6">
            <ProductForm companyId={company.id} onAdded={products.refetch} />
            <ProductList
              products={products.products}
              isLoading={products.isLoading}
              error={products.error}
              companyId={company.id}
              onUpdated={products.refetch}
            />
          </div>
        ) : null}
        {tab === "invoices" ? (
          <InvoiceList
            invoices={invoices.invoices}
            products={products.products}
            isLoading={invoices.isLoading}
            error={invoices.error}
          />
        ) : null}
      </div>
    </div>
  );
}
