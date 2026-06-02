# CLAUDE.md — E-Commerce Web3 with Stablecoin

> Master guide for this monorepo. Read this first. It is written for both Claude Code and human
> contributors. Project files are in **English** (open-source standard); pedagogical notes are
> embedded in **Spanish** using `<!-- 🇪🇸 NOTA -->` (Markdown) and `// 🇪🇸 NOTA` (code).

<!-- 🇪🇸 NOTA: Este archivo es la "fuente de verdad" del proyecto. Cuando Claude o un dev nuevo
     abran el repo, este documento explica QUÉ es, CÓMO está organizado y POR QUÉ se tomó cada
     decisión. Mantenerlo actualizado es parte del trabajo. -->

---

## 1. What is this project?

A full-stack **Web3 e-commerce system** built around a **EUR-pegged stablecoin (EURT)**.
A customer buys EURT with a real credit card (via Stripe), then spends that EURT on-chain to buy
products from merchants. Everything that matters — token balances, the product catalog, carts,
invoices and payments — lives on a blockchain. The web apps are just windows into on-chain state.

It is **Module 8** of the CodeCrypto Master's in *Blockchain & AI Systems Engineering*. The goal is
**deep learning, not a quick MVP**: real Stripe with working webhooks, real IPFS, 80%+ test
coverage, professional documentation.

The system has **7 integrated components** (see §3).

---

## 2. Working philosophy & conventions

<!-- 🇪🇸 NOTA: Estas reglas existen para que el aprendizaje sea profundo y reproducible. -->

- **Deep learning > speed.** No shortcuts, no MVP mindset. Understand every layer.
- **Language:** assistant replies in **Spanish**; explains each technical decision as if teaching
  a mid-level dev. **Project files in English.** Pedagogical notes embedded in Spanish:
  - Markdown: `<!-- 🇪🇸 NOTA: ... -->`
  - TypeScript / Solidity: `// 🇪🇸 NOTA: ...`
- **Explain advanced terms on first use** (EIP-2771, AccessControl, webhooks, Payment Intents…).
- **Quality bars:** Stripe must be REAL with functional webhooks · IPFS must be REAL ·
  test coverage target **80%+** · TypeScript in **strict** mode · robust input validation at every
  system boundary.
- **File hygiene:** keep files under ~500 lines; never commit secrets or `.env` files; read a file
  before editing it; do not create files unless necessary.

---

## 3. System architecture

Seven components, two "worlds" (on-chain Solidity vs. off-chain Next.js), glued by shared packages.

```
                         ┌───────────────────────────────────────────────┐
                         │                  USER (browser)                │
                         │                  + MetaMask wallet             │
                         └───────────────────────────────────────────────┘
                            │            │              │            │
            ┌───────────────┘            │              │            └───────────────┐
            ▼                            ▼              ▼                            ▼
   ┌──────────────────┐      ┌────────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │ (2) buy-stablecoin│     │ (6) web-customer   │  │ (5) web-admin    │  │ (3) payment-     │
   │     Next.js       │     │     Next.js        │  │     Next.js      │  │     gateway      │
   │ Buy EURT w/ card  │     │ Catalog, cart,     │  │ Companies, prods │  │  Next.js         │
   │ via Stripe        │     │ checkout, orders   │  │ (IPFS img), inv. │  │ approve + pay    │
   └──────────────────┘      └────────────────────┘  └──────────────────┘  └──────────────────┘
            │ Stripe                    │  reads/writes        │  reads/writes        │ approve+
            │ webhook                   │                      │                      │ processPayment
            ▼                           ▼                      ▼                      ▼
   ┌──────────────────┐      ╔══════════════════════════════════════════════════════════════╗
   │  Stripe (cards,  │      ║                    BLOCKCHAIN (Anvil / EVM)                   ║
   │  Payment Intents)│      ║                                                              ║
   └──────────────────┘      ║   ┌────────────────────┐        ┌──────────────────────────┐ ║
            │ on payment      ║   │ (1) EuroToken      │  EURT  │ (4) Ecommerce            │ ║
            │ success         ║   │     ERC20, 6 dec.  │◄──────►│   CompanyLib ProductLib  │ ║
            └──────mint()────►║   │     mint() owner   │ transfer│  CustomerLib CartLib     │ ║
                              ║   └────────────────────┘        │  InvoiceLib  PaymentLib  │ ║
                              ║                                  └──────────────────────────┘ ║
                              ╚══════════════════════════════════════════════════════════════╝

   Shared packages (imported by all apps):  @ecommerce-web3/shared-abis · shared-types · shared-config
   Off-chain storage:  IPFS (Pinata / web3.storage) for product images
   (7) scripts/restart-all.sh  →  boots Anvil, deploys both contracts, wires .env, starts the 4 apps
```

