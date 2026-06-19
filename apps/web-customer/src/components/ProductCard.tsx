"use client";

import { type Product } from "@/types/product";
import { formatEurt } from "@/lib/format";
import { env } from "@/lib/env";

export function ProductCard({
  product,
  onAddToCart,
}: {
  product: Product;
  onAddToCart: (product: Product) => void;
}) {
  // 🇪🇸 stock es bigint on-chain: comparamos con 0n (no 0). Sin stock → no se puede comprar.
  const outOfStock = product.stock === 0n;

  return (
    <div className="overflow-hidden rounded-lg border border-line bg-card">
      {/* 🇪🇸 Imagen desde IPFS (gateway + CID). Si el gateway falla o el CID no resuelve, onError
          sustituye por el placeholder local. aspect 4/3 para una grilla uniforme. */}
      <img
        src={env.ipfsGateway + product.ipfsCid}
        alt={product.name}
        onError={(e) => {
          e.currentTarget.src = "/placeholder.png";
        }}
        className="aspect-[4/3] w-full object-cover"
      />
      <div className="flex flex-col gap-2 p-4">
        <h3 className="font-medium text-fg">{product.name}</h3>
        <p className="text-lg font-semibold text-accent">{formatEurt(product.price)}</p>
        <p className="text-xs text-muted">
          {outOfStock ? "Out of stock" : `${product.stock.toString()} in stock`}
        </p>
        <button
          type="button"
          onClick={() => onAddToCart(product)}
          disabled={outOfStock}
          className="mt-1 rounded-md bg-accent px-4 py-2 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
        >
          Add to cart
        </button>
      </div>
    </div>
  );
}
