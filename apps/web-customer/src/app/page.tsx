"use client";

import { useState } from "react";
import { type ContractTransactionResponse } from "ethers";
import { useProducts } from "@/hooks/useProducts";
import { useWallet } from "@/hooks/useWallet";
import { useCustomer } from "@/hooks/useCustomer";
import { useEcommerce } from "@/hooks/useEcommerce";
import { ProductCard } from "@/components/ProductCard";
import { RegistrationModal } from "@/components/RegistrationModal";
import { friendlyError } from "@/lib/errors";
import { type Product } from "@/types/product";

export default function CatalogPage() {
  const { products, isLoading, error } = useProducts();
  const { address } = useWallet();
  const { isRegistered, refetch: refetchCustomer } = useCustomer(address);
  const { write } = useEcommerce();

  const [showModal, setShowModal] = useState(false);
  const [pendingProduct, setPendingProduct] = useState<Product | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [isError, setIsError] = useState(false);

  // 🇪🇸 addToCart real: qty = 1 (se ajusta luego en /cart). companyId/id son number → BigInt para
  // ethers v6. addToCart(companyId, productId, quantity) — los tres uint256.
  async function doAddToCart(product: Product) {
    if (write === null) return;
    setFeedback(null);
    setIsError(false);
    try {
      const tx = (await write.addToCart(
        BigInt(product.companyId),
        BigInt(product.id),
        1n,
      )) as ContractTransactionResponse;
      await tx.wait();
      setFeedback(`Added "${product.name}" to cart.`);
    } catch (err) {
      setIsError(true);
      setFeedback(friendlyError(err));
    }
  }

  // 🇪🇸 Punto de entrada del botón de cada card. Decide: sin wallet → aviso; sin registro → modal
  // (guardando el producto pendiente); registrado → addToCart directo.
  function onAddToCart(product: Product) {
    if (write === null) {
      setIsError(true);
      setFeedback("Connect your wallet first.");
      return;
    }
    if (!isRegistered) {
      setPendingProduct(product);
      setShowModal(true);
      return;
    }
    void doAddToCart(product);
  }

  return (
    <main className="mx-auto max-w-6xl p-8">
      <h1 className="text-2xl font-bold">Products</h1>

      {feedback !== null ? (
        <p className={`mt-3 text-sm ${isError ? "text-red-400" : "text-success"}`}>{feedback}</p>
      ) : null}

      <div className="mt-6">
        {isLoading ? (
          // 🇪🇸 Skeleton: 3 cards en gris con pulso mientras carga el catálogo.
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {[0, 1, 2].map((i) => (
              <div key={i} className="h-72 animate-pulse rounded-lg border border-line bg-card" />
            ))}
          </div>
        ) : error !== null ? (
          <p className="text-sm text-red-400">{error}</p>
        ) : products.length === 0 ? (
          <p className="text-sm text-muted">No products available yet.</p>
        ) : (
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} onAddToCart={onAddToCart} />
            ))}
          </div>
        )}
      </div>

      {showModal ? (
        <RegistrationModal
          onRegistered={() => {
            // 🇪🇸 Tras registrar: refrescamos isRegistered (para próximos adds) y completamos el add
            // que disparó el modal.
            refetchCustomer();
            if (pendingProduct !== null) void doAddToCart(pendingProduct);
          }}
          onClose={() => {
            setShowModal(false);
            setPendingProduct(null);
          }}
        />
      ) : null}
    </main>
  );
}
