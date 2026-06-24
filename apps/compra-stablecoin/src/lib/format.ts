import { formatUnits, parseUnits } from "ethers";

// 🇪🇸 NOTA: helpers de formato puros (sin estado). shortenAddress abrevia una dirección al estilo
// 0x1234...5678 (primeros 6 + últimos 4). Reutilizado por el header (WalletConnect) y las tablas.
export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// 🇪🇸 NOTA: EURT tiene 6 decimales (como USDC). On-chain los importes son enteros en "base units"
// (1 € = 1_000_000). formatEurt los pasa a "€X.XX" para mostrar; parseEurt hace el camino inverso
// (string de euros → bigint base units) antes de enviar la tx. Centralizamos el "6" mágico aquí
// para no esparcirlo por List y Form.
const EURT_DECIMALS = 6;

export function formatEurt(amount: bigint): string {
  // 🇪🇸 toFixed(2) fuerza siempre 2 decimales de display (€12.50, €12.00) en vez del crudo de
  // formatUnits (€12.5, €12). El float intermedio solo afecta la presentación, nunca el valor on-chain.
  return `€${Number(formatUnits(amount, EURT_DECIMALS)).toFixed(2)}`;
}

export function parseEurt(euros: string): bigint {
  return parseUnits(euros, EURT_DECIMALS);
}

// 🇪🇸 NOTA: convierte un timestamp on-chain (segundos unix, bigint — p.ej. Customer.createdAt) a una
// fecha legible según el locale del navegador. Multiplicamos por 1000 porque JS Date usa milisegundos.
// Centralizado aquí para reutilizarlo en cualquier vista que muestre fechas on-chain.
export function formatTimestamp(ts: bigint): string {
  return new Date(Number(ts) * 1000).toLocaleDateString();
}
