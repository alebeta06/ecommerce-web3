# EuroToken (Component 1)

The **EURT stablecoin**: an ERC20 token pegged 1:1 to the EUR, with **6 decimals** (euro cents and
fractions). New EURT is minted only when a fiat payment clears (called by the compra-stablecoin app).

## Responsibilities
- ERC20 with 6 decimals (1 EUR = 1,000,000 base units).
- `mint(address to, uint256 amount)` restricted to the **owner** (Ownable).
- Audit **events** for mint and transfers.
- **8 Foundry tests**, **100% coverage** of `EuroToken.sol` (lines/statements/branches/functions),
  measured with `forge coverage`. The aggregate Total drops only because the deploy script
  (`script/DeployEuroToken.s.sol`) is not unit-tested.

## Structure (Foundry)
```
src/EuroToken.sol
test/EuroToken.t.sol
script/DeployEuroToken.s.sol
foundry.toml
lib/            # openzeppelin-contracts, forge-std (git submodules)
```

## Key concepts (🇪🇸)
- **6 decimales:** los decimales en ERC20 son solo de display; on-chain todo son enteros.
- **Ownable:** patrón de OpenZeppelin con un único `owner` con permisos privilegiados (mint).

See [`../../CLAUDE.md`](../../CLAUDE.md) §9 for rationale. Build commands in §7 (Foundry).
