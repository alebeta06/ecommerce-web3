// 🇪🇸 NOTA: Server Component. Soporta DOS formatos de link de pago:
//   · nuevo  → ?invoices=1,2&redirect=…            (carrito on-chain → PayClient)
//   · legacy → ?merchant_address=0x…&amount=10&invoice=INV-X&date=…&redirect=…  (curso → LegacyPayClient)
// Lee searchParams (Promise en Next 15: hay que await), valida, y delega al Client Component adecuado.
import { PayClient } from "@/components/PayClient";
import { LegacyPayClient } from "@/components/LegacyPayClient";
import { isAddress } from "ethers";

interface GatewayPageProps {
  searchParams: Promise<{
    invoices?: string;
    redirect?: string;
    merchant_address?: string;
    amount?: string;
    invoice?: string;
    date?: string;
  }>;
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
  const { invoices, redirect, merchant_address, amount, invoice, date } = await searchParams;

  // 🇪🇸 redirect debe ser una URL http(s) (guard anti open-redirect / javascript:). Compartido.
  const validRedirect =
    typeof redirect === "string" && /^https?:\/\//i.test(redirect) ? redirect : null;

  // 🇪🇸 FORMATO LEGACY: si viene merchant_address, esta es una transferencia directa.
  if (typeof merchant_address === "string" && merchant_address.trim() !== "") {
    const amountNum = Number(amount);
    const legacyValid =
      isAddress(merchant_address) &&
      Number.isFinite(amountNum) &&
      amountNum > 0 &&
      validRedirect !== null;
    if (!legacyValid) return <InvalidLink />;
    return (
      <LegacyPayClient
        merchantAddress={merchant_address}
        amount={amountNum}
        invoice={invoice ?? "—"}
        date={date ?? "—"}
        redirect={validRedirect}
      />
    );
  }

  // 🇪🇸 FORMATO NUEVO: lista de invoice ids (sin cambios respecto a antes).
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
