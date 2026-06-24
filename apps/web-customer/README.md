# web-customer (Component 6)

Next.js 15 **storefront** (port 6004). Browse the catalog (no wallet needed), use an on-chain
persistent cart, checkout (creates one invoice per company and redirects to the payment gateway),
and view order history. Dark mode + responsive.

## Responsibilities
- Product catalog — readable **without** connecting a wallet.
- Persistent **on-chain cart** (`CartLib`).
- Checkout: create invoices (`InvoiceLib`, one per company) and redirect to `payment-gateway` via
  `window.location.href` with `?invoices=...&redirect=...` (cross-origin :6004 → :6002).
- Order history ("my invoices").

## Structure
```
src/app/            # /catalog, /cart, /checkout, /orders
src/components/      # product cards, cart drawer, theme toggle
src/hooks/           # useWallet, useContract, useCart
src/lib/             # ethers client, ipfs gateway helpers
src/types/
.env.example
```

## Key concepts (🇪🇸)
- **Carrito on-chain:** persiste entre sesiones/dispositivos porque vive en el contrato.
- **Checkout → redirect:** la tienda crea la invoice y delega el cobro a la pasarela vía URL.

See [`../../CLAUDE.md`](../../CLAUDE.md) for env vars and design rationale.
