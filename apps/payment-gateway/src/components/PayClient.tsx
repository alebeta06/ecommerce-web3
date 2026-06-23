"use client";

import { useState } from "react";
import { useWallet } from "@/hooks/useWallet";
import { useEcommerce } from "@/hooks/useEcommerce";
import { useInvoices } from "@/hooks/useInvoices";
import { useEuroTokenBalance } from "@/hooks/useEuroTokenBalance";
import { getEuroTokenContract } from "@/lib/contracts";
import { env } from "@/lib/env";
import { formatEurt } from "@/lib/format";
import { friendlyError } from "@/lib/errors";

type PayStatus = "idle" | "approving" | "paying" | "done" | "error";

interface PayClientProps {
  invoiceIds: number[];
  redirect: string;
}

export function PayClient({ invoiceIds, redirect }: PayClientProps) {
  const { address, isConnected, isWrongNetwork, signer } = useWallet();
  const { invoices, isLoading, error } = useInvoices(invoiceIds);
  const { balance } = useEuroTokenBalance(address);
  const { write } = useEcommerce();

  const [status, setStatus] = useState<PayStatus>("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const total = invoices.reduce((acc, inv) => acc + inv.total, 0n);
  const hasPaid = invoices.some((inv) => inv.isPaid);
  const insufficient = balance !== null && balance < total;
  const inFlight = status === "approving" || status === "paying" || status === "done";

  async function onPay() {
    if (!signer || !write) return;
    setErrorMsg(null);
    try {
      setStatus("approving");
      const euroToken = getEuroTokenContract(signer);
      // 🇪🇸 approve EXACTO del total (no MaxUint256) — decisión de seguridad: Ecommerce solo queda
      // autorizado a mover justo lo que se paga ahora.
      const approveTx = await euroToken.approve(env.ecommerceAddress, total);
      await approveTx.wait();

      setStatus("paying");
      // 🇪🇸 processBatchPayments recibe uint256[]; pasamos los ids como BigInt[].
      const payTx = await write.processBatchPayments(invoiceIds.map((id) => BigInt(id)));
      await payTx.wait();

      setStatus("done");
      // 🇪🇸 Navegación CROSS-ORIGIN de vuelta a la tienda: window.location.href, NO router.push.
      window.location.href = redirect;
    } catch (err) {
      setErrorMsg(friendlyError(err));
      setStatus("idle");
    }
  }

  const payDisabled =
    !isConnected || isWrongNetwork || insufficient || inFlight || isLoading || invoices.length === 0;

  let buttonLabel: string;
  if (status === "approving") buttonLabel = "Approving…";
  else if (status === "paying") buttonLabel = "Processing payment…";
  else if (status === "done") buttonLabel = "Done — redirecting…";
  else buttonLabel = `Pay ${formatEurt(total)}`;

  let guardMessage: string | null = null;
  if (!isConnected) guardMessage = "Connect your wallet to pay.";
  else if (isWrongNetwork) guardMessage = "Switch to the correct network.";
  else if (insufficient) guardMessage = "Insufficient balance.";

  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-2xl font-bold text-fg">Pay invoices</h1>

      {isLoading ? (
        <p className="mt-4 text-muted">Loading invoices…</p>
      ) : error !== null ? (
        <p className="mt-4 text-red-400">{error}</p>
      ) : (
        <>
          {hasPaid ? (
            <p className="mt-4 rounded-md bg-yellow-500/15 px-3 py-2 text-sm text-yellow-300">
              Some invoices are already paid. You can still continue (this may be a partial payment).
            </p>
          ) : null}

          <ul className="mt-4 space-y-3">
            {invoices.map((inv) => (
              <li key={inv.id} className="rounded-md border border-line bg-card p-4">
                <div className="flex items-center justify-between">
                  <span className="font-medium text-fg">
                    Invoice #{inv.id} · Company {inv.companyId}
                  </span>
                  <span className="flex items-center gap-3">
                    <span className="font-mono text-fg">{formatEurt(inv.total)}</span>
                    {inv.isPaid ? (
                      <span className="rounded-md bg-success/15 px-2 py-0.5 text-xs text-success">
                        Paid
                      </span>
                    ) : null}
                  </span>
                </div>
                <ul className="mt-2 space-y-1 text-sm text-muted">
                  {inv.lines.map((line, i) => (
                    <li key={i}>
                      Product {line.productId} — {line.quantity.toString()} × {formatEurt(line.unitPrice)}
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>

          <div className="mt-6 rounded-md border border-line bg-card p-4">
            <div className="flex justify-between text-fg">
              <span className="font-medium">Total</span>
              <span className="font-mono font-semibold">{formatEurt(total)}</span>
            </div>
            <div className="mt-1 flex justify-between text-sm text-muted">
              <span>Your balance</span>
              <span className="font-mono">{balance === null ? "—" : formatEurt(balance)}</span>
            </div>
          </div>

          {errorMsg !== null ? <p className="mt-4 text-sm text-red-400">{errorMsg}</p> : null}
          {guardMessage !== null ? <p className="mt-4 text-sm text-muted">{guardMessage}</p> : null}

          <button
            type="button"
            onClick={() => void onPay()}
            disabled={payDisabled}
            className="mt-4 w-full rounded-md bg-accent px-4 py-3 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
          >
            {buttonLabel}
          </button>
        </>
      )}
    </main>
  );
}
