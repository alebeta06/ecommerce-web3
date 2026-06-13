import Link from "next/link";
import { type Company } from "@/types/company";
import { shortenAddress } from "@/lib/format";

export function CompanyList({
  companies,
  isLoading,
  error,
}: {
  companies: Company[];
  isLoading: boolean;
  error: string | null;
}) {
  if (isLoading) return <p className="text-sm text-gray-500">Loading…</p>;
  if (error !== null) return <p className="text-sm text-red-600">{error}</p>;
  if (companies.length === 0) return <p className="text-sm text-gray-500">No companies yet.</p>;

  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-gray-200 text-left text-gray-500">
          <th className="py-2 pr-4 font-medium">ID</th>
          <th className="py-2 pr-4 font-medium">Name</th>
          <th className="py-2 pr-4 font-medium">Owner</th>
          <th className="py-2 pr-4 font-medium">Payout</th>
          <th className="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        {companies.map((c) => (
          <tr key={c.id} className="border-b border-gray-100">
            <td className="py-2 pr-4">{c.id}</td>
            <td className="py-2 pr-4">{c.name}</td>
            <td className="py-2 pr-4 font-mono">{shortenAddress(c.owner)}</td>
            <td className="py-2 pr-4 font-mono">{shortenAddress(c.payoutWallet)}</td>
            <td className="py-2">
              <Link href={`/company/${c.id}`} className="text-blue-600 hover:underline">
                View
              </Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
