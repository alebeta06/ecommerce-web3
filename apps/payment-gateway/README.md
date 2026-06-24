# payment-gateway (Component 3)

Next.js 15 **payment gateway** (port 6002). It receives payment parameters via the URL, connects
MetaMask, and executes the on-chain payment against the Ecommerce contract, then redirects back to
the store.

## Responsibilities
- Read URL params in two formats: the **new** one from checkout — `invoices=ID1,ID2&redirect=URL` —
  and a **legacy** one — `merchant_address&amount&invoice&date&redirect`.
- Connect MetaMask (EIP-1193 provider) and ensure the right network (Anvil, chainId 31337).
- `approve()` the Ecommerce contract for the **exact amount** (not `MaxUint256`), then call
  `processPayment(invoiceId)` / `processBatchPayments(invoiceIds)`.
- Robust error handling (rejected tx, insufficient balance, wrong network) and post-payment redirect
  (with `^https?://` validation against open redirects).

## Structure
```
src/app/            # the gateway page reading searchParams
src/components/      # PayClient / LegacyPayClient, payment steps UI, error states
src/hooks/           # useWallet, useContract
src/lib/             # ethers client, approve+pay logic, parseEurt (format.ts)
.env.example
```

## Key concepts (🇪🇸)
- **EIP-1193:** estándar de la API del proveedor de wallet (`window.ethereum`) que usa MetaMask.
- **approve + processPayment:** patrón ERC20 de 2 transacciones (autorizar gasto, luego cobrar).
- Recibir todo por URL **desacopla** la pasarela de cualquier tienda concreta.

See [`../../CLAUDE.md`](../../CLAUDE.md) for env vars and design rationale.