**Reading the diagram:** the four Next.js apps never own data — they read from and write to the two
smart contracts. EuroToken is the money; Ecommerce is the store logic. Stripe sits *outside* the
chain and triggers an on-chain `mint()` when a card payment succeeds. The shared packages are the
plumbing that keeps the four apps in sync with the contracts (see §6).

---

## 4. Tech stack by component

| # | Component        | Type            | Core tech                                                        |
|---|------------------|-----------------|------------------------------------------------------------------|
| 1 | EuroToken        | Smart contract  | Solidity, Foundry, OpenZeppelin (ERC20 + Ownable), 6 decimals    |
| 2 | buy-stablecoin   | Next.js app     | Next.js 15 (App Router), TS strict, Stripe SDK + webhooks, ethers v6 |
| 3 | payment-gateway  | Next.js app     | Next.js 15, TS strict, ethers v6, MetaMask (EIP-1193), URL params |
| 4 | Ecommerce        | Smart contract  | Solidity, Foundry, 6 libraries, AccessControl, gas optimization  |
| 5 | web-admin        | Next.js app     | Next.js 15, TS strict, ethers v6, IPFS (Pinata), Tailwind, dark mode |
| 6 | web-customer     | Next.js app     | Next.js 15, TS strict, ethers v6, Tailwind, dark mode            |
| 7 | restart-all.sh   | Bash script     | Anvil, Forge, Cast — local orchestration                         |
| — | shared packages  | TS libraries    | shared-abis, shared-types, shared-config                         |

**Cross-cutting:** Solidity (latest stable) · Foundry (Forge/Anvil/Cast) · OpenZeppelin ·
Next.js 15 · TypeScript strict · Tailwind CSS · ethers.js v6 · Stripe (real) · IPFS · MetaMask ·
pnpm workspaces + Turborepo.

---

## 5. Monorepo structure

```
ecommerce-web3/
├── apps/            buy-stablecoin · payment-gateway · web-admin · web-customer   (deployable)
├── contracts/       euro-token · ecommerce                                        (Foundry)
├── packages/        shared-abis · shared-types · shared-config                    (importable libs)
├── scripts/         restart-all.sh (local orchestration)
├── docs/            ARCHITECTURE.md (+ future: STRIPE.md, IPFS.md, …)
├── CLAUDE.md  README.md  LICENSE  .gitignore
└── package.json  pnpm-workspace.yaml  turbo.json  .nvmrc
```

- `apps/` = what gets **deployed and runs**. `packages/` = what apps **import**. `contracts/` = the
  Solidity world with its own toolchain (Forge), isolated from Node.

### Naming conventions
- Folders & packages: `kebab-case`. Internal npm package names: `@ecommerce-web3/<name>`.
- Solidity contracts: `PascalCase` (`EuroToken.sol`); libraries suffixed `Lib` (`ProductLib`).
- React components: `PascalCase`. Hooks: `useCamelCase` (`useWallet`, `useContract`).
- Env vars: browser-exposed use `NEXT_PUBLIC_` prefix; secrets have **no** prefix (server-only).

### Recommended internal layout (filled in future sessions)
- **Next.js app:** `src/app/` · `src/components/` · `src/hooks/` · `src/lib/` · `src/types/` ·
  `public/` · `.env.example`.
- **Foundry project:** `src/` · `test/` · `script/` · `foundry.toml` · `lib/` (git submodules).
- **Package:** `src/index.ts` + minimal `package.json`.

---

## 6. Shared packages — single source of truth

<!-- 🇪🇸 NOTA: Este es el corazón de por qué usamos monorepo. Sin esto, copiarías el ABI de un
     contrato a mano en 4 apps cada vez que cambia. Con esto, hay UNA copia y todas la importan. -->

