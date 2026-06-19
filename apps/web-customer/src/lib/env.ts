// 🇪🇸 NOTA: validación de las env vars públicas en el "boundary" del sistema (CLAUDE.md: validar
// la entrada en los límites). Centraliza el acceso a process.env: si falta una variable crítica
// fallamos rápido con un mensaje claro, en vez de propagar `undefined` por toda la app.
// Solo NEXT_PUBLIC_* (disponibles tanto en cliente como en servidor).

function required(name: string, value: string | undefined): string {
  if (value === undefined || value.trim() === "") {
    throw new Error(`Missing required env var: ${name}. See apps/web-customer/.env.example.`);
  }
  return value;
}

export const env = {
  rpcUrl: required("NEXT_PUBLIC_RPC_URL", process.env.NEXT_PUBLIC_RPC_URL),
  chainId: Number(required("NEXT_PUBLIC_CHAIN_ID", process.env.NEXT_PUBLIC_CHAIN_ID)),
  ecommerceAddress: required(
    "NEXT_PUBLIC_ECOMMERCE_ADDRESS",
    process.env.NEXT_PUBLIC_ECOMMERCE_ADDRESS,
  ),
  euroTokenAddress: required(
    "NEXT_PUBLIC_EURO_TOKEN_ADDRESS",
    process.env.NEXT_PUBLIC_EURO_TOKEN_ADDRESS,
  ),
  // 🇪🇸 URL de la pasarela de pago (app payment-gateway, :6002). El checkout redirige aquí para
  // pagar. Tiene default razonable; no es crítica para arrancar la app.
  paymentGatewayUrl: process.env.NEXT_PUBLIC_PAYMENT_GATEWAY_URL ?? "http://localhost:6002",
  // 🇪🇸 El gateway IPFS tiene default razonable; no es crítico para arrancar.
  ipfsGateway: process.env.NEXT_PUBLIC_IPFS_GATEWAY ?? "https://gateway.pinata.cloud/ipfs/",
} as const;
