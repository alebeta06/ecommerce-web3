"use client";

import { useState } from "react";
import { useCompany } from "@/hooks/useCompany";

type Tab = "info" | "products" | "invoices";

const TABS: { key: Tab; label: string }[] = [
  { key: "info", label: "Info" },
  { key: "products", label: "Products" },
  { key: "invoices", label: "Invoices" },
];

export function CompanyDetail({ id }: { id: number }) {
  const { company, isLoading, error } = useCompany(id);
  const [tab, setTab] = useState<Tab>("info");

  if (isLoading) return <p className="text-sm text-gray-500">Loading…</p>;
  if (error !== null || company === null) {
    return <p className="text-sm text-red-600">{error ?? "Company not found."}</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold">{company.name}</h1>
      <p className="mt-1 text-sm text-gray-500">Company #{company.id}</p>

      {/* 🇪🇸 Tab bar: HTML + Tailwind, sin librerías. El activo lleva borde inferior azul. */}
      <div className="mt-6 flex gap-1 border-b border-gray-200">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setTab(t.key)}
            className={`-mb-px border-b-2 px-4 py-2 text-sm font-medium ${
              tab === t.key
                ? "border-blue-600 text-blue-700"
                : "border-transparent text-gray-500 hover:text-gray-700"
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
              <dt className="text-gray-500">Name</dt>
              <dd className="font-medium">{company.name}</dd>
            </div>
            <div>
              <dt className="text-gray-500">Owner</dt>
              <dd className="font-mono break-all">{company.owner}</dd>
            </div>
            <div>
              <dt className="text-gray-500">Payout wallet</dt>
              <dd className="font-mono break-all">{company.payoutWallet}</dd>
            </div>
          </dl>
        ) : null}
        {tab === "products" ? <p className="text-sm text-gray-500">Coming soon</p> : null}
        {tab === "invoices" ? <p className="text-sm text-gray-500">Coming soon</p> : null}
      </div>
    </div>
  );
}
