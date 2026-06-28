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

## Seed

> **seed_verificado** ✅ — Demo data seeded on-chain via
> [`contracts/ecommerce/script/SeedSepolia.s.sol`](../contracts/ecommerce/script/SeedSepolia.s.sol)
> on 2026-06-27, block `11153098`, cost ~0.00103 ETH. Signed by Alebeta Admin (`--account alebeta-admin`).

**Company:** TechShop — `companyId 1`, owner & payoutWallet = Alebeta Admin
`0x377307274977ac9E3b2b71BEaA8a1aC859FB1097`.

**Products** (owner = TechShop; prices in base units, 6 decimals):

| Product | IPFS CID | Price | Stock |
|---------|----------|-------|-------|
| Smartphone | `bafkreib536nfcvmdjnaxmanfzrkkzpedsoxoypqyz7gppfehrfiyrf65hi` | `278990000` (278.99 EURT) | 7 |
| Laptop     | `bafkreiguxp3on6ouekheftx32qpt3ckpzsgzdkjt6iy6msozyv7irqrnyi` | `800990000` (800.99 EURT) | 4 |
| Bicicleta  | `bafkreiczboif47b47voibbru4ri4sfyk2ut3cdaiknj3asme3ueaiuzm4i` | `445990000` (445.99 EURT) | 8 |

**Mint:** 1000 EURT (`1000000000` base units) to **Cliente Demo** `0x34DF3...9cB7d`. Verified on-chain:
`balanceOf` = `1000000000`.

**Transactions** (block `11153098`):

| Action | Tx |
|--------|----|
| registerCompany (TechShop) | [`0x0a9956c2…81f3`](https://sepolia.etherscan.io/tx/0x0a9956c2d3456faaab6ca191dc921d41fa951d9e2e4de5001bb308a7237981f3) |
| addProduct (Smartphone) | [`0x46635cba…c23c`](https://sepolia.etherscan.io/tx/0x46635cba953b190d8de5f9da142e9bc9adfe0f230201f9c3798155358327c23c) |
| addProduct (Laptop / Bicicleta) | [`0x1aa4ddbd…39f8`](https://sepolia.etherscan.io/tx/0x1aa4ddbd6e2459eabc442ead17b0f7806783a881624ceef0da02fa92e639f831) · [`0xc5623bf0…5b93`](https://sepolia.etherscan.io/tx/0xc5623bf0e3bfd60cf65b8e453a703e7b2a4545d0bec54266d2eda52220eb5b93) |
| mint (1000 EURT → Cliente Demo) | [`0x5dde738e…bc5c`](https://sepolia.etherscan.io/tx/0x5dde738e8305a57fed52c699ae7f65f2c3b34c7bc3606e8205d109e6848ebc5c) |

## Next steps (not done here)

1. Configure the apps' production env (Vercel) with these addresses, `NEXT_PUBLIC_CHAIN_ID=11155111`,
   the Sepolia RPC, and `NEXT_PUBLIC_NETWORK_NAME="Ethereum Sepolia"`.
