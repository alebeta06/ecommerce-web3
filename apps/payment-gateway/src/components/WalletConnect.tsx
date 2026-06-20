"use client";

import { useWallet } from "@/hooks/useWallet";
import { shortenAddress } from "@/lib/format";

export function WalletConnect() {
  const { address, isConnecting, isWrongNetwork, error, connect, disconnect } = useWallet();

  // 🇪🇸 Comparamos con `address === null` (no con isConnected) para que TypeScript estreche el
  // tipo a `string` en el resto del componente.
  if (address === null) {
    return (
      <div className="flex flex-col items-end gap-1">
        <button
          type="button"
          onClick={() => void connect()}
          disabled={isConnecting}
          className="rounded-md bg-accent px-4 py-2 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
        >
          {isConnecting ? "Connecting…" : "Connect wallet"}
        </button>
        {error !== null ? <span className="text-xs text-red-400">{error}</span> : null}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3">
      {isWrongNetwork ? (
        <span className="rounded-md bg-red-500/15 px-2 py-1 text-xs font-medium text-red-300">
          Wrong network — switch to Anvil (31337)
        </span>
      ) : null}
      <span className="rounded-md border border-line bg-bg px-3 py-1.5 font-mono text-xs text-fg">
        {shortenAddress(address)}
      </span>
      <button
        type="button"
        onClick={disconnect}
        className="rounded-md border border-line bg-transparent px-3 py-1 text-sm text-muted hover:bg-card hover:text-fg"
      >
        Disconnect
      </button>
    </div>
  );
}
