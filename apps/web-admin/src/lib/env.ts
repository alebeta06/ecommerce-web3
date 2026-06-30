// 🇪🇸 NOTA: validación de las env vars públicas en el "boundary" del sistema (CLAUDE.md: validar
// la entrada en los límites). Centraliza el acceso a process.env: si falta una variable crítica
// fallamos rápido con un mensaje claro, en vez de propagar `undefined` por toda la app.
// Solo NEXT_PUBLIC_* (disponibles tanto en cliente como en servidor).

function required(name: string, value: string | undefined): string {
  if (value === undefined || value.trim() === "") {
    throw new Error(`Missing required env var: ${name}. See apps/web-admin/.env.example.`);
  }
  return value;
}

const rpcUrl = required("NEXT_PUBLIC_RPC_URL", process.env.NEXT_PUBLIC_RPC_URL);

export const env = {
  rpcUrl,
  chainId: Number(required("NEXT_PUBLIC_CHAIN_ID", process.env.NEXT_PUBLIC_CHAIN_ID)),
  ecommerceAddress: required(
    "NEXT_PUBLIC_ECOMMERCE_ADDRESS",
    process.env.NEXT_PUBLIC_ECOMMERCE_ADDRESS,
  ),
  euroTokenAddress: required(
    "NEXT_PUBLIC_EURO_TOKEN_ADDRESS",
    process.env.NEXT_PUBLIC_EURO_TOKEN_ADDRESS,
  ),
  // 🇪🇸 El gateway IPFS tiene default razonable; no es crítico para arrancar.
  ipfsGateway: process.env.NEXT_PUBLIC_IPFS_GATEWAY ?? "https://gateway.pinata.cloud/ipfs/",
  // 🇪🇸 Nombre legible de la red esperada; fallback al chainId si no se define.
  networkName: process.env.NEXT_PUBLIC_NETWORK_NAME ?? `chain ${Number(process.env.NEXT_PUBLIC_CHAIN_ID)}`,
  // 🇪🇸 Bloque de despliegue del contrato: punto de arranque del escaneo de eventos. Empezar aquí
  // (no en 0) evita recorrer millones de bloques vacíos previos al deploy. Default 0 → Anvil, donde
  // el contrato vive casi desde el bloque 0. En Sepolia: 11146508.
  deployBlock: Number(process.env.NEXT_PUBLIC_DEPLOY_BLOCK ?? "0"),
  // 🇪🇸 Tamaño de ventana para paginar `eth_getLogs`. Default 10 = límite del free tier de Alchemy.
  // En Sepolia se sube (p.ej. 2000) JUNTO con logsRpcUrl=PublicNode, que admite rangos grandes.
  logWindowSize: Number(process.env.NEXT_PUBLIC_LOG_WINDOW_SIZE ?? "10"),
  // 🇪🇸 RPC dedicado al escaneo de logs. El free tier de Alchemy capa eth_getLogs a 10 bloques
  // (sin excepción por filtros), inviable para escanear ~890k bloques. Apuntamos el escaneo a un RPC
  // público que admite rangos grandes (PublicNode), dejando Alchemy para el resto de llamadas.
  // Opcional: si no se define, cae a rpcUrl → en Anvil usa el mismo nodo local (comportamiento idéntico).
  logsRpcUrl: process.env.NEXT_PUBLIC_LOGS_RPC_URL?.trim() || rpcUrl,
  // 🇪🇸 Nº máximo de peticiones eth_getLogs simultáneas durante el escaneo (throttle anti-429).
  logConcurrency: Number(process.env.NEXT_PUBLIC_LOG_CONCURRENCY ?? "4"),
} as const;
