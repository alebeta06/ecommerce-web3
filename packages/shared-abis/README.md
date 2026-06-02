# @ecommerce-web3/shared-abis

<!-- 🇪🇸 NOTA: Placeholder. Paquete TS que se poblará cuando los contratos estén compilados. -->

Single source of truth for the **contract ABIs** (EuroToken, Ecommerce), consumed by all four
Next.js apps via ethers.js.

> **ABI (Application Binary Interface):** the JSON descriptor that tells ethers.js which functions
> and events a contract exposes and how to encode/decode calls to them.

## Why this package exists (🇪🇸)
Sin esto, copiarías el ABI a mano en 4 apps cada vez que cambia un contrato → drift y bugs.
Aquí el ABI vive una sola vez; las apps lo importan.

## Planned structure
```
src/
  index.ts          # re-exports the ABIs
  EuroToken.json    # generated from forge build output
  Ecommerce.json
package.json        # name: @ecommerce-web3/shared-abis
```

ABIs are generated from Foundry's `out/` after `forge build` (wired in a future session).
