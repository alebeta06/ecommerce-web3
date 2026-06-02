# Ecommerce (Component 4)

<!-- 🇪🇸 NOTA: Placeholder. Proyecto Foundry que se inicializará tras EuroToken. -->

The **store logic** contract, built modularly with **6 Solidity libraries**. Handles companies,
products (with stock), customers, carts, invoices, and payments in EURT. Strict access control,
gas-optimized, target 80%+ test coverage.

## The 6 libraries
| Library      | Responsibility                          |
|--------------|------------------------------------------|
| `CompanyLib` | Company registration & management        |
| `ProductLib` | Product CRUD + stock (stores IPFS CID)    |
| `CustomerLib`| Customer management & history            |
| `CartLib`    | On-chain shopping cart                    |
| `InvoiceLib` | Invoice creation & lookup                 |
| `PaymentLib` | Payment processing (pull EURT, mark paid) |

## Planned structure (Foundry)
```
src/Ecommerce.sol
src/libraries/{CompanyLib,ProductLib,CustomerLib,CartLib,InvoiceLib,PaymentLib}.sol
test/                # one test file per library + integration tests
script/Deploy.s.sol
foundry.toml
lib/                 # openzeppelin-contracts, forge-std
```

## Key concepts (🇪🇸)
- **library en Solidity:** código reutilizable y enlazable que mantiene el contrato principal
  pequeño (límite de 24KB de bytecode) y mejora testabilidad y gas.
- **AccessControl:** control de acceso por roles (no un solo owner) para las acciones de admin.

See [`../../CLAUDE.md`](../../CLAUDE.md) §9 and [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §4.