- **`@ecommerce-web3/shared-abis`** — the ABIs of EuroToken and Ecommerce, generated from the
  compiled contracts. *ABI = Application Binary Interface: the JSON "contract" that tells ethers.js
  which functions/events exist and how to encode calls to them.*
- **`@ecommerce-web3/shared-types`** — TypeScript types shared across apps (Product, Invoice,
  Customer, Cart…), so the front-end speaks the same language as the contracts.
- **`@ecommerce-web3/shared-config`** — deployed contract **addresses**, chain config (Anvil
  chainId `31337`, RPC URL), and small env helpers. Updated automatically by `restart-all.sh`.

---

## 7. Common commands

> 🇪🇸 NOTA: Estos comandos asumen que ya se instalaron dependencias (futuras sesiones).
> En esta sesión de scoping NO ejecutamos ninguno.

### Monorepo (pnpm + Turborepo)
```bash
pnpm install                 # install all workspace deps (run once at root)
pnpm dev                     # turbo run dev — start all apps in dev mode
pnpm build                   # turbo run build — build everything (cached)
pnpm test                    # turbo run test
pnpm --filter web-admin dev  # run a task for ONE workspace only
```

### Foundry (inside contracts/euro-token or contracts/ecommerce)
```bash
forge build                  # compile contracts
forge test -vvv              # run tests (verbose)
forge coverage               # coverage report (target 80%+)
forge fmt                    # format Solidity
anvil                        # start local EVM node (chainId 31337)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <KEY>
cast call <ADDR> "totalSupply()(uint256)" --rpc-url http://localhost:8545   # read on-chain
```

### Local full system
```bash
./scripts/restart-all.sh     # (future) Anvil → deploy → wire .env → start 4 apps
```

---

## 8. Environment variables (per app)

> 🇪🇸 NOTA: `NEXT_PUBLIC_*` = expuestas al navegador (no secretas). El resto son SOLO de servidor
> (Stripe secret key, webhook secret, IPFS JWT) y nunca deben llevar el prefijo público.
> Las plantillas reales están en cada `apps/<app>/.env.example`.

| App             | Variable                          | Secret? | Purpose                                  |
|-----------------|-----------------------------------|---------|------------------------------------------|
| buy-stablecoin  | `NEXT_PUBLIC_RPC_URL`             | no      | RPC endpoint (Anvil)                     |
|                 | `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | no      | EuroToken contract address               |
|                 | `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | no   | Stripe client key                        |
|                 | `STRIPE_SECRET_KEY`               | **yes** | Stripe server key (create Payment Intent)|
|                 | `STRIPE_WEBHOOK_SECRET`           | **yes** | Verify Stripe webhook signatures         |
|                 | `MINTER_PRIVATE_KEY`              | **yes** | Wallet allowed to call `mint()`          |
| payment-gateway | `NEXT_PUBLIC_RPC_URL`             | no      | RPC endpoint                             |
|                 | `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | no      | For `approve()`                          |
|                 | `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | no      | For `processPayment()`                   |
| web-admin       | `NEXT_PUBLIC_RPC_URL`             | no      | RPC endpoint                             |
|                 | `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | no      | Ecommerce contract                       |
|                 | `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | no      | EuroToken contract                       |
|                 | `PINATA_JWT`                      | **yes** | IPFS uploads (product images)            |
|                 | `NEXT_PUBLIC_IPFS_GATEWAY`        | no      | Public gateway to read IPFS content      |
| web-customer    | `NEXT_PUBLIC_RPC_URL`             | no      | RPC endpoint                             |
|                 | `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | no      | Ecommerce contract                       |
|                 | `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | no      | EuroToken contract                       |
|                 | `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` | no      | Where checkout redirects to pay          |
|                 | `NEXT_PUBLIC_IPFS_GATEWAY`        | no      | Read product images                      |

---

## 9. Key technical decisions (with rationale)

<!-- 🇪🇸 NOTA: Aquí documentamos el POR QUÉ. Cuando vuelvas en 3 meses, esto te ahorra reabrir
     debates ya cerrados. -->

