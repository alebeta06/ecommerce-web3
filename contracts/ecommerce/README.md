# Ecommerce (Component 4)

The **store logic** contract, built modularly with **6 Solidity libraries**. Handles companies,
products (with stock), customers, carts, invoices, and payments in EURT. Role-based access
control, gas-conscious, target **80%+** test coverage.

> 🇪🇸 NOTA: El **diseño detallado y el porqué de cada decisión** están en
> [`./CLAUDE.md`](./CLAUDE.md). Este README es el resumen de alto nivel.

## The 6 libraries
| Library      | Responsibility                          |
|--------------|------------------------------------------|
| `CompanyLib` | Company registration & management        |
| `ProductLib` | Product CRUD + stock (stores IPFS CID)    |
| `CustomerLib`| Customer management & history            |
| `CartLib`    | On-chain shopping cart                    |
| `InvoiceLib` | Invoice creation & lookup                 |
| `PaymentLib` | Payment processing (pull EURT, mark paid) |

## Architecture decisions (summary)
- **Library pattern:** `internal` functions + `using-for` over structs stored in the
  `Ecommerce` contract (the contract owns all storage; libraries validate/mutate it).
- **Access control:** OpenZeppelin **`AccessControl`** (roles), not `Ownable` — multiple
  privileged actors (platform admin, company owners, customers). Product CRUD is gated by
  **per-company ownership**, not a global role.
- **Marketplace model:** **one invoice per company** (multi-vendor). `checkout()` splits the
  cart by company; each company is paid directly to its `payoutWallet`. A
  `processBatchPayments(uint256[])` lets a customer pay several invoices atomically in one tx.
- **EURT integration:** via OpenZeppelin **`IERC20`** + the token address passed to the
  constructor (`immutable`). The contract pulls EURT with `transferFrom` after the customer
  `approve`s it. No dependency on the `EuroToken` bytecode (only the ERC20 standard).
- **Safety:** custom errors (gas), events on critical operations, **CEI + `ReentrancyGuard`**
  on payments, stock reserved at checkout (restocked on cancellation).

## Structure (Foundry)
```
src/Ecommerce.sol
src/libraries/{CompanyLib,ProductLib,CustomerLib,CartLib,InvoiceLib,PaymentLib}.sol
test/                # one *.t.sol per library + Ecommerce.integration.t.sol
script/DeployEcommerce.s.sol
foundry.toml  remappings.txt
lib/                 # git submodules: forge-std v1.16.1, openzeppelin-contracts v5.1.0
```

## Key concepts (🇪🇸)
- **library en Solidity:** código reutilizable. Con funciones `internal` se *inlinea* en el
  contrato (organiza y habilita `using-for`); para reducir bytecode haría falta `external`
  + linking (contingencia si superamos el límite de 24KB).
- **using-for:** `using LibX for T;` permite llamar las funciones de la librería como métodos
  del tipo `T` (el primer parámetro `self` recibe el operando de la izquierda).
- **AccessControl:** control de acceso por roles (`bytes32`) en vez de un único `owner`.

See [`../../CLAUDE.md`](../../CLAUDE.md) §9 and [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §4.
