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
| 2 | compra-stablecoin| off-chain | Sells EURT for fiat via Stripe; mints EURT on confirmed payment.  |
| 3 | payment-gateway  | off-chain | Executes an on-chain payment: `approve` EURT + `processPayment`.  |
| 4 | Ecommerce        | on-chain  | Store logic: companies, products, customers, carts, invoices, payments. |
| 5 | web-admin        | off-chain | Merchant back-office; product images go to IPFS.                  |
| 6 | web-customer     | off-chain | Storefront; browse, cart, checkout, order history.                |
| 7 | restart-all.sh   | tooling   | Boots the full local stack; deploys to deterministic addresses and validates them. |

The four apps hold **no business data of their own** — they read/write on-chain state through
ethers.js, using ABIs and addresses from the shared packages.

---

## 2. Communication map

```
  compra-stablecoin┐                                        ┌── web-admin
                   │ ethers.js (read/write)                 │ ethers.js + IPFS
                   ▼                                        ▼
            ┌──────────────┐  EURT transfer/approve  ┌──────────────┐
            │  EuroToken   │◄───────────────────────►│  Ecommerce   │
            │   (ERC20)    │                          │  (+ 6 libs)  │
            └──────┬───────┘                          └──────┬───────┘
                   ▲                                         ▲
   payment-gateway─┘ approve + processPayment   web-customer─┘ read catalog / write cart, invoice

  Off-chain:  Stripe (cards) ──PaymentIntent──► compra-stablecoin ──mint() via /api/mint-tokens──► EuroToken
              IPFS (Pinata)  ◄──upload──  web-admin ;  CID stored in Ecommerce product
  Shared:     shared-abis · shared-types · shared-config  (imported by all 4 apps)
```

---

## 3. Main data flows

### Flow 1 — Buying stablecoin (fiat → EURT)

```
User        compra-stablecoin (Next.js)        Stripe              EuroToken (chain)
 │  enter € amount + card  │                      │                      │
 │ ───────────────────────►│ POST /api/create-payment-intent             │
 │                         │ ────────────────────►│                      │
 │                         │ ◄──── client_secret ─│                      │
 │ ◄── confirm card (Stripe.js) ─────────────────►│ (charges the card)   │
 │                         │                      │                      │
 │  paymentIntent.succeeded (on the client)       │                      │
 │ ───────────────────────►│ POST /api/mint-tokens │                      │
 │                         │  (server re-checks the PaymentIntent status) │
 │                         │ ─────────────── mint(user, amount) ─────────►│  (server minter wallet)
 │ ◄── EURT in wallet ─────│                      │                      │
```

**Key points (🇪🇸 NOTA):**
- El mint ocurre **server-side** (`/api/mint-tokens`) y **solo tras `paymentIntent.succeeded`**: el
  backend nunca confía en un "ya pagué" del cliente sin validar el estado del PaymentIntent en Stripe.
- `mint()` lo llama una **wallet minter** controlada por el servidor (`WALLET_PRIVATE_KEY`), que es
  el `owner` del contrato EuroToken.
- El importe se convierte a unidades base con 6 decimales (1 € = 1_000_000 unidades).

> 🇪🇸 NOTA (implementación final): la confirmación de pago se resuelve con una **API route**
> (`/api/mint-tokens`), **no con un webhook firmado**. Un webhook firmado por Stripe sería la
> evolución más robusta (resistente a que el cliente cierre la pestaña), pero la implementación
> actual mintea desde la API route tras verificar el estado del PaymentIntent en Stripe.

### Flow 2 — Buying products (EURT → goods)

