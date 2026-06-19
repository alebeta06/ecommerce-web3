"use client";

import { useProducts } from "@/hooks/useProducts";
import { ProductCard } from "@/components/ProductCard";
import { type Product } from "@/types/product";

export default function CatalogPage() {
  const { products, isLoading, error } = useProducts();

  // 🇪🇸 NOTA: en el commit 1 solo logueamos. El flujo real (registro + addToCart) se cablea en C3-S2 commit 2.
  function onAddToCart(product: Product) {
    console.log("add to cart:", product.id);
  }

  return (
    <main className="mx-auto max-w-6xl p-8">
      <h1 className="text-2xl font-bold">Products</h1>

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
    </main>
  );
}
