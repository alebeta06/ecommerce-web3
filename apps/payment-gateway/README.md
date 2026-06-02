# payment-gateway (Component 3)

<!-- 🇪🇸 NOTA: Placeholder. App Next.js que se inicializará más adelante. -->

Next.js 15 **payment gateway**. It receives payment parameters via the URL, connects MetaMask, and
executes the on-chain payment against the Ecommerce contract, then redirects back to the store.

## Responsibilities
- Read URL params: `merchant`, `amount`, `invoice`, `redirect`.
- Connect MetaMask (EIP-1193 provider) and ensure the right network (Anvil, chainId 31337).
- `approve()` the Ecommerce contract to spend EURT, then call `processPayment(invoice)`.
- Robust error handling (rejected tx, insufficient balance, wrong network) and post-payment redirect.

## Planned structure
```
src/app/            # the gateway page reading searchParams
src/components/      # connect button, payment steps UI, error states
src/hooks/           # useWallet, useContract
src/lib/             # ethers client, approve+pay logic
.env.example
```

## Key concepts (🇪🇸)
- **EIP-1193:** estándar de la API del proveedor de wallet (`window.ethereum`) que usa MetaMask.
- **approve + processPayment:** patrón ERC20 de 2 transacciones (autorizar gasto, luego cobrar).
- Recibir todo por URL **desacopla** la pasarela de cualquier tienda concreta.

See [`../../CLAUDE.md`](../../CLAUDE.md) for env vars and design rationale.
