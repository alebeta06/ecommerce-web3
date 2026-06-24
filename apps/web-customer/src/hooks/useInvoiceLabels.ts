"use client";

import { useEffect, useState } from "react";
import { useEcommerce } from "@/hooks/useEcommerce";
import { toProduct } from "@/types/product";

export interface InvoiceLabels {
  productNames: Map<number, string>;
  companyNames: Map<number, string>;
}

// 🇪🇸 NOTA: nombres legibles para enriquecer facturas: productId→name (TODO el catálogo en una sola
// lectura) y companyId→name (getCompany por cada empresa única). Ambos en paralelo. Best-effort: si
// falla, la tabla cae al fallback "#id".
export function useInvoiceLabels(companyIds: number[]): InvoiceLabels {
  const { read } = useEcommerce();
  const [productNames, setProductNames] = useState<Map<number, string>>(new Map());
  const [companyNames, setCompanyNames] = useState<Map<number, string>>(new Map());

  // 🇪🇸 key estable (ids únicos ordenados) para no re-disparar el efecto por identidad del array.
  const key = Array.from(new Set(companyIds))
    .sort((a, b) => a - b)
    .join(",");

  useEffect(() => {
    let cancelled = false;
    const ids = key === "" ? [] : key.split(",").map(Number);

    async function load() {
      try {
        const [rawProducts, rawCompanies] = await Promise.all([
          read.getAllProducts(),
          Promise.all(ids.map((id) => read.getCompany(id))),
        ]);
        if (cancelled) return;
        const pNames = new Map<number, string>();
        for (const p of rawProducts.map(toProduct)) pNames.set(p.id, p.name);
        const cNames = new Map<number, string>();
        rawCompanies.forEach((raw: { name: string }, i: number) =>
          cNames.set(ids[i], String(raw.name)),
        );
        setProductNames(pNames);
        setCompanyNames(cNames);
      } catch {
        // 🇪🇸 best-effort: fallback "#id" en la tabla.
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [key, read]);

  return { productNames, companyNames };
}
