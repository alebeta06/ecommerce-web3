# Deployment — Ethereum Sepolia

<!-- 🇪🇸 NOTA: Documentación de entrega del despliegue real en testnet. Las direcciones reales NO
     van en .env commiteados: viven en Vercel (env de producción) y en cada .env.local. -->

> **deploy_verificado** ✅ — Both contracts deployed and verified on Etherscan.

## Network

| Field    | Value             |
|----------|-------------------|
| Network  | Ethereum Sepolia  |
| chainId  | `11155111`        |
| Date     | 2026-06-26        |
| Block    | `11146508`        |
| Cost     | ~0.00386 ETH      |

## Deployed contracts

| Contract  | Address | Etherscan (verified) |
|-----------|---------|----------------------|
| EuroToken (EURT) | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3` | https://sepolia.etherscan.io/address/0x6d3b3054140fc52aeb63f7fb2467177f1aedbec3 |
| Ecommerce        | `0xf8db42Bd1c711b60a810a0790Af4eB5219df2764` | https://sepolia.etherscan.io/address/0xf8db42bd1c711b60a810a0790af4eb5219df2764 |

Both contracts were deployed in a single pass by
[`contracts/ecommerce/script/DeployEcommerce.s.sol`](../contracts/ecommerce/script/DeployEcommerce.s.sol),
which deploys `EuroToken(deployer)` first and then `Ecommerce(euroToken, admin)` wired to the freshly
deployed token. On Sepolia the addresses are **not deterministic** — they depend on the deployer's nonce.

## Roles

| Role | Account |
|------|---------|
| Deployer / owner (EuroToken minter) / platform admin (`DEFAULT_ADMIN_ROLE`) | **Alebeta Admin** `0x377307274977ac9E3b2b71BEaA8a1aC859FB1097` |

The deployer signs via a Foundry encrypted keystore (`--account alebeta-admin`); the private key is
never passed in plain text or committed.

## Verification

- **EuroToken** was verified from the **`contracts/euro-token`** project (its own Foundry root).
- **Ecommerce** was verified from the **`contracts/ecommerce`** project.

Both show **Pass - Verified** on Sepolia Etherscan.

### How to re-verify

Run from each contract's Foundry root, with `ETHERSCAN_API_KEY` exported (no keys in the repo):

```bash
# EuroToken — from contracts/euro-token
forge verify-contract \
  0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3 \
  src/EuroToken.sol:EuroToken \
  --chain sepolia \
  --constructor-args $(cast abi-encode "constructor(address)" 0x377307274977ac9E3b2b71BEaA8a1aC859FB1097) \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --watch

# Ecommerce — from contracts/ecommerce
forge verify-contract \
  0xf8db42Bd1c711b60a810a0790Af4eB5219df2764 \
  src/Ecommerce.sol:Ecommerce \
  --chain sepolia \
  --constructor-args $(cast abi-encode "constructor(address,address)" 0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3 0x377307274977ac9E3b2b71BEaA8a1aC859FB1097) \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --watch
```

> `EuroToken`'s constructor is `constructor(address initialOwner)`; `Ecommerce`'s is
> `constructor(address euroToken, address admin)`. Adjust the addresses if you redeploy.

## Next steps (not done here)

1. Seed demo data with [`contracts/ecommerce/script/SeedSepolia.s.sol`](../contracts/ecommerce/script/SeedSepolia.s.sol)
   (`ECOMMERCE_ADDRESS` / `EURO_TOKEN_ADDRESS` = the addresses above; `DEPLOYER` = Alebeta Admin;
   `DEMO_ACCOUNT` = the demo buyer).
2. Configure the apps' production env (Vercel) with these addresses, `NEXT_PUBLIC_CHAIN_ID=11155111`,
   the Sepolia RPC, and `NEXT_PUBLIC_NETWORK_NAME="Ethereum Sepolia"`.
