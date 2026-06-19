// 🇪🇸 NOTA: refleja el struct CartLib.CartItem del contrato. read.getCart() devuelve un Result
// dinámico de ethers (tuple con campos nombrados); toCartItem aísla AQUÍ el casteo a tipos TS
// para que el resto de la app no toque `any`.
// 🇪🇸 quantity se mantiene como bigint: es una cantidad on-chain. companyId/productId pasan a
// number (son ids de negocio, no montos).
export interface CartItem {
  companyId: number;
  productId: number;
  quantity: bigint;
}

export function toCartItem(raw: {
  companyId: bigint;
  productId: bigint;
  quantity: bigint;
}): CartItem {
  return {
    companyId: Number(raw.companyId),
    productId: Number(raw.productId),
    quantity: raw.quantity,
  };
}
