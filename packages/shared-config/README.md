# @ecommerce-web3/shared-config

<!-- 🇪🇸 NOTA: Placeholder. Direcciones de contratos + config de red. -->

Shared **configuration**: deployed contract **addresses**, chain config (Anvil chainId `31337`,
RPC URL), and small env helpers. Updated automatically by `restart-all.sh` on every redeploy.

## Why this package exists (🇪🇸)
Las direcciones de los contratos cambian en cada despliegue local. Centralizarlas aquí (y que el
script las reescriba) evita editar 4 `.env` a mano cada vez.

## Planned structure
```
src/
  index.ts          # exports addresses + chain config
  addresses.ts      # { euroToken, ecommerce } — rewritten by restart-all.sh
  chains.ts         # anvil: { id: 31337, rpcUrl: 'http://localhost:8545' }
package.json        # name: @ecommerce-web3/shared-config
```
