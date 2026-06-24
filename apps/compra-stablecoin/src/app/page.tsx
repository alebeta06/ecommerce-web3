"use client";

import { useState } from "react";
import { Elements } from "@stripe/react-stripe-js";
import { useWallet } from "@/hooks/useWallet";
import { useEuroTokenBalance } from "@/hooks/useEuroTokenBalance";
import { stripePromise } from "@/lib/stripe";
import { formatEurt, shortenAddress } from "@/lib/format";
import { env } from "@/lib/env";
import { CheckoutForm } from "@/components/CheckoutForm";

type Status = "idle" | "creating" | "paying" | "minting" | "success" | "error";

export default function BuyStablecoinPage() {
  const { address, isConnected, isWrongNetwork, isConnecting, connect } = useWallet();
  const { balance, refetch } = useEuroTokenBalance(address);

  const [amountEur, setAmountEur] = useState<number>(10);
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const amountValid = Number.isInteger(amountEur) && amountEur >= 10 && amountEur <= 10000;

  async function startPayment() {
    if (!address || !amountValid) return;
    setStatus("creating");
    setErrorMsg(null);
    try {
      const res = await fetch("/api/create-payment-intent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ amountEur, walletAddress: address }),
      });
      const data = (await res.json()) as { clientSecret?: string; error?: string };
      if (!res.ok || !data.clientSecret) {
        throw new Error(data.error ?? "Could not start the payment.");
      }
      setClientSecret(data.clientSecret);
      setStatus("paying");
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : "Could not start the payment.");
      setStatus("error");
    }
  }

  async function onPaid(paymentIntentId: string) {
    if (!address) return;
    setStatus("minting");
    setErrorMsg(null);
    try {
      const res = await fetch("/api/mint-tokens", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ paymentIntentId, walletAddress: address, amountEur }),
      });
      const data = (await res.json()) as { txHash?: string; error?: string };
      if (!res.ok || !data.txHash) {
        throw new Error(data.error ?? "The mint failed.");
      }
      setTxHash(data.txHash);
      setStatus("success");
      void refetch();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : "The mint failed.");
      setStatus("error");
    }
  }

  function openGateway() {
    // 🇪🇸 Demo: redirige a la pasarela con el FORMATO LEGACY (merchant_address). Lo soporta el
    // Commit 3 de payment-gateway; hasta entonces mostrará "Invalid payment link".
    const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const params = new URLSearchParams({
      merchant_address: env.euroTokenAddress,
      amount: "10",
      invoice: "INV-TEST",
      date,
      redirect: "http://localhost:6001",
    });
    window.location.href = `${env.paymentGatewayUrl}?${params.toString()}`;
  }

  return (
    <div className="mx-auto max-w-5xl p-8">
      <button
        type="button"
        onClick={openGateway}
        className="mb-6 rounded-md border border-line bg-card px-4 py-2 text-sm text-fg hover:bg-accent-2"
      >
        Probar Pasarela de Pago (10 EURT)
      </button>

      <div className="grid gap-6 md:grid-cols-2">
        {/* ── Izquierda: Detalles de la Compra ─────────────────────────── */}
        <section className="rounded-lg border border-line bg-card p-6">
          <h2 className="text-lg font-semibold text-fg">Detalles de la Compra</h2>

          <div className="mt-4 rounded-md border border-line bg-bg p-4">
            <p className="font-medium text-fg">EuroToken (EURT)</p>
            <p className="mt-1 text-sm text-muted">Stablecoin respaldada 1:1 con EUR</p>
          </div>

          <label className="mt-6 block text-sm font-medium text-fg" htmlFor="amount">
            Cantidad a Comprar (EUR)
          </label>
          <div className="mt-2 flex items-center rounded-md border border-line bg-input px-3">
            <span className="text-muted">€</span>
            <input
              id="amount"
              type="number"
              min={10}
              max={10000}
              step={1}
              value={Number.isNaN(amountEur) ? "" : amountEur}
              onChange={(e) => setAmountEur(Number(e.target.value))}
              disabled={clientSecret !== null}
              className="w-full bg-transparent px-2 py-2 text-fg outline-none disabled:opacity-60"
            />
          </div>
          {!amountValid ? (
            <p className="mt-1 text-xs text-red-400">La cantidad debe ser un entero entre 10 y 10000.</p>
          ) : null}

          <div className="mt-6 space-y-1 border-t border-line pt-4 text-sm">
            <div className="flex justify-between">
              <span className="text-muted">Tokens a recibir</span>
              <span className="font-mono text-fg">{amountValid ? amountEur : 0} EURT</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted">Tasa de cambio</span>
              <span className="text-fg">1 EUR = 1 EURT</span>
            </div>
          </div>
        </section>

        {/* ── Derecha: Información de Pago / Éxito ──────────────────────── */}
        <section className="rounded-lg border border-line bg-card p-6">
          {status === "success" ? (
            <div className="flex flex-col gap-3">
              <h2 className="text-lg font-semibold text-success">✓ ¡Pago Exitoso!</h2>
              <p className="text-sm text-muted">Transacción completada exitosamente</p>
              <div className="mt-2 space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted">Cantidad</span>
                  <span className="font-mono text-fg">{amountEur} EURT</span>
                </div>
                <div className="flex justify-between gap-4">
                  <span className="text-muted">Dirección de destino</span>
                  <span className="font-mono text-fg">{address ? shortenAddress(address) : "—"}</span>
                </div>
                {txHash !== null ? (
                  <div className="flex justify-between gap-4">
                    <span className="text-muted">Tx hash</span>
                    <span className="break-all font-mono text-xs text-fg">{txHash}</span>
                  </div>
                ) : null}
                <div className="flex justify-between border-t border-line pt-2">
                  <span className="text-muted">Balance EURT</span>
                  <span className="font-mono text-fg">{balance === null ? "—" : formatEurt(balance)}</span>
                </div>
              </div>
            </div>
          ) : (
            <>
              <h2 className="text-lg font-semibold text-fg">Información de Pago</h2>

              {!isConnected ? (
                <button
                  type="button"
                  onClick={() => void connect()}
                  disabled={isConnecting}
                  className="mt-4 w-full rounded-md bg-accent px-4 py-3 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
                >
                  {isConnecting ? "Conectando…" : "Conectar MetaMask"}
                </button>
              ) : (
                <>
                  <div className="mt-4 rounded-md border border-line bg-bg p-3 text-sm">
                    <p className="flex items-center gap-2 text-fg">
                      <span className="text-success">●</span> Billetera Conectada
                    </p>
                    <p className="mt-1 font-mono text-muted">{address ? shortenAddress(address) : ""}</p>
                    <p className="mt-1 text-muted">
                      Balance:{" "}
                      <span className="font-mono text-fg">
                        {balance === null ? "—" : formatEurt(balance)}
                      </span>
                    </p>
                  </div>

                  {isWrongNetwork ? (
                    <p className="mt-4 text-sm text-red-400">
                      Switch to the correct network (Anvil 31337).
                    </p>
                  ) : clientSecret === null ? (
                    <button
                      type="button"
                      onClick={() => void startPayment()}
                      disabled={!amountValid || status === "creating"}
                      className="mt-4 w-full rounded-md bg-accent px-4 py-3 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
                    >
                      {status === "creating" ? "Preparando pago…" : `Pagar €${amountValid ? amountEur : "—"}`}
                    </button>
                  ) : (
                    <div className="mt-4">
                      <Elements stripe={stripePromise} options={{ clientSecret }}>
                        <CheckoutForm amountEur={amountEur} onPaid={(id) => void onPaid(id)} />
                      </Elements>
                      {status === "minting" ? (
                        <p className="mt-3 text-sm text-muted">Minteando EURT on-chain…</p>
                      ) : null}
                    </div>
                  )}
                </>
              )}

              {errorMsg !== null ? <p className="mt-4 text-sm text-red-400">{errorMsg}</p> : null}
            </>
          )}
        </section>
      </div>
    </div>
  );
}
