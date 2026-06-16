"use client";

import { useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { useEcommerce } from "@/hooks/useEcommerce";
import { parseEurt } from "@/lib/format";
import { friendlyError } from "@/lib/errors";

type TxStatus = "idle" | "pending" | "success" | "error";

export function ProductForm({
  companyId,
  onAdded,
}: {
  companyId: number;
  onAdded: () => void;
}) {
  const { write } = useEcommerce();
  const [name, setName] = useState("");
  const [price, setPrice] = useState("");
  const [stock, setStock] = useState("");
  const [ipfsCid, setIpfsCid] = useState("");
  const [status, setStatus] = useState<TxStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);

  // 🇪🇸 Sin wallet conectada no hay signer (write === null): no mostramos el form.
  if (write === null) {
    return (
      <p className="rounded-md border border-gray-200 bg-gray-50 p-4 text-sm text-gray-600">
        Connect wallet first to add a product.
      </p>
    );
  }

  // 🇪🇸 NOTA: TS no propaga el narrowing del guard a funciones anidadas; fijamos una const ya
  // no-nulable para que el closure onSubmit vea el Contract sin posible null.
  const contract = write;

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    // 🇪🇸 Validación en el boundary antes de gastar gas.
    if (name.trim() === "") {
      setStatus("error");
      setMessage("Name is required.");
      return;
    }
    const priceNum = Number(price);
    if (!Number.isFinite(priceNum) || priceNum <= 0) {
      setStatus("error");
      setMessage("Price must be greater than 0.");
      return;
    }
    const stockNum = Number(stock);
    if (!Number.isInteger(stockNum) || stockNum < 0) {
      setStatus("error");
      setMessage("Stock must be a non-negative integer.");
      return;
    }
    if (ipfsCid.trim() === "") {
      setStatus("error");
      setMessage("IPFS CID is required.");
      return;
    }
    // 🇪🇸 El contrato (ProductLib) exige length >= 46 (un CIDv0 "Qm..." mide exactamente 46).
    // Validamos aquí para dar un mensaje claro en vez de un revert InvalidIpfsCidLength en estimateGas.
    if (ipfsCid.trim().length < 46) {
      setStatus("error");
      setMessage("IPFS CID looks invalid (expected at least 46 characters).");
      return;
    }
    setStatus("pending");
    setMessage(null);
    try {
      // 🇪🇸 parseEurt: euros (string) → bigint base units 6-dec. Orden del ABI:
      // addProduct(companyId, name, ipfsCid, price, stock).
      const tx = (await contract.addProduct(
        companyId,
        name.trim(),
        ipfsCid.trim(),
        parseEurt(price),
        BigInt(stock),
      )) as ContractTransactionResponse;
      await tx.wait(); // 🇪🇸 espera a que la tx mine
      setStatus("success");
      setMessage("Product added.");
      setName("");
      setPrice("");
      setStock("");
      setIpfsCid("");
      onAdded(); // 🇪🇸 refetch de la lista
    } catch (err) {
      setStatus("error");
      setMessage(friendlyError(err));
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3 rounded-md border border-gray-200 p-4">
      <h2 className="text-sm font-semibold text-gray-800">Add product</h2>
      <input
        type="text"
        placeholder="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="rounded-md border border-gray-300 px-3 py-2 text-sm"
      />
      <input
        type="number"
        step="0.01"
        min="0"
        placeholder="Price (€)"
        value={price}
        onChange={(e) => setPrice(e.target.value)}
        className="rounded-md border border-gray-300 px-3 py-2 text-sm"
      />
      <input
        type="number"
        step="1"
        min="0"
        placeholder="Stock"
        value={stock}
        onChange={(e) => setStock(e.target.value)}
        className="rounded-md border border-gray-300 px-3 py-2 text-sm"
      />
      <input
        type="text"
        placeholder="IPFS CID"
        value={ipfsCid}
        onChange={(e) => setIpfsCid(e.target.value)}
        className="rounded-md border border-gray-300 px-3 py-2 font-mono text-sm"
      />
      <button
        type="submit"
        disabled={status === "pending"}
        className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
      >
        {status === "pending" ? "Adding…" : "Add product"}
      </button>
      {message !== null ? (
        <span className={`text-xs ${status === "error" ? "text-red-600" : "text-green-600"}`}>
          {message}
        </span>
      ) : null}
    </form>
  );
}
