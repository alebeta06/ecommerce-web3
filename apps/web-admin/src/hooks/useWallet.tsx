"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { BrowserProvider, type Eip1193Provider, type JsonRpcSigner } from "ethers";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: MetaMask, además del request() de EIP-1193, emite eventos vía on/removeListener.
// El tipo Eip1193Provider de ethers solo declara request(), así que lo ampliamos para suscribirnos.
type InjectedProvider = Eip1193Provider & {
  on?: (event: string, listener: (...args: unknown[]) => void) => void;
  removeListener?: (event: string, listener: (...args: unknown[]) => void) => void;
};

// 🇪🇸 NOTA: acceso SSR-safe a window.ethereum. En el servidor (Next.js App Router renderiza ahí)
// `window` no existe, así que devolvemos null y nunca tocamos APIs del navegador.
function getInjected(): InjectedProvider | null {
  if (typeof window === "undefined") return null;
  return (window.ethereum as InjectedProvider | undefined) ?? null;
}

export interface WalletState {
  address: string | null;
  chainId: number | null;
  signer: JsonRpcSigner | null;
  isConnected: boolean;
  isConnecting: boolean;
  isWrongNetwork: boolean;
  error: string | null;
  connect: () => Promise<void>;
  disconnect: () => void;
}

// 🇪🇸 NOTA: el estado de la wallet se comparte por Context (no por llamadas sueltas a useWallet,
// que tendrían estado independiente). Así el header y useEcommerce ven el MISMO signer.
const WalletContext = createContext<WalletState | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [address, setAddress] = useState<string | null>(null);
  const [chainId, setChainId] = useState<number | null>(null);
  const [signer, setSigner] = useState<JsonRpcSigner | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const disconnect = useCallback(() => {
    // 🇪🇸 NOTA: EIP-1193 no define una desconexión programática; limpiamos el estado local.
    setAddress(null);
    setChainId(null);
    setSigner(null);
    setError(null);
  }, []);

  // 🇪🇸 Relee cuenta, red y signer desde el proveedor inyectado. Reutilizado por connect() y por
  // los listeners de MetaMask, para que el signer nunca quede desfasado al cambiar de cuenta/red.
  const refresh = useCallback(
    async (injected: InjectedProvider) => {
      const provider = new BrowserProvider(injected);
      const accounts = await provider.listAccounts();
      if (accounts.length === 0) {
        disconnect();
        return;
      }
      const nextSigner = await provider.getSigner();
      const network = await provider.getNetwork();
      setSigner(nextSigner);
      setAddress(await nextSigner.getAddress());
      setChainId(Number(network.chainId));
    },
    [disconnect],
  );

  const connect = useCallback(async () => {
    const injected = getInjected();
    if (!injected) {
      setError("MetaMask not found. Install it to connect.");
      return;
    }
    setIsConnecting(true);
    setError(null);
    try {
      // 🇪🇸 Pide permiso de cuentas (abre el popup de MetaMask la primera vez).
      await injected.request({ method: "eth_requestAccounts" });
      await refresh(injected);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to connect wallet.");
    } finally {
      setIsConnecting(false);
    }
  }, [refresh]);

  // 🇪🇸 NOTA: mantenemos el estado en sync con MetaMask (cambio de cuenta o de red en la extensión).
  useEffect(() => {
    const injected = getInjected();
    if (!injected?.on || !injected.removeListener) return;

    const onChange = () => {
      void refresh(injected);
    };
    injected.on("accountsChanged", onChange);
    injected.on("chainChanged", onChange);
    return () => {
      injected.removeListener?.("accountsChanged", onChange);
      injected.removeListener?.("chainChanged", onChange);
    };
  }, [refresh]);

  const value = useMemo<WalletState>(() => {
    const isConnected = address !== null;
    return {
      address,
      chainId,
      signer,
      isConnected,
      isConnecting,
      // 🇪🇸 Guard de red: conectado pero en una red distinta de la esperada (anvil 31337).
      isWrongNetwork: isConnected && chainId !== env.chainId,
      error,
      connect,
      disconnect,
    };
  }, [address, chainId, signer, isConnecting, error, connect, disconnect]);

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>;
}

export function useWallet(): WalletState {
  const ctx = useContext(WalletContext);
  if (ctx === null) {
    throw new Error("useWallet must be used within a <WalletProvider>.");
  }
  return ctx;
}
