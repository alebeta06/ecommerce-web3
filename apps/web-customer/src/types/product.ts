// 🇪🇸 NOTA: refleja el struct ProductLib.Product del contrato. read.getAllProducts()/getProduct()
// devuelven un Result dinámico de ethers (tuple con campos nombrados); toProduct aísla AQUÍ el
// casteo a tipos TS para que el resto de la app no toque `any`.
// 🇪🇸 price y stock se mantienen como bigint: son montos/cantidades on-chain (price en base units
// de 6 decimales). Convertirlos a number perdería precisión; el formateo a "€X.XX" se hace al mostrar.
export interface Product {
  id: number;
  companyId: number;
  name: string;
  ipfsCid: string;
  price: bigint;
  stock: bigint;
  active: boolean;
}

export function toProduct(raw: {
  id: bigint;
  companyId: bigint;
  name: string;
  ipfsCid: string;
  price: bigint;
  stock: bigint;
  active: boolean;
}): Product {
  return {
    id: Number(raw.id),
    companyId: Number(raw.companyId),
    name: String(raw.name),
    ipfsCid: String(raw.ipfsCid),
    price: raw.price,
    stock: raw.stock,
    active: Boolean(raw.active),
  };
}
