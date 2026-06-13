// 🇪🇸 NOTA: helpers de formato puros (sin estado). shortenAddress abrevia una dirección al estilo
// 0x1234...5678 (primeros 6 + últimos 4). Reutilizado por el header (WalletConnect) y las tablas.
export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}
