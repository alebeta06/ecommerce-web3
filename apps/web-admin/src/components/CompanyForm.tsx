"use client";

import { useState } from "react";
import { isAddress, type ContractTransactionResponse } from "ethers";
import { useEcommerce } from "@/hooks/useEcommerce";
import { useWallet } from "@/hooks/useWallet";
import { shortenAddress } from "@/lib/format";
import { friendlyError } from "@/lib/errors";

type TxStatus = "idle" | "pending" | "success" | "error";

export function CompanyForm({ onRegistered }: { onRegistered: () => void }) {
  const { write } = useEcommerce();
  const { address } = useWallet();
  const [name, setName] = useState("");
  const [payoutWallet, setPayoutWallet] = useState("");
  const [status, setStatus] = useState<TxStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);

  // 🇪🇸 Sin wallet conectada no hay signer (write === null) ni owner: no mostramos el form.
  if (write === null || address === null) {
    return (
      <p className="rounded-md border border-line bg-card p-4 text-sm text-muted">
        Connect wallet first to register a company.
      </p>
    );
  }

  // 🇪🇸 NOTA: TS no propaga el narrowing del guard a funciones anidadas; fijamos consts ya
  // no-nulables para que el closure onSubmit vea el Contract/address sin posible null.
  const contract = write;
  const owner = address;

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    // 🇪🇸 Validación en el boundary antes de gastar gas: nombre no vacío + address válida.
    if (name.trim() === "") {
      setStatus("error");
      setMessage("Name is required.");
      return;
    }
    if (!isAddress(payoutWallet)) {
      setStatus("error");
      setMessage("Payout wallet is not a valid address.");
      return;
    }
    setStatus("pending");
    setMessage(null);
    try {
      // 🇪🇸 contract y owner ya son no-nulables (fijados tras el guard).
      const tx = (await contract.registerCompany(
        owner,
        name.trim(),
        payoutWallet,
      )) as ContractTransactionResponse;
      await tx.wait(); // 🇪🇸 espera a que la tx mine
      setStatus("success");
      setMessage("Company registered.");
      setName("");
      setPayoutWallet("");
      onRegistered(); // 🇪🇸 refetch de la lista
    } catch (err) {
      setStatus("error");
      setMessage(friendlyError(err));
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3 rounded-md border border-line bg-card p-4">
      <h2 className="text-sm font-semibold text-fg">Register company</h2>
      <p className="text-xs text-muted">
        Owner: <span className="font-mono">{shortenAddress(address)}</span> (connected wallet)
      </p>
      <input
        type="text"
        placeholder="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg placeholder:text-muted"
      />
      <input
        type="text"
        placeholder="Payout wallet (0x...)"
        value={payoutWallet}
        onChange={(e) => setPayoutWallet(e.target.value)}
        className="rounded-md border border-line bg-input px-3 py-2 font-mono text-sm text-fg placeholder:text-muted"
      />
      <button
        type="submit"
        disabled={status === "pending"}
        className="rounded-md bg-accent px-4 py-2 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
      >
        {status === "pending" ? "Registering…" : "Register"}
      </button>
      {message !== null ? (
        <span className={`text-xs ${status === "error" ? "text-red-400" : "text-success"}`}>
          {message}
        </span>
      ) : null}
    </form>
  );
}
