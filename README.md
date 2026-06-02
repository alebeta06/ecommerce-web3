# 🛒 E-Commerce Web3 with Stablecoin

<!-- 🇪🇸 NOTA: Este README es la presentación pública del repo. Debe permitir a cualquier dev
     entender el proyecto y arrancarlo en minutos. CLAUDE.md es la guía profunda; este es el escaparate. -->

![Status](https://img.shields.io/badge/status-in%20development-orange)
![Solidity](https://img.shields.io/badge/Solidity-^0.8.x-363636?logo=solidity)
![Next.js](https://img.shields.io/badge/Next.js-15-black?logo=next.js)
![TypeScript](https://img.shields.io/badge/TypeScript-strict-3178C6?logo=typescript)
![Foundry](https://img.shields.io/badge/Foundry-Forge%20%7C%20Anvil%20%7C%20Cast-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A full-stack **Web3 e-commerce platform** powered by a **EUR-pegged stablecoin (EURT)**. Buy EURT
with a real credit card (Stripe), then spend it on-chain to purchase products from merchants. The
catalog, carts, invoices and payments all live on the blockchain — the web apps are thin clients
over on-chain state.

> Built as **Module 8** of the CodeCrypto Master's in *Blockchain & AI Systems Engineering*.
> Philosophy: **deep learning over speed** — real Stripe webhooks, real IPFS, 80%+ test coverage.

---

## 🏗️ Architecture

```
   ┌───────────────┐   card    ┌──────────────────┐  mint   ┌──────────────────────┐
   │  buy-stablecoin│ ────────► │     Stripe       │ ──────► │  EuroToken (ERC20)   │
   │   (Next.js)    │  webhook  │ (Payment Intents)│         │   EURT, 6 decimals   │
   └───────────────┘           └──────────────────┘         └──────────┬───────────┘
                                                                        │ EURT
   ┌───────────────┐  checkout  ┌──────────────────┐  approve+pay       ▼
   │  web-customer  │ ─────────► │ payment-gateway  │ ─────────► ┌──────────────────────┐
   │   (Next.js)    │            │   (Next.js)      │            │  Ecommerce contract  │
   └───────────────┘            └──────────────────┘            │  6 libraries:        │
   ┌───────────────┐  manage                                    │  Company/Product/    │
   │   web-admin    │ ──────────────────────────────────────►   │  Customer/Cart/      │
   │   (Next.js)    │   products (images → IPFS), invoices       │  Invoice/Payment     │
   └───────────────┘                                            └──────────────────────┘
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for detailed data flows and design rationale,
and [`CLAUDE.md`](CLAUDE.md) for the full developer guide.

---

## 🧰 Tech stack

**On-chain:** Solidity (latest stable) · Foundry (Forge/Anvil/Cast) · OpenZeppelin
**Off-chain:** Next.js 15 (App Router) · TypeScript (strict) · Tailwind CSS · ethers.js v6
**Integrations:** Stripe (real, with webhooks) · IPFS (Pinata) · MetaMask
**Tooling:** pnpm workspaces · Turborepo · Node 20 LTS

---

## 🚀 Quick start

> ⚠️ The project is in early scaffolding. Apps and contracts are not initialized yet — these steps
> describe the intended developer workflow and will become fully runnable as components land.

### Prerequisites
- [Node 20 LTS](https://nodejs.org) + [pnpm](https://pnpm.io) (`corepack enable`)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`foundryup`)
- [MetaMask](https://metamask.io) (configured for local Anvil, chainId `31337`)
- A Stripe test account and an IPFS provider account (Pinata) — needed for later components.

### Setup
```bash
git clone <repo-url> ecommerce-web3
cd ecommerce-web3
pnpm install            # install all workspace dependencies
cp apps/*/.env.example apps/*/.env   # then fill in your keys
./scripts/restart-all.sh             # boot Anvil, deploy contracts, start the 4 apps
```

---

## 📁 Project structure

```
ecommerce-web3/
├── apps/
│   ├── buy-stablecoin/     # Buy EURT with a credit card (Stripe)
│   ├── payment-gateway/    # MetaMask: approve + processPayment
│   ├── web-admin/          # Manage companies, products (IPFS), invoices, customers
│   └── web-customer/       # Catalog, cart, checkout, order history
├── contracts/
│   ├── euro-token/         # EuroToken ERC20 (EURT)
│   └── ecommerce/          # Ecommerce + 6 libraries
├── packages/
│   ├── shared-abis/        # Contract ABIs (single source of truth)
│   ├── shared-types/       # Shared TypeScript types
│   └── shared-config/      # Contract addresses, chain config
├── scripts/                # restart-all.sh (local orchestration)
├── docs/                   # ARCHITECTURE.md and more
└── CLAUDE.md               # Full developer & contributor guide
```

---

## 🗺️ Roadmap

- [ ] **0. Scaffolding & docs** — monorepo structure, CLAUDE.md, README, architecture *(current)*
- [ ] **1. EuroToken** — ERC20 (6 decimals), `mint()` with access control, events, Foundry tests
- [ ] **2. Ecommerce contract** — 6 libraries, access control, gas optimization, 80%+ coverage
- [ ] **3. Shared packages** — ABIs, types, config wiring
- [ ] **4. buy-stablecoin** — Stripe Payment Intents + webhooks + auto-mint
- [ ] **5. payment-gateway** — MetaMask approve + processPayment + redirect
- [ ] **6. web-admin** — companies, products w/ IPFS uploads, invoices, customers, dark mode
- [ ] **7. web-customer** — catalog, on-chain cart, checkout → gateway, order history, dark mode
- [ ] **8. restart-all.sh** — one-command local environment

---

## 📄 License

[MIT](LICENSE) © 2026 alebeta06
