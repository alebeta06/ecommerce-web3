"use client";

import { useState } from "react";
import { PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";

interface CheckoutFormProps {
  amountEur: number;
  onPaid: (paymentIntentId: string) => void;
}

export function CheckoutForm({ amountEur, onPaid }: CheckoutFormProps) {
  const stripe = useStripe();
  const elements = useElements();
  const [isPaying, setIsPaying] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handlePay() {
    if (!stripe || !elements) return;
    setIsPaying(true);
    setError(null);
    // 🇪🇸 confirmPayment con redirect:"if_required" confirma SIN salir de la página (en test de
    // tarjeta no hace falta redirección 3DS). Si Stripe necesitara redirigir, lo haría.
    const result = await stripe.confirmPayment({ elements, redirect: "if_required" });
    if (result.error) {
      setError(result.error.message ?? "Payment failed.");
      setIsPaying(false);
      return;
    }
    if (result.paymentIntent && result.paymentIntent.status === "succeeded") {
      // 🇪🇸 Pago OK → el padre dispara el mint on-chain con este paymentIntentId.
      onPaid(result.paymentIntent.id);
      return; // 🇪🇸 dejamos isPaying en true: el padre toma el control (estado "minting").
    }
    setError("Payment was not completed.");
    setIsPaying(false);
  }

  return (
    <div className="flex flex-col gap-4">
      <PaymentElement />
      {error !== null ? <p className="text-sm text-red-400">{error}</p> : null}
      <button
        type="button"
        onClick={() => void handlePay()}
        disabled={!stripe || isPaying}
        className="w-full rounded-md bg-accent px-4 py-3 text-sm font-medium text-bg hover:bg-accent/90 disabled:opacity-50"
      >
        {isPaying ? "Procesando…" : `Pagar €${amountEur}`}
      </button>
    </div>
  );
}
