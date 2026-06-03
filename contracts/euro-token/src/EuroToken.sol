// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: El identificador SPDX declara la licencia del código. Es obligatorio
// (o el compilador avisa). MIT = licencia permisiva, estándar en open source.
pragma solidity 0.8.28;

// 🇪🇸 NOTA: Importamos dos contratos base de OpenZeppelin (auditados y estándar):
//  - ERC20:   implementa el estándar de token fungible (balances, transfer, approve…).
//  - Ownable: patrón de control de acceso con un único "owner" con permisos especiales.
// El remapping "@openzeppelin/" (ver foundry.toml) apunta a lib/openzeppelin-contracts/.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  EuroToken (EURT)
 * @notice EUR-pegged stablecoin (1 EURT == 1 EUR) with 6 decimals. New EURT is minted
 *         only by the owner — in this system, the buy-stablecoin webhook wallet — after
 *         a fiat (Stripe) payment clears.
 * @dev    Inherits ERC20 (token logic) + Ownable (access control for mint()).
 *
 * 🇪🇸 NOTA: Esta es la "moneda" de todo el e-commerce. El resto de componentes la usan
 * para pagar. La regla central: solo se crea EURT cuando entra dinero real (tarjeta).
 */
contract EuroToken is ERC20, Ownable {
    /**
     * @notice Emitted when new EURT is minted, for off-chain auditing.
     * @param to     Recipient of the freshly minted tokens.
     * @param amount Amount minted, in base units (6 decimals).
     *
     * 🇪🇸 NOTA: ERC20._mint() ya emite un Transfer(address(0) -> to). Añadimos este
     * evento Mint SEMÁNTICO (con `to` indexed para poder filtrarlo eficientemente en
     * los logs) porque "crear dinero" es un hecho auditable que queremos rastrear
     * de forma explícita, separado de las transferencias normales.
     */
    event Mint(address indexed to, uint256 amount);

    /**
     * @param initialOwner Address that will hold the mint privilege.
     *
     * 🇪🇸 NOTA: En OpenZeppelin v5, Ownable EXIGE recibir el owner inicial en el
     * constructor: `Ownable(initialOwner)`. En v4 el owner era msg.sender implícito.
     * ERC20 recibe el nombre y el símbolo del token.
     */
    constructor(address initialOwner) ERC20("EuroToken", "EURT") Ownable(initialOwner) {}

    /**
     * @notice Number of decimals used for display.
     * @return Always 6 (1 EUR == 1_000_000 base units), like USDC.
     *
     * 🇪🇸 NOTA: Los decimales en ERC20 son SOLO de display; on-chain todo son enteros.
     * Por defecto ERC20 devuelve 18; lo sobreescribimos a 6. Usamos `pure` porque el
     * valor es constante (restringir view -> pure en un override es válido en Solidity).
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Mint new EURT to an address. Restricted to the owner.
     * @param to     Recipient address.
     * @param amount Amount to mint, in base units (6 decimals).
     *
     * 🇪🇸 NOTA: `onlyOwner` (de Ownable) hace revert con el error custom
     * OwnableUnauthorizedAccount(msg.sender) si quien llama no es el owner.
     * `_mint` es la función interna de ERC20 que crea los tokens y sube el totalSupply.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Mint(to, amount);
    }
}
