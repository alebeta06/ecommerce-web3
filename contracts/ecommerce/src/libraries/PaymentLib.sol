// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  PaymentLib
 * @notice Thin library that settles a payment by pulling EURT from the buyer to a seller wallet.
 * @dev    Stateless and storage-free: it only wraps `SafeERC20.safeTransferFrom`. Attached via
 *         `using PaymentLib for IERC20` so callers write `eurt.collect(from, to, amount)`.
 *
 * 🇪🇸 NOTA — modelo PULL (approve + transferFrom):
 *  - El cliente autoriza primero `approve(ecommerce, total)` sobre EURT (en la app payment-gateway).
 *    Luego `Ecommerce.checkout` ejecuta `collect`, que hace `transferFrom(cliente, payoutWallet, importe)`.
 *  - Usamos `SafeERC20`: revierte si el token devuelve `false` o no es estándar (no asume retorno bool).
 *
 * 🇪🇸 NOTA — por qué SIN validación y SIN ReentrancyGuard aquí:
 *  - Delgada a propósito: `checkout` garantiza `to = payoutWallet` no-cero (validado en `register`) y
 *    `amount = total > 0`. No añadimos ramas que `checkout` ya cubre (fuente única de verdad).
 *  - La protección anti-reentrancy es responsabilidad del orquestador: el modifier `nonReentrant`
 *    vive en `Ecommerce.checkout`, no en la librería (una lib `internal` se inlina; el guard debe
 *    envolver toda la operación checkout, no cada transferencia).
 */
library PaymentLib {
    using SafeERC20 for IERC20;

    /**
     * @notice Pull `amount` of `token` from `from` to `to` (requires a prior allowance).
     * @param token  The ERC20 being moved (EURT).
     * @param from   Payer address that must have approved this contract for at least `amount`.
     * @param to     Recipient address (the seller's `payoutWallet`).
     * @param amount Token amount in base units (EURT has 6 decimals).
     *
     * 🇪🇸 NOTA: `safeTransferFrom` revierte ante allowance/balance insuficiente o token no conforme;
     * no hace falta comprobar el valor de retorno manualmente.
     */
    function collect(IERC20 token, address from, address to, uint256 amount) internal {
        token.safeTransferFrom(from, to, amount);
    }
}
