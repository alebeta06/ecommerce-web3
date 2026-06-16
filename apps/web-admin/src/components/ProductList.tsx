import { type Product } from "@/types/product";
import { formatEurt } from "@/lib/format";

export function ProductList({
  products,
  isLoading,
  error,
}: {
  products: Product[];
  isLoading: boolean;
  error: string | null;
}) {
  if (isLoading) return <p className="text-sm text-gray-500">Loading…</p>;
  if (error !== null) return <p className="text-sm text-red-600">{error}</p>;
  if (products.length === 0) return <p className="text-sm text-gray-500">No products yet.</p>;

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-gray-200 text-left text-gray-500">
          <th className="py-2 pr-4 font-medium">Name</th>
          <th className="py-2 pr-4 font-medium">Price</th>
          <th className="py-2 pr-4 font-medium">Stock</th>
          <th className="py-2 font-medium">Active</th>
        </tr>
      </thead>
      <tbody>
        {products.map((p) => (
          <tr key={p.id} className="border-b border-gray-100">
            <td className="py-2 pr-4">{p.name}</td>
            <td className="py-2 pr-4">{formatEurt(p.price)}</td>
            <td className="py-2 pr-4">{p.stock.toString()}</td>
            <td className="py-2">
              {/* 🇪🇸 Badge de estado: verde si el producto está activo, gris si no. */}
              <span
                className={`rounded-full px-2 py-0.5 text-xs ${
                  p.active ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"
                }`}
              >
                {p.active ? "Active" : "Inactive"}
              </span>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
