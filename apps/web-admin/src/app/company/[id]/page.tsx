import { CompanyDetail } from "@/components/CompanyDetail";

// 🇪🇸 NOTA: en Next.js 15 `params` es asíncrono (Promise). Lo await-eamos en el server component
// y pasamos un id ya parseado al componente cliente, que hace el fetch on-chain y maneja los tabs.
export default async function CompanyDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <main className="mx-auto max-w-3xl p-8">
      <CompanyDetail id={Number(id)} />
    </main>
  );
}
