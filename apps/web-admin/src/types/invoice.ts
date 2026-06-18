// 🇪🇸 NOTA: refleja el struct InvoiceLib.Invoice del contrato. read.getInvoice() devuelve un Result
// dinámico de ethers (tuple con campos nombrados, incl. un array anidado de líneas); toInvoice aísla
// AQUÍ el casteo a tipos TS para que el resto de la app no toque `any`.
// 🇪🇸 quantity/unitPrice/total se mantienen como bigint: son cantidades/montos on-chain (montos en
// base units de 6 decimales). Convertirlos a number perdería precisión; el formateo a "€X.XX" se
// hace al mostrar. id/companyId/productId sí pasan a number (son ids de negocio, no montos).

export interface InvoiceLine {
  productId: number;
  quantity: bigint;
  unitPrice: bigint;
}

export interface Invoice {
  id: number;
  customer: string;
  companyId: number;
  lines: InvoiceLine[];
  total: bigint;
  createdAt: bigint;
  isPaid: boolean;
}

export function toInvoiceLine(raw: {
  productId: bigint;
  quantity: bigint;
  unitPrice: bigint;
}): InvoiceLine {
  return {
    productId: Number(raw.productId),
    quantity: raw.quantity,
    unitPrice: raw.unitPrice,
  };
}

export function toInvoice(raw: {
  id: bigint;
  customer: string;
  companyId: bigint;
  lines: { productId: bigint; quantity: bigint; unitPrice: bigint }[];
  total: bigint;
  createdAt: bigint;
  isPaid: boolean;
}): Invoice {
  return {
    id: Number(raw.id),
    customer: String(raw.customer),
    companyId: Number(raw.companyId),
    lines: raw.lines.map(toInvoiceLine),
    total: raw.total,
    createdAt: raw.createdAt,
    isPaid: Boolean(raw.isPaid),
  };
}
