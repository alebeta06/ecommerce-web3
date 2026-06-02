# EuroToken (Component 1)

<!-- 🇪🇸 NOTA: Placeholder. Proyecto Foundry que se inicializará en la PRÓXIMA sesión. -->

The **EURT stablecoin**: an ERC20 token pegged 1:1 to the EUR, with **6 decimals** (euro cents and
fractions). New EURT is minted only when a fiat payment clears (called by the buy-stablecoin app).

## Responsibilities
- ERC20 with 6 decimals (1 EUR = 1,000,000 base units).
- `mint(address to, uint256 amount)` restricted to the **owner** (Ownable).
- Audit **events** for mint and transfers.
- Complete **Foundry** tests (target 80%+ coverage).

## Planned structure (Foundry)
```
src/EuroToken.sol
test/EuroToken.t.sol
script/Deploy.s.sol
foundry.toml
lib/            # openzeppelin-contracts, forge-std (git submodules)
```

## Key concepts (🇪🇸)
- **6 decimales:** los decimales en ERC20 son solo de display; on-chain todo son enteros.
- **Ownable:** patrón de OpenZeppelin con un único `owner` con permisos privilegiados (mint).

See [`../../CLAUDE.md`](../../CLAUDE.md) §9 for rationale. Build commands in §7 (Foundry).
