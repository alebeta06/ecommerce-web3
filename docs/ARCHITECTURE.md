# Architecture — E-Commerce Web3 with Stablecoin

<!-- 🇪🇸 NOTA: Este documento explica CÓMO se comunican los 7 componentes y los flujos de datos
     principales. CLAUDE.md da la vista general; aquí entramos al detalle de cada flujo. -->

This document details how the 7 components communicate and the main data flows. For the high-level
overview and tech decisions, see [`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Components & responsibilities

| # | Component        | World     | Owns / does                                                       |
|---|------------------|-----------|-------------------------------------------------------------------|
| 1 | EuroToken        | on-chain  | The money. ERC20 EURT (6 decimals). `mint()` restricted to owner. |
| 2 | buy-stablecoin   | off-chain | Sells EURT for fiat via Stripe; mints EURT on confirmed payment.  |
| 3 | payment-gateway  | off-chain | Executes an on-chain payment: `approve` EURT + `processPayment`.  |
| 4 | Ecommerce        | on-chain  | Store logic: companies, products, customers, carts, invoices, payments. |
| 5 | web-admin        | off-chain | Merchant back-office; product images go to IPFS.                  |
| 6 | web-customer     | off-chain | Storefront; browse, cart, checkout, order history.                |
| 7 | restart-all.sh   | tooling   | Boots the full local stack and wires addresses into `.env`.       |

The four apps hold **no business data of their own** — they read/write on-chain state through
ethers.js, using ABIs and addresses from the shared packages.

---

## 2. Communication map

```
  buy-stablecoin ──┐                                        ┌── web-admin
                   │ ethers.js (read/write)                 │ ethers.js + IPFS
                   ▼                                        ▼
            ┌──────────────┐  EURT transfer/approve  ┌──────────────┐
            │  EuroToken   │◄───────────────────────►│  Ecommerce   │
            │   (ERC20)    │                          │  (+ 6 libs)  │
            └──────┬───────┘                          └──────┬───────┘
                   ▲                                         ▲
   payment-gateway─┘ approve + processPayment   web-customer─┘ read catalog / write cart, invoice

  Off-chain:  Stripe (cards) ──webhook──► buy-stablecoin ──mint()──► EuroToken
              IPFS (Pinata)  ◄──upload──  web-admin ;  CID stored in Ecommerce product
  Shared:     shared-abis · shared-types · shared-config  (imported by all 4 apps)
```

---

## 3. Main data flows

### Flow 1 — Buying stablecoin (fiat → EURT)

```
User           buy-stablecoin (Next.js)        Stripe              EuroToken (chain)
 │  enter € amount + card  │                      │                      │
 │ ───────────────────────►│ create PaymentIntent │                      │
 │                         │ ────────────────────►│                      │
 │                         │ ◄──── client_secret ─│                      │
 │ ◄── confirm card (Stripe.js) ─────────────────►│ (charges the card)   │
 │                         │                      │                      │
 │                         │ ◄═══ webhook: payment_intent.succeeded ══════│  (Stripe → our server)
 │                         │  verify signature    │                      │
 │                         │  with WEBHOOK_SECRET  │                      │
 │                         │ ─────────────── mint(user, amount) ─────────►│  (only minter wallet)
 │ ◄── EURT in wallet ─────│                      │                      │
```

**Key points (🇪🇸 NOTA):**
- El navegador **nunca** confirma el pago a nuestro backend; confiamos solo en el **webhook**
  firmado por Stripe (verificamos la firma con `STRIPE_WEBHOOK_SECRET`). Esto evita que un usuario
  malicioso falsee "ya pagué" y reciba EURT gratis.
- `mint()` lo llama una **wallet minter** controlada por el servidor (`MINTER_PRIVATE_KEY`), que es
  el `owner` del contrato EuroToken.
- El importe se convierte a unidades base con 6 decimales (1 € = 1_000_000 unidades).

### Flow 2 — Buying products (EURT → goods)

```
User      web-customer            Ecommerce (chain)        payment-gateway        EuroToken
 │ browse catalog │                    │                        │                   │
 │ ──────────────►│ read products      │                        │                   │
 │                │ ──────────────────►│                        │                   │
 │ add to cart    │ write cart (on-chain, CartLib)              │                   │
 │ ──────────────►│ ──────────────────►│                        │                   │
 │ checkout       │ createInvoice (InvoiceLib) → invoiceId      │                   │
 │ ──────────────►│ ──────────────────►│                        │                   │
 │                │ redirect with URL params:                   │                   │
 │                │   ?merchant=&amount=&invoice=&redirect=      │                   │
 │ ◄──────────────│ ───────────────────────────────────────────►│                   │
 │ connect MetaMask, confirm                                    │ approve(EURT)     │
 │ ────────────────────────────────────────────────────────────►│ ─────────────────►│
 │                │                    │  processPayment(invoice)│                   │
 │                │                    │◄────────────────────────│ (pulls EURT via   │
 │                │                    │  PaymentLib marks paid   │  transferFrom)    │
 │ ◄── redirect back to web-customer (order confirmed) ─────────│                   │
```

**Key points (🇪🇸 NOTA):**
- El **carrito es on-chain** (persistente): sobrevive a recargas y cambios de dispositivo porque
  vive en el contrato, no en `localStorage`.
- `approve` + `processPayment` es el patrón ERC20 clásico: primero el usuario **autoriza**
  (`approve`) al contrato Ecommerce a gastar X EURT; luego `processPayment` hace `transferFrom`
  para cobrar. Son **dos transacciones** y hay que manejar el estado intermedio en la UI.
- La pasarela recibe todo por **parámetros de URL** (`merchant`, `amount`, `invoice`, `redirect`),
  lo que la desacopla de la tienda: cualquier tienda podría redirigir a esta misma pasarela.

### Flow 3 — Administration (merchant back-office)

```
Merchant    web-admin              IPFS (Pinata)            Ecommerce (chain)
 │ register company │                    │                        │
 │ ────────────────►│ ───────────────────────────────────────────► registerCompany (CompanyLib)
 │ create product   │                    │                        │
 │ + image          │ ── upload image ──►│ returns CID            │
 │ ────────────────►│ ◄──────────────────│                        │
 │                  │ createProduct(name, price, stock, CID) ─────► ProductLib (stores CID, not bytes)
 │ view invoices /  │                    │                        │
 │ customers        │ ◄──── read InvoiceLib / CustomerLib ─────────│
```

**Key points (🇪🇸 NOTA):**
- Las imágenes se suben a **IPFS** y on-chain solo guardamos el **CID** (hash). Guardar los bytes
  de la imagen on-chain sería carísimo en gas; el CID ocupa poco y es verificable.
- El registro de empresas y el CRUD de productos están protegidos por **control de acceso** (roles)
  en el contrato Ecommerce: no cualquiera puede crear productos.

---

## 4. Design decisions (justified)

<!-- 🇪🇸 NOTA: Decisiones de arquitectura. El "por qué" detallado de tooling está en CLAUDE.md §9. -->

1. **Modular Ecommerce with 6 libraries.** Splitting Company/Product/Customer/Cart/Invoice/Payment
   into libraries keeps the main contract under the 24KB bytecode limit, isolates concerns for
   easier testing (aim 80%+ coverage), and can reduce gas via shared, linked code.
2. **6-decimal EURT.** Matches a cent-precise fiat peg (1 € = 1,000,000 base units), mirrors USDC,
   and keeps integer math compact. Decimals are display-only; storage is integer base units.
3. **Payment confirmed by webhook, not browser.** The only trusted signal that fiat cleared is
   Stripe's signed webhook; minting hangs off that, never off a client-side success callback.
4. **On-chain cart.** Persistence and auditability for free; the cart is part of the protocol, not
   a front-end convenience.
5. **Decoupled payment gateway via URL params.** The gateway knows nothing about the store; it just
   needs `merchant/amount/invoice/redirect`. This makes it reusable across storefronts.
6. **Shared ABIs/types/config package.** One source of truth prevents drift between the 4 apps and
   the contracts; `restart-all.sh` rewrites addresses on every redeploy.
7. **Images on IPFS, CID on-chain.** Cheap, content-addressed, tamper-evident; on-chain stays lean.
8. **Access control split: Ownable (EuroToken) vs AccessControl (Ecommerce).** Minting is a single
   privileged action → Ownable. The store has multiple privileged roles → role-based AccessControl.

---

## 5. Local environment topology

```
   Anvil (localhost:8545, chainId 31337)
     ├── EuroToken      @ 0x... (deployed by restart-all.sh)
     └── Ecommerce      @ 0x... (deployed by restart-all.sh)
   Next.js dev servers
     ├── buy-stablecoin   :3000
     ├── payment-gateway  :3001
     ├── web-admin        :3002
     └── web-customer     :3003
   (ports are indicative; finalized when apps are initialized)
```

`restart-all.sh` is the conductor: it starts Anvil, deploys both contracts, writes their addresses
into each app's `.env` (and into `shared-config`), then launches the four dev servers.
