import { NextResponse } from "next/server";
import Stripe from "stripe";
import { Contract, JsonRpcProvider, Wallet, isAddress, parseUnits, type InterfaceAbi } from "ethers";
import EuroTokenAbi from "@/abi/EuroToken.json";

// 🇪🇸 NOTA: API route de servidor. Verifica con Stripe que el pago se completó y SOLO entonces
// mintea EURT on-chain con la wallet OWNER del token (WALLET_PRIVATE_KEY = acct0). La secret de
// Stripe y la private key viven solo aquí; nunca tocan el navegador.
export const runtime = "nodejs";

interface MintBody {
  paymentIntentId?: unknown;
  walletAddress?: unknown;
  amountEur?: unknown;
}

export async function POST(req: Request): Promise<NextResponse> {
  let body: MintBody;
  try {
    body = (await req.json()) as MintBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  const { paymentIntentId, walletAddress, amountEur } = body;

  if (typeof paymentIntentId !== "string" || !paymentIntentId.startsWith("pi_")) {
    return NextResponse.json({ error: "Invalid paymentIntentId." }, { status: 400 });
  }
  if (typeof walletAddress !== "string" || !isAddress(walletAddress)) {
    return NextResponse.json({ error: "walletAddress is not a valid address." }, { status: 400 });
  }
  if (
    typeof amountEur !== "number" ||
    !Number.isInteger(amountEur) ||
    amountEur < 10 ||
    amountEur > 10000
  ) {
    return NextResponse.json(
      { error: "amountEur must be an integer between 10 and 10000." },
      { status: 400 },
    );
  }

  const secret = process.env.STRIPE_SECRET_KEY;
  const pk = process.env.WALLET_PRIVATE_KEY;
  const rpcUrl = process.env.RPC_URL;
  const tokenAddress = process.env.NEXT_PUBLIC_EUROTOKEN_ADDRESS;
  if (!secret || !pk || !rpcUrl || !tokenAddress) {
    return NextResponse.json({ error: "Server is missing required env vars." }, { status: 500 });
  }

  // 🇪🇸 1) Verificar el pago en Stripe. El PaymentIntent es la fuente de verdad.
  const stripe = new Stripe(secret);
  let paymentIntent: Stripe.PaymentIntent;
  try {
    paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
  } catch {
    return NextResponse.json({ error: "Payment intent not found." }, { status: 404 });
  }
  if (paymentIntent.status !== "succeeded") {
    return NextResponse.json(
      { error: `Payment not completed (status: ${paymentIntent.status}).` },
      { status: 402 },
    );
  }
  // 🇪🇸 Verificación cruzada anti-fraude: lo que se pide minar DEBE coincidir con lo pagado
  // (cantidad + wallet de la metadata del PI). Comparación de address case-insensitive (checksum).
  const paidWallet = (paymentIntent.metadata.walletAddress ?? "").toLowerCase();
  if (paymentIntent.amount !== amountEur * 100 || paidWallet !== walletAddress.toLowerCase()) {
    return NextResponse.json({ error: "Payment does not match the requested mint." }, { status: 400 });
  }

  // 🇪🇸 NOTA (riesgo conocido, NO resuelto en scope local): no hay idempotencia. Un mismo
  // paymentIntentId reenviado mintearía de nuevo. En producción se persistiría el PI ya procesado
  // (DB/flag) para no acuñar dos veces por el mismo pago.

  // 🇪🇸 2) Mintear EURT. acct0 (owner del token) firma. 6 decimales: €1 = 1_000_000 base units.
  try {
    const provider = new JsonRpcProvider(rpcUrl);
    const wallet = new Wallet(pk, provider);
    const euroToken = new Contract(tokenAddress, EuroTokenAbi as InterfaceAbi, wallet);
    const tx = await euroToken.mint(walletAddress, parseUnits(String(amountEur), 6));
    await tx.wait();
    return NextResponse.json({ txHash: tx.hash });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Mint failed.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
