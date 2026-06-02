# scripts (Component 7)

<!-- 🇪🇸 NOTA: Placeholder. El script restart-all.sh NO se crea funcional todavía porque depende
     de contratos que aún no existen. Aquí documentamos su "contrato de comportamiento" para
     implementarlo cuando EuroToken y Ecommerce estén listos. -->

Local orchestration scripts. The headline script is **`restart-all.sh`** — one command to boot the
entire local stack.

## `restart-all.sh` — planned behavior
1. Start **Anvil** (local EVM node, chainId `31337`).
2. Deploy **EuroToken** (Foundry `forge script`) → capture its address.
3. Deploy **Ecommerce** → capture its address.
4. **Wire `.env`**: write both addresses into each app's `.env` and into
   `@ecommerce-web3/shared-config`.
5. Start the **4 Next.js apps** in dev mode (via `pnpm` / Turborepo).

## Why it's documented-only for now (🇪🇸)
Pasos 2–5 dependen de contratos y apps que todavía no existen. Crear un script "roto" no aporta;
lo implementamos cuando lleguemos al componente 7, con todo lo demás ya en su sitio.

## Notes
- Must be idempotent: a clean restart wipes prior Anvil state and redeploys fresh.
- Should fail fast with clear errors if Anvil/Forge/pnpm are missing.
