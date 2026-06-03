# CLAUDE.md — Ecommerce (Component 4) Design Guide

> Design rationale for the `Ecommerce` smart contract. Read together with the root
> [`../../CLAUDE.md`](../../CLAUDE.md). Files in **English**; pedagogical notes in **Spanish**
> as `<!-- 🇪🇸 NOTA -->` / `// 🇪🇸 NOTA`.

---

## 1. What this contract is

The on-chain **store logic** of the system: companies, products (with stock + IPFS image CID),
customers, on-chain carts, invoices and EURT payments. Built modularly with **6 Solidity
libraries**. It is the second contract of Módulo 8 and **consumes** the `EuroToken` (EURT)
stablecoin from Component 1 to settle payments.

---

## 2. Library pattern — `internal` + `using-for`

- The **`Ecommerce` contract owns ALL storage** (mappings of structs). Each library provides
  (a) its entity `struct` and (b) `internal` functions that validate/mutate that storage via
  a `storage` pointer (`self`).
- Libraries **do not call each other** — the contract orchestrates the flow.
- `using LibX for T;` lets us call library functions as methods on `T`
  (e.g. `products.add(...)`, `product.decreaseStock(qty)`).

<!-- 🇪🇸 NOTA: funciones `internal` => el compilador las INLINEA en el contrato. Organizan y
     habilitan using-for, pero NO reducen el bytecode. Si superamos el límite de 24KB,
     migramos selectivamente 1-2 librerías a `external` + linking (delegatecall). Decisión
     guiada por el tamaño REAL medido, no a priori. -->

| Library | Struct | Core `internal` functions |
|---------|--------|---------------------------|
| `CompanyLib`  | `Company{ id, owner, name, payoutWallet, exists }` | `register`, `get`, `requireExists` |
| `ProductLib`  | `Product{ id, companyId, name, ipfsCid, price, stock, active }` | `add`, `update`, `decreaseStock`, `increaseStock`, `requireInStock` |
| `CustomerLib` | `Customer{ wallet, registered, invoiceIds[] }` | `register`, `get`, `pushInvoice` |
| `CartLib`     | `Item{ productId, quantity }` | `addItem`, `items`, `clear` |
| `InvoiceLib`  | `Invoice{ id, customer, companyId, items[], total, status, createdAt, paidAt }` | `create`, `get`, `markPaid` |
| `PaymentLib`  | — (operates on `Invoice` + `IERC20`) | `process` (pull EURT, CEI) |

---

## 3. Marketplace model — ONE INVOICE PER COMPANY (multi-vendor)

`checkout()` splits the cart by company and creates **one invoice per company** present in the
cart. Each company is paid **directly** to its `payoutWallet`.

**Why this model (decision rationale):**
1. It is the **real multi-vendor marketplace** model (Etsy, Amazon, MercadoLibre).
2. Money goes **directly to each seller** — no intermediary custody, no operator risk.
3. Coherent with the spec: `processPayment(invoiceId)` settles **one** invoice.
4. **Perfect traceability:** each company sees only **its own** invoices.
5. Aligns with the "learn deeply" philosophy: solve the problem **on-chain** instead of
   pushing it to a backend.

### Batch payments (UX improvement, same model)
`processBatchPayments(uint256[] invoiceIds)` pays several invoices (possibly across **multiple
companies**) in a **single transaction**. Better UX without breaking the multi-vendor model —
each invoice is still settled to its own `payoutWallet`.
- **Atomic (all-or-nothing)** + `nonReentrant`: reuses an internal `_processPayment(id)` in a
  loop; if any invoice fails (no allowance, already paid…), the **whole tx reverts** → no
  partial payments, consistent state.
- The input array length is **bounded** to stay within the block gas limit.

---

## 4. Access control — `AccessControl` (roles), not `Ownable`

The system has **several privileged actors**, so role-based access fits better than a single
owner:
- `DEFAULT_ADMIN_ROLE` → platform admin: can `registerCompany` and manage roles.
- **Product CRUD** is gated by **per-company ownership** (`msg.sender == company.owner`, via a
  `companyOf` mapping), because the permission is per-company, not global.

<!-- 🇪🇸 NOTA: AccessControl = roles (bytes32) que se conceden a direcciones. Ownable (un solo
     owner) no modela admin-de-plataforma + dueños-de-empresa + clientes. Ver raíz §9.4. -->

---

## 5. EURT integration

- Import **`IERC20`** from OpenZeppelin (`@openzeppelin/contracts/token/ERC20/IERC20.sol`).
  We only need `transferFrom` / `balanceOf` / `allowance`; **not** the `EuroToken` bytecode.
- The EURT address is passed to the **constructor** and stored as `IERC20 public immutable eurt;`.
- Flow: customer `approve(ecommerce, total)` on EuroToken (payment-gateway app) → then
  `Ecommerce.processPayment` runs `eurt.transferFrom(customer, payoutWallet, total)`.

---

## 6. Cross-cutting technical decisions

| Topic | Decision | Why |
|-------|----------|-----|
| Solidity | `0.8.28` exact (same as EuroToken) | Toolchain/bytecode coherence; OZ v5 requires ≥0.8.20. |
| OZ Contracts | `v5.1.0` (same pins as euro-token) | Reproducibility; validated submodules. |
| Errors | **Custom errors** | Cheaper gas; consistent with OZ v5 / EuroToken. |
| Events | Only on **critical ops** | `CompanyRegistered`, `ProductAdded/Updated`, `InvoiceCreated`, `PaymentProcessed` (indexed). |
| Stock | Reserved at **checkout**; restocked on cancel | Avoids overselling vs reserving at `addToCart`. |
| Payments | **CEI + `ReentrancyGuard`** | External `transferFrom`; mark `Paid` before the interaction. |

---

## 7. Known technical risks (track while coding)

1. **Stack too deep** in `checkout`-like functions → group locals in `structs`, use `{}` scope
   blocks, fallback `via_ir = true` in `foundry.toml`.
2. **Reentrancy** in `processPayment` / `processBatchPayments` → CEI + `nonReentrant`.
3. **Gas / unbounded loops** in `getAllProducts`, cart-by-company split, batch payments →
   `view` where possible, bound array lengths, `delete` on `clearCart`.
4. **Stock validation** → `requireInStock` before reserving; 0.8 reverts on underflow.
5. **Storage layout** → low risk with `internal` libs (no delegatecall); becomes relevant only
   if we migrate to external-linked libraries.

---

## 8. Build order (sessions)

| Session | Scope |
|---------|-------|
| 1 (done) | Scoping + Foundry setup (this file, `foundry.toml`, submodules, folders) |
| 2 | `CompanyLib` + `ProductLib` (+ base storage in `Ecommerce.sol`) + tests |
| 3 | `CustomerLib` + `CartLib` + tests |
| 4 | `InvoiceLib` + `PaymentLib` + EURT integration (`IERC20`, `ReentrancyGuard`) |
| 5 | E2E integration tests, `forge coverage` ≥80%, `DeployEcommerce.s.sol`, dry-run deploy |
