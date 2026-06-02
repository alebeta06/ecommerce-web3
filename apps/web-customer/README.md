# web-customer (Component 6)

<!-- 🇪🇸 NOTA: Placeholder. App Next.js que se inicializará más adelante. -->

Next.js 15 **storefront**. Browse the catalog (no wallet needed), use an on-chain persistent cart,
checkout (creates an invoice and redirects to the payment gateway), and view order history.
Dark mode + responsive.

## Responsibilities
- Product catalog — readable **without** connecting a wallet.
- Persistent **on-chain cart** (`CartLib`).
- Checkout: create invoice (`InvoiceLib`) and redirect to `payment-gateway` with URL params.
- Order history ("my invoices").

## Planned structure
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