1. **Monorepo with pnpm workspaces + Turborepo.** Industry-standard layout for Web3 mono­repos.
   pnpm links dependencies instead of duplicating them (disk-efficient); Turborepo caches builds.
2. **6-decimal EURT.** "1:1 with EUR" + 6 decimals means the smallest unit is a *cent's* fraction
   (1 EUR = 1,000,000 base units). *Decimals in ERC20 are purely cosmetic for display;* on-chain
   everything is integers. 6 decimals (like USDC) keeps numbers small and avoids 18-decimal
   overkill for a fiat-pegged token.
3. **`mint()` access control — Ownable on EuroToken.** *Ownable = a simple OpenZeppelin pattern
   with one `owner` who holds privileged rights.* Only the owner (the minter wallet, called by the
   buy-stablecoin webhook) can mint new EURT, mirroring "money is only created when a card payment
   clears."
4. **AccessControl (role-based) on Ecommerce.** *AccessControl = OpenZeppelin's role-based access:
   instead of one owner, you define roles (e.g. `ADMIN_ROLE`) and grant them to addresses.* The
   store has several privileged actions (register company, CRUD products) that benefit from roles
   rather than a single owner. We explain the Ownable-vs-AccessControl trade-off when we build it.
5. **Modular Ecommerce with 6 libraries.** *A Solidity `library` is reusable code that can be
   `delegatecall`-ed or linked, keeping the main contract small and under bytecode/size limits.*
   Splitting Company/Product/Customer/Cart/Invoice/Payment logic improves readability, testability
   and gas, and avoids the 24KB contract size limit.
6. **Stripe Payment Intents + webhooks (real).** *A Payment Intent is Stripe's object tracking a
   payment's lifecycle.* *A webhook is an HTTP callback Stripe sends to our server when an event
   happens (e.g. `payment_intent.succeeded`).* We mint EURT **only** after verifying the webhook
   signature — never trust the browser to confirm payment.
7. **ethers.js v6.** Latest major version; note API differences vs v5 (e.g. `parseUnits`,
   `BrowserProvider`, `Contract` constructor) — we'll flag them when coding.
8. **EIP-2771 (gasless meta-transactions) = OPTIONAL, not core.** *EIP-2771 lets a "trusted
   forwarder" relay a user's transaction so a third party pays the gas (gasless UX).* Our defined
   flow has the user pay gas via MetaMask (`approve` + `processPayment`), so we do **not** assume
   gasless. We may revisit it as an advanced topic later — we avoid over-engineering now.
9. **IPFS via Pinata (default).** *IPFS = content-addressed distributed storage; you get back a CID
   (a hash) instead of a URL.* Product images are uploaded to IPFS so the on-chain product only
   stores a small CID, not the image bytes (storing bytes on-chain would be prohibitively expensive).

---

## 10. Learning plan (suggested build order)

<!-- 🇪🇸 NOTA: El orden importa: cada componente desbloquea al siguiente. -->

1. **EuroToken** (contract 1) — the money. Foundry + OpenZeppelin + tests. *(next session)*
2. **Ecommerce** (contract 4) — the store logic with 6 libraries + tests.
3. **shared-abis / shared-types / shared-config** — wire contracts to the front-end.
4. **buy-stablecoin** (app 2) — Stripe + webhook + mint.
5. **payment-gateway** (app 3) — MetaMask approve + processPayment.
6. **web-admin** (app 5) — companies, products (IPFS), invoices, customers.
7. **web-customer** (app 6) — catalog, cart, checkout → gateway, order history.
8. **restart-all.sh** (script 7) — orchestrate the whole local system.

---

## 11. External references

- **OpenZeppelin Contracts:** https://docs.openzeppelin.com/contracts
- **Foundry Book:** https://book.getfoundry.sh
- **Solidity docs:** https://docs.soliditylang.org
- **Next.js (App Router):** https://nextjs.org/docs
- **ethers.js v6:** https://docs.ethers.org/v6/
- **Stripe (Payment Intents):** https://stripe.com/docs/payments/payment-intents
- **Stripe webhooks:** https://stripe.com/docs/webhooks
- **Pinata (IPFS):** https://docs.pinata.cloud
- **Turborepo:** https://turbo.build/repo/docs
- **pnpm workspaces:** https://pnpm.io/workspaces