```
User      web-customer            Ecommerce (chain)        payment-gateway        EuroToken
 │ browse catalog │                    │                        │                   │
 │ ──────────────►│ read products      │                        │                   │
 │                │ ──────────────────►│                        │                   │
 │ add to cart    │ write cart (on-chain, CartLib)              │                   │
 │ ──────────────►│ ──────────────────►│                        │                   │
 │ checkout       │ createInvoices (InvoiceLib, one per company) │                  │
 │ ──────────────►│ ──────────────────►│                        │                   │
 │                │ redirect with URL params:                   │                   │
 │                │   ?invoices=ID1,ID2&redirect=URL            │                   │
 │ ◄──────────────│ ───────────────────────────────────────────►│                   │
 │ connect MetaMask, confirm                                    │ approve(exact)    │
 │ ────────────────────────────────────────────────────────────►│ ─────────────────►│
 │                │                    │ processBatchPayments([ids]) (atomic)        │
 │                │                    │◄────────────────────────│ (pulls EURT via   │
 │                │                    │  PaymentLib marks paid   │  transferFrom)    │
 │ ◄── redirect back to web-customer (orders confirmed) ────────│                   │
```

**Key points (🇪🇸 NOTA):**
- El **carrito es on-chain** (persistente): sobrevive a recargas y cambios de dispositivo porque
  vive en el contrato, no en `localStorage`.
- `approve` + `processPayment` es el patrón ERC20 clásico: primero el usuario **autoriza**
  (`approve`, por el **importe exacto**, no `MaxUint256`) al contrato Ecommerce a gastar X EURT;
  luego `processPayment(invoiceId)` / `processBatchPayments(invoiceIds)` (atómico) hace
  `transferFrom` para cobrar. Son **dos transacciones** y hay que manejar el estado intermedio en la UI.
- La pasarela recibe todo por **parámetros de URL**: el formato de checkout es
  `invoices=ID1,ID2&redirect=URL`; además admite un formato **legacy**
  (`merchant_address&amount&invoice&date&redirect`). Esto la desacopla de la tienda: cualquier
  tienda podría redirigir a esta misma pasarela.

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
   easier testing (**100% coverage of the contract code achieved**), and can reduce gas via shared,
   linked code.
2. **6-decimal EURT.** Matches a cent-precise fiat peg (1 € = 1,000,000 base units), mirrors USDC,
   and keeps integer math compact. Decimals are display-only; storage is integer base units.
3. **Minting confirmed server-side, not by the browser.** EURT is minted only by the server
   (`/api/mint-tokens`) after `paymentIntent.succeeded`, re-checking the PaymentIntent status with
   Stripe — never off an unverified client-side claim. (A signed Stripe webhook would be the more
   robust evolution; the current implementation uses an API route — see Flow 1.)
4. **On-chain cart.** Persistence and auditability for free; the cart is part of the protocol, not
   a front-end convenience.
5. **Decoupled payment gateway via URL params.** The gateway knows nothing about the store; it just
   needs `invoices` + `redirect` (plus a legacy `merchant_address/amount/invoice/date/redirect`
   format). This makes it reusable across storefronts.
6. **Shared ABIs/types/config package (planned).** A single source of truth would prevent drift
   between the 4 apps and the contracts. *Note:* these packages are not yet implemented — each app
   currently carries its own ABIs/types/config — and `restart-all.sh` deploys to **deterministic
   addresses** (hardcoded and validated, not rewritten into `.env`).
7. **Images on IPFS, CID on-chain.** Cheap, content-addressed, tamper-evident; on-chain stays lean.
8. **Access control split: Ownable (EuroToken) vs AccessControl (Ecommerce).** Minting is a single
   privileged action → Ownable. The store has multiple privileged roles → role-based AccessControl.

---

## 5. Local environment topology

```
   Anvil (localhost:8545, chainId 31337)
     ├── EuroToken      @ 0x5FbDB2315678afecb367f032d93F642f64180aa3 (deterministic)
     └── Ecommerce      @ 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 (deterministic)
   Next.js dev servers
     ├── compra-stablecoin :6001
     ├── payment-gateway   :6002
     ├── web-admin         :6003
     └── web-customer      :6004
```

`restart-all.sh` (at the repo root) is the conductor: it starts Anvil, deploys both contracts to
their **deterministic addresses** and validates them, seeds demo data, then launches the four dev
servers. The apps' `.env` files carry those deterministic addresses pre-configured (the script does
not rewrite them).
