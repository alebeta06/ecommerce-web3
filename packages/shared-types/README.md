# @ecommerce-web3/shared-types

<!-- 🇪🇸 NOTA: Placeholder. Tipos TS compartidos entre las apps. -->

Shared **TypeScript types** that mirror the on-chain domain (Product, Invoice, Customer, Cart,
Company, Payment…), so all four apps speak the same language as the contracts.

## Why this package exists (🇪🇸)
Define una vez la forma de cada entidad del dominio; las 4 apps importan los mismos tipos →
consistencia y autocompletado en todo el monorepo.

## Planned structure
```
src/
  index.ts          # re-exports
  product.ts        # Product, ProductInput…
  invoice.ts
  customer.ts
  cart.ts
  company.ts
package.json        # name: @ecommerce-web3/shared-types
```
