"use client";

import { useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { useEcommerce } from "@/hooks/useEcommerce";
import { parseEurt } from "@/lib/format";
import { friendlyError } from "@/lib/errors";

type TxStatus = "idle" | "pending" | "success" | "error";
// 🇪🇸 Estado del upload a IPFS, independiente del tx-state: subir la imagen ocurre ANTES y por
// separado de mandar la tx. "done" significa que ya tenemos un CID de Pinata listo para el submit.
type UploadStatus = "idle" | "uploading" | "done" | "error";

// 🇪🇸 Forma de la respuesta de /api/upload-ipfs (éxito → { cid }, fallo → { error }).
interface UploadResponse {
  cid?: string;
  error?: string;
}

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
  // 🇪🇸 cid ya no se teclea a mano: lo devuelve Pinata tras subir la imagen. El usuario elige un
  // archivo y nosotros guardamos aquí el CID resultante.
  const [cid, setCid] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [uploadStatus, setUploadStatus] = useState<UploadStatus>("idle");
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [status, setStatus] = useState<TxStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);

  // 🇪🇸 Sin wallet conectada no hay signer (write === null): no mostramos el form.
  if (write === null) {
    return (
      <p className="rounded-md border border-line bg-card p-4 text-sm text-muted">
        Connect wallet first to add a product.
      </p>
    );
  }

  // 🇪🇸 NOTA: TS no propaga el narrowing del guard a funciones anidadas; fijamos una const ya
  // no-nulable para que el closure onSubmit vea el Contract sin posible null.
  const contract = write;

  // 🇪🇸 Al elegir un archivo lo subimos a IPFS vía nuestra API route (que firma con PINATA_JWT en
  // el servidor). Guardamos el CID devuelto en estado; el submit lo usará. Si falla, bloqueamos el
  // submit (cid queda vacío) y mostramos el error.
  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file === undefined) return;
    setFileName(file.name);
    setUploadStatus("uploading");
    setUploadError(null);
    setCid("");
    try {
      const body = new FormData();
      body.append("file", file);
      const res = await fetch("/api/upload-ipfs", { method: "POST", body });
      const json = (await res.json()) as UploadResponse;
      if (!res.ok || json.cid === undefined) {
        setUploadStatus("error");
        setUploadError(json.error ?? "Upload failed.");
        return;
      }
      setCid(json.cid);
      setUploadStatus("done");
    } catch {
      setUploadStatus("error");
      setUploadError("Could not upload the image.");
    }
  }

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
    if (cid.trim() === "") {
      setStatus("error");
      setMessage("Upload an image first.");
      return;
    }
    // 🇪🇸 El contrato (ProductLib) exige length >= 46 (un CIDv0 "Qm..." mide exactamente 46).
    // Validamos aquí para dar un mensaje claro en vez de un revert InvalidIpfsCidLength en estimateGas.
    if (cid.trim().length < 46) {
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
        cid.trim(),
        parseEurt(price),
        BigInt(stock),
      )) as ContractTransactionResponse;
      await tx.wait(); // 🇪🇸 espera a que la tx mine
      setStatus("success");
      setMessage("Product added.");
      setName("");
      setPrice("");
      setStock("");
      setCid("");
      setFileName(null);
      setUploadStatus("idle");
      onAdded(); // 🇪🇸 refetch de la lista
    } catch (err) {
      setStatus("error");
      setMessage(friendlyError(err));
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3 rounded-md border border-line bg-card p-4">
      <h2 className="text-sm font-semibold text-fg">Add product</h2>
      <input
        type="text"
        placeholder="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg placeholder:text-muted"
      />
      <input
        type="number"
        step="0.01"
        min="0"
        placeholder="Price (€)"
        value={price}
        onChange={(e) => setPrice(e.target.value)}
        className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg placeholder:text-muted"
      />
      <input
        type="number"
        step="1"
        min="0"
        placeholder="Stock"
        value={stock}
        onChange={(e) => setStock(e.target.value)}
        className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg placeholder:text-muted"
      />
      {/* 🇪🇸 File picker: sube la imagen a IPFS al elegirla. El CID resultante (no editable) se
          muestra en un chip debajo y es lo que viaja en el submit. */}
      <input
        type="file"
        accept="image/*"
        onChange={onFileChange}
        className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg file:mr-3 file:rounded file:border-0 file:bg-accent file:px-3 file:py-1 file:text-sm file:font-medium file:text-bg"
      />
      {fileName !== null ? (
        <span className="text-xs text-muted">
          {fileName}
          {uploadStatus === "uploading" ? " — Uploading…" : null}
        </span>
      ) : null}
      {uploadStatus === "done" ? (
        <span className="truncate rounded-full bg-success/15 px-2 py-0.5 font-mono text-xs text-success">
          {cid}
        </span>
      ) : null}
      {uploadStatus === "error" && uploadError !== null ? (
        <span className="text-xs text-red-400">{uploadError}</span>
      ) : null}
      <button
        type="submit"
        disabled={status === "pending" || uploadStatus === "uploading"}
        className="rounded-md bg-accent px-4 py-2 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
      >
        {status === "pending" ? "Adding…" : "Add product"}
      </button>
      {message !== null ? (
        <span className={`text-xs ${status === "error" ? "text-red-400" : "text-success"}`}>
          {message}
        </span>
      ) : null}
    </form>
  );
}
