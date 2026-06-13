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
          className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {isConnecting ? "Connecting…" : "Connect wallet"}
        </button>
        {error !== null ? <span className="text-xs text-red-600">{error}</span> : null}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3">
      {isWrongNetwork ? (
        <span className="rounded-md bg-red-100 px-2 py-1 text-xs font-medium text-red-700">
          Wrong network — switch to Anvil (31337)
        </span>
      ) : null}
      <span className="rounded-md bg-gray-100 px-3 py-1 font-mono text-sm text-gray-800">
        {shortenAddress(address)}
      </span>
      <button
        type="button"
        onClick={disconnect}
        className="rounded-md border border-gray-300 px-3 py-1 text-sm text-gray-700 hover:bg-gray-50"
      >
        Disconnect
      </button>
    </div>
  );
}
