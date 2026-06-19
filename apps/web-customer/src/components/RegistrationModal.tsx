"use client";

import { useState } from "react";
import { useWallet } from "@/hooks/useWallet";
import { useCustomer } from "@/hooks/useCustomer";

// 🇪🇸 NOTA: modal overlay de registro. Autocontenido: toma la wallet del context y usa useCustomer
// para registrar. Al éxito avisa al llamador (onRegistered) y se cierra (onClose).
export function RegistrationModal({
  onRegistered,
  onClose,
}: {
  onRegistered: () => void;
  onClose: () => void;
}) {
  const { address } = useWallet();
  const { register, status, message } = useCustomer(address);
  const [name, setName] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const ok = await register(name);
    if (ok) {
      onRegistered();
      onClose();
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      {/* 🇪🇸 stopPropagation: click DENTRO del panel no cierra el modal (solo el backdrop cierra). */}
      <div
        className="w-full max-w-sm rounded-lg border border-line bg-card p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-lg font-semibold text-fg">One quick step</h2>
        <p className="mt-1 text-sm text-muted">
          Register as a customer to start shopping. Your wallet will be your account.
        </p>
        <form onSubmit={onSubmit} className="mt-4 flex flex-col gap-3">
          <input
            type="text"
            placeholder="Your name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="rounded-md border border-line bg-input px-3 py-2 text-sm text-fg placeholder:text-muted"
          />
          <div className="flex items-center gap-2">
            <button
              type="submit"
              disabled={status === "pending"}
              className="flex-1 rounded-md bg-accent px-4 py-2 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
            >
              {status === "pending" ? "Registering…" : "Register"}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="rounded-md border border-line px-4 py-2 text-sm text-muted hover:bg-bg hover:text-fg"
            >
              Cancel
            </button>
          </div>
          {message !== null ? (
            <span className={`text-xs ${status === "error" ? "text-red-400" : "text-success"}`}>
              {message}
            </span>
          ) : null}
        </form>
      </div>
    </div>
  );
}
