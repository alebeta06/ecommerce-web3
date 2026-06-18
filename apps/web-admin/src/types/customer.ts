// 🇪🇸 NOTA: refleja el struct CustomerLib.Customer del contrato. read.getCustomer() devuelve un
// Result dinámico de ethers (tuple con campos nombrados); toCustomer aísla AQUÍ el casteo a tipos TS
// para que el resto de la app no toque `any` (mismo patrón que toInvoice / toCompany).
// 🇪🇸 createdAt se mantiene como bigint: es un timestamp on-chain (segundos unix). El formateo a
// fecha legible se hace al mostrar (lib/format.ts → formatTimestamp). wallet/name son strings y
// registered un bool (centinela de existencia del struct).

export interface Customer {
  wallet: string;
  name: string;
  registered: boolean;
  createdAt: bigint;
}

export function toCustomer(raw: {
  wallet: string;
  name: string;
  registered: boolean;
  createdAt: bigint;
}): Customer {
  return {
    wallet: String(raw.wallet),
    name: String(raw.name),
    registered: Boolean(raw.registered),
    createdAt: raw.createdAt,
  };
}
