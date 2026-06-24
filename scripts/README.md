# scripts (Component 7)

Local orchestration. The headline script is **`restart-all.sh`**, which lives at the **repo root**
(`../restart-all.sh`) — one command to boot the entire local stack from scratch.

## `restart-all.sh` — behavior
1. **Kills** any prior Anvil / Next.js processes and frees ports `8545` and `6001`–`6004`.
2. Starts **Anvil** (local EVM node, chainId `31337`) and waits until the RPC responds.
3. Deploys both contracts in one pass via `forge script DeployEcommerce.s.sol` and **validates** that
   the resulting addresses match the expected **deterministic** ones:
   - EuroToken `0x5FbDB2315678afecb367f032d93F642f64180aa3`
   - Ecommerce `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
4. **Seeds demo data**: company **TechShop** (id 1, owner = Anvil acct1), **3 products**
   (Smartphone, Laptop, Bicicleta), and **mints 1000 EURT to acct1**.
5. Starts the **4 Next.js apps** (`pnpm --filter <app> dev`) on ports 6001–6004 and waits for HTTP 200.

## Notes
- **Idempotent**: safe to re-run; it kills prior processes and Anvil starts with fresh in-memory state,
  so the deterministic addresses are reproduced on every run.
- The apps' `.env` files carry the deterministic addresses **pre-configured** — the script does **not**
  rewrite `.env` files.
- Logs are written to `/tmp/` (`/tmp/anvil.log`, `/tmp/app-6001.log`, …). Fails fast with clear errors
  if Anvil/Forge/pnpm are missing or a health check times out.
