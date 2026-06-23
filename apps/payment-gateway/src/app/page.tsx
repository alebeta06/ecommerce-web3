// 🇪🇸 NOTA: Server Component. Lee searchParams (Promise en Next 15: hay que await), valida el link
// de pago, y delega el flujo interactivo (wallet, approve, pay) al Client Component PayClient.
import { PayClient } from "@/components/PayClient";

interface GatewayPageProps {
  searchParams: Promise<{ invoices?: string; redirect?: string }>;
}

function InvalidLink() {
  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-2xl font-bold text-fg">Invalid payment link.</h1>
      <p className="mt-2 text-muted">
        This payment link is missing or malformed. Please return to the store and try checkout again.
      </p>
    </main>
  );
}

export default async function GatewayPage({ searchParams }: GatewayPageProps) {
  const { invoices, redirect } = await searchParams;

  // 🇪🇸 redirect debe ser una URL http(s) (guard anti open-redirect / javascript:).
  const validRedirect =
    typeof redirect === "string" && /^https?:\/\//i.test(redirect) ? redirect : null;

  // 🇪🇸 invoices: lista de ids separada por comas; válida si no vacía y todos enteros >= 0.
  const ids =
    typeof invoices === "string" && invoices.trim() !== ""
      ? invoices.split(",").map(Number)
      : [];
  const validIds = ids.length > 0 && ids.every((n) => Number.isInteger(n) && n >= 0);

  if (!validIds || validRedirect === null) {
    return <InvalidLink />;
  }

  return <PayClient invoiceIds={ids} redirect={validRedirect} />;
}
