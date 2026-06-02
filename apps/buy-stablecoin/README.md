# buy-stablecoin (Component 2)

<!-- 🇪🇸 NOTA: Placeholder. Esta carpeta se inicializará como app Next.js en una sesión futura.
     Por ahora documenta su propósito y estructura prevista, y mantiene la carpeta en git. -->

Next.js 15 app to **buy EURT stablecoin with a real credit card** via Stripe, minting EURT to the
user's wallet once the payment is confirmed by a verified Stripe webhook.

## Responsibilities
- Create Stripe **Payment Intents** for a given EUR amount.
- Collect card details with Stripe.js (PCI-safe; card data never touches our server).
- Receive the `payment_intent.succeeded` **webhook**, verify its signature, and call `mint()` on
  EuroToken from the minter wallet.

## Planned structure
```
src/app/            # routes incl. /api/webhook (Stripe), /api/payment-intent
src/components/      # checkout form, status UI
src/lib/             # stripe client, ethers client, mint helper
src/types/
public/
.env.example
```

## Key concepts (🇪🇸)
- **Payment Intent:** objeto de Stripe que sigue el ciclo de vida de un pago.
- **Webhook:** callback HTTP firmado que Stripe envía al confirmarse el pago — única fuente fiable.
- Minteamos EURT **solo** tras verificar la firma del webhook (`STRIPE_WEBHOOK_SECRET`).

See [`../../CLAUDE.md`](../../CLAUDE.md) §8 for env vars and §9 for design rationale.
