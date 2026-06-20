// 🇪🇸 NOTA: traduce los reverts del contrato (custom errors) a mensajes claros para personas no
// técnicas. ethers v6 a veces NO decodifica el custom error y muestra "unknown custom error" + la
// data cruda (0x...); por eso extraemos nosotros el selector (primeros 4 bytes) y lo mapeamos.
// Robusto e independiente de cómo ethers anide la revert data.

// 🇪🇸 selector (4 bytes, keccak de la firma del error) → mensaje humano. Incluimos los errores
// alcanzables desde web-customer (carrito, checkout, registro de cliente) además de los de
// producto/empresa heredados. Calculados con `cast sig`.
const ERROR_BY_SELECTOR: Record<string, string> = {
  // CompanyLib
  "0x2ef13105": "The name cannot be empty.", // EmptyName()
  "0x49e27cff": "The owner address is not valid.", // InvalidOwner()
  "0xc41cbee2": "The payout wallet address is not valid.", // InvalidPayoutWallet()
  "0x39be3236": "That company does not exist.", // CompanyNotFound(uint256)
  // Ecommerce
  "0xc33d1810": "You are not the owner of this company, so you cannot manage its products.", // NotCompanyOwner
  "0xab48656e": "That product does not belong to this company.", // ProductCompanyMismatch
  // ProductLib
  "0x00bfc921": "The price must be greater than zero.", // InvalidPrice()
  "0xffb02c70": "The image reference (IPFS CID) is required.", // EmptyIpfsCid()
  "0xfe42c219": "The image reference (IPFS CID) is not valid — it must be at least 46 characters.", // InvalidIpfsCidLength()
  "0x92691cab": "That product does not exist.", // ProductNotFound(uint256)
  "0x6fb8167b": "That product is inactive.", // ProductInactive(uint256)
  "0xb88528e4": "There is not enough stock for that product.", // InsufficientStock
  // CartLib
  "0x3d560c9b": "That item is not in your cart.", // ItemNotInCart(uint256,uint256)
  "0x524f409b": "The quantity is not valid.", // InvalidQuantity()
  // CustomerLib
  "0xba03d6bf": "You are not registered as a customer yet.", // CustomerNotFound(address)
  "0xe0f004dc": "You are already registered.", // CustomerAlreadyRegistered(address)
  // Ecommerce (checkout)
  "0x89a0016e": "Your cart is empty.", // EmptyCart()
  "0xc2e5347d": "The request was empty.", // EmptyBatch()
  "0x36cab380": "This invoice does not belong to you.", // NotInvoiceCustomer(uint256,address)
  // OpenZeppelin AccessControl
  "0xe2517d3f": "You don't have permission for this action. Only the platform admin can register companies.", // AccessControlUnauthorizedAccount
};

function asRecord(v: unknown): Record<string, unknown> | null {
  return typeof v === "object" && v !== null ? (v as Record<string, unknown>) : null;
}

function hexSelector(v: unknown): string | null {
  return typeof v === "string" && v.startsWith("0x") && v.length >= 10
    ? v.slice(0, 10).toLowerCase()
    : null;
}

// 🇪🇸 ethers v6 mete la revert data en distintos sitios según el provider; probamos los habituales
// y, como último recurso, buscamos un 0x******** dentro del mensaje serializado.
function extractSelector(err: unknown): string | null {
  const e = asRecord(err);
  if (e) {
    const info = asRecord(e.info);
    const infoError = info ? asRecord(info.error) : null;
    const nested = asRecord(e.error);
    const found =
      hexSelector(e.data) ??
      (infoError ? hexSelector(infoError.data) : null) ??
      (nested ? hexSelector(nested.data) : null);
    if (found !== null) return found;
  }
  const msg = err instanceof Error ? err.message : String(err);
  const match = msg.match(/0x[0-9a-fA-F]{8}/);
  return match ? match[0].toLowerCase() : null;
}

// 🇪🇸 Punto de entrada: del error de ethers a un string mostrable. Prioridad:
// 1) usuario rechazó la firma  2) custom error conocido  3) fallback legible.
export function friendlyError(err: unknown): string {
  const e = asRecord(err);
  if (e && (e.code === "ACTION_REJECTED" || e.code === 4001)) {
    return "You rejected the transaction in your wallet.";
  }
  const selector = extractSelector(err);
  if (selector !== null) {
    const known = ERROR_BY_SELECTOR[selector];
    if (known !== undefined) return known;
  }
  return "The transaction could not be completed. Please check your inputs and try again.";
}
