import { NextResponse } from "next/server";
import Stripe from "stripe";
import { isAddress } from "ethers";

// 🇪🇸 NOTA: API route SOLO de servidor (Node runtime). Aquí vive STRIPE_SECRET_KEY: nunca llega al
// navegador. Crea el PaymentIntent (objeto con el que Stripe rastrea el ciclo de vida de un pago) y
// devuelve su client_secret, con el que el frontend monta el <PaymentElement>.
export const runtime = "nodejs";

interface CreateBody {
  amountEur?: unknown;
  walletAddress?: unknown;
}

export async function POST(req: Request): Promise<NextResponse> {
  let body: CreateBody;
  try {
    body = (await req.json()) as CreateBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  const { amountEur, walletAddress } = body;

  // 🇪🇸 Validación en el boundary: cantidad entera 10..10000 y dirección EVM válida.
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
  if (typeof walletAddress !== "string" || !isAddress(walletAddress)) {
    return NextResponse.json({ error: "walletAddress is not a valid address." }, { status: 400 });
  }

  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    return NextResponse.json({ error: "Server missing STRIPE_SECRET_KEY." }, { status: 500 });
  }

  // 🇪🇸 Sin apiVersion pineada: usa la versión por defecto de la cuenta (decisión acordada).
  const stripe = new Stripe(secret);

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountEur * 100, // 🇪🇸 Stripe usa la unidad mínima (céntimos): €10 = 1000.
      currency: "eur",
      automatic_payment_methods: { enabled: true },
      // 🇪🇸 Guardamos destino + cantidad en metadata: en /api/mint-tokens la FUENTE DE VERDAD es el
      // PaymentIntent, no el body del cliente (que podría mentir sobre cuánto pagó o a qué wallet).
      metadata: { walletAddress, amountEur: String(amountEur) },
    });
    return NextResponse.json({ clientSecret: paymentIntent.client_secret });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to create payment intent.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
