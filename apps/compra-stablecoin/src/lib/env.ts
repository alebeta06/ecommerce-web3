// 🇪🇸 NOTA: validación de las env vars PÚBLICAS en el "boundary" del sistema (CLAUDE.md: validar la
// entrada en los límites). Centraliza el acceso a process.env: si falta una variable crítica fallamos
// rápido con un mensaje claro, en vez de propagar `undefined` por toda la app.
// IMPORTANTE: este módulo lo importa el CLIENTE, así que aquí solo van NEXT_PUBLIC_*. Las server-only
// (STRIPE_SECRET_KEY, WALLET_PRIVATE_KEY, RPC_URL) se leen directamente con process.env en las API
// routes — nunca acá — para no exponerlas al bundle del navegador.

function required(name: string, value: string | undefined): string {
  if (value === undefined || value.trim() === "") {
    throw new Error(`Missing required env var: ${name}. See apps/compra-stablecoin/.env.example.`);
  }
  return value;
}

export const env = {
  stripePublishableKey: required(
    "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY",
    process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
  ),
  euroTokenAddress: required(
    "NEXT_PUBLIC_EUROTOKEN_ADDRESS",
    process.env.NEXT_PUBLIC_EUROTOKEN_ADDRESS,
  ),
  rpcUrl: required("NEXT_PUBLIC_RPC_URL", process.env.NEXT_PUBLIC_RPC_URL),
  chainId: Number(required("NEXT_PUBLIC_CHAIN_ID", process.env.NEXT_PUBLIC_CHAIN_ID)),
  paymentGatewayUrl: required(
    "NEXT_PUBLIC_PAYMENT_GATEWAY_URL",
    process.env.NEXT_PUBLIC_PAYMENT_GATEWAY_URL,
  ),
} as const;
