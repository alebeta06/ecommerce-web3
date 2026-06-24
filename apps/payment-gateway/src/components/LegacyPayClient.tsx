"use client";

import { useState } from "react";
import { useWallet } from "@/hooks/useWallet";
import { useEuroTokenBalance } from "@/hooks/useEuroTokenBalance";
import { getEuroTokenContract } from "@/lib/contracts";
import { formatEurt, parseEurt, shortenAddress } from "@/lib/format";
import { friendlyError } from "@/lib/errors";

type LegacyStatus = "idle" | "approving" | "done" | "error";

interface LegacyPayClientProps {
  merchantAddress: string;
  amount: number;
  invoice: string;
  date: string;
  redirect: string;
}

function Row({
  label,
  value,
  mono,
  wrap,
}: {
  label: string;
  value: string;
  mono?: boolean;
  wrap?: boolean;
}) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-muted">{label}</span>
      <span className={`text-fg ${mono ? "font-mono" : ""} ${wrap ? "break-all text-xs" : ""}`}>
        {value}
      </span>
    </div>
  );
}

export function LegacyPayClient({
  merchantAddress,
  amount,
  invoice,
  date,
  redirect,
}: LegacyPayClientProps) {
  const { address, isConnected, isWrongNetwork, signer } = useWallet();
  const { balance } = useEuroTokenBalance(address);

  const [status, setStatus] = useState<LegacyStatus>("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  // 🇪🇸 amount es EUR (entero o decimal); a base units de 6 decimales con parseEurt.
  const total = parseEurt(String(amount));
  const insufficient = balance !== null && balance < total;
  const inFlight = status === "approving" || status === "done";

  async function onPay() {
    if (!signer) return;
    setErrorMsg(null);
    try {
      // 🇪🇸 Formato legacy: transferencia ERC20 DIRECTA al comerciante. No hay invoice on-chain ni
      // processBatchPayments; transfer mueve los EURT del comprador al merchant en una sola tx.
      setStatus("approving");
      const euroToken = getEuroTokenContract(signer);
      const tx = await euroToken.transfer(merchantAddress, total);
      await tx.wait();
      setTxHash(tx.hash);
      setStatus("done");
      window.location.href = redirect; // 🇪🇸 cross-origin de vuelta al origen del link.
    } catch (err) {
      setErrorMsg(friendlyError(err));
      setStatus("error");
    }
  }

  const payDisabled = !isConnected || isWrongNetwork || insufficient || inFlight;

  let guardMessage: string | null = null;
  if (!isConnected) guardMessage = "Connect your wallet to pay.";
  else if (isWrongNetwork) guardMessage = "Switch to the correct network.";
  else if (insufficient) guardMessage = "Insufficient balance.";

  if (status === "done") {
    return (
      <main className="mx-auto max-w-2xl p-8">
        <h1 className="text-2xl font-bold text-success">✓ ¡Pago Completado!</h1>
        <p className="mt-2 text-muted">Redirecting…</p>
        <dl className="mt-6 space-y-2 rounded-md border border-line bg-card p-4 text-sm">
          <Row label="Comerciante" value={shortenAddress(merchantAddress)} mono />
          <Row label="Cantidad" value={`${amount} EURT`} />
          <Row label="Factura" value={invoice} />
          <Row label="Fecha" value={date} />
          {txHash !== null ? <Row label="Tx hash" value={txHash} mono wrap /> : null}
        </dl>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-2xl font-bold text-fg">Pay merchant</h1>

      <dl className="mt-4 space-y-2 rounded-md border border-line bg-card p-4 text-sm">
        <Row label="Comerciante" value={shortenAddress(merchantAddress)} mono />
        <Row label="Cantidad" value={`${amount} EURT`} />
        <Row label="Factura" value={invoice} />
        <Row label="Fecha" value={date} />
      </dl>

      <div className="mt-4 flex justify-between rounded-md border border-line bg-card p-4 text-sm">
        <span className="text-muted">Your balance</span>
        <span className="font-mono text-fg">{balance === null ? "—" : formatEurt(balance)}</span>
      </div>

      {errorMsg !== null ? <p className="mt-4 text-sm text-red-400">{errorMsg}</p> : null}
      {guardMessage !== null ? <p className="mt-4 text-sm text-muted">{guardMessage}</p> : null}

      <button
        type="button"
        onClick={() => void onPay()}
        disabled={payDisabled}
        className="mt-4 w-full rounded-md bg-accent px-4 py-3 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
      >
        {status === "approving" ? "Processing…" : `Pagar ${amount} EURT`}
      </button>
    </main>
  );
}
