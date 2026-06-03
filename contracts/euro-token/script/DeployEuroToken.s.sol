// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// 🇪🇸 NOTA: forge-std/Script.sol da el contrato base `Script` (con el objeto `vm`)
// y `console2` para imprimir logs legibles durante la ejecución/simulación.
import {Script, console2} from "forge-std/Script.sol";
import {EuroToken} from "../src/EuroToken.sol";

/**
 * @title  DeployEuroToken
 * @notice Deployment script for the EURT stablecoin. Deploys EuroToken and mints an
 *         initial supply of 1,000,000 EURT to the deployer (who is also the owner).
 * @dev    Run a dry-run (no chain) with:
 *           forge script script/DeployEuroToken.s.sol -vvv
 *         Broadcast against a local Anvil node with:
 *           forge script script/DeployEuroToken.s.sol --rpc-url http://localhost:8545 --broadcast
 *
 * 🇪🇸 NOTA: Un "script" en Foundry es Solidity que se ejecuta off-chain para orquestar
 * despliegues. Lo que va dentro de startBroadcast/stopBroadcast se convierte en
 * transacciones firmadas (reales con --broadcast, simuladas sin él).
 */
contract DeployEuroToken is Script {
    // 🇪🇸 NOTA: Clave privada de la CUENTA 0 por defecto de Anvil (mnemónico estándar
    // "test test ... junk"). Es PÚBLICA y SOLO para desarrollo local — NUNCA usar en
    // producción ni con fondos reales. Sirve de fallback para que el script corra sin
    // configurar nada. Verificada con: cast wallet private-key --mnemonic "...".
    uint256 internal constant ANVIL_ACCOUNT_0 =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // 🇪🇸 NOTA: Mint inicial = 1.000.000 EURT en unidades base (6 decimales) => 1e12.
    uint256 internal constant INITIAL_MINT = 1_000_000e6;

    function run() external returns (EuroToken token) {
        // 🇪🇸 NOTA: vm.envOr lee la env var PRIVATE_KEY; si NO está definida, usa el
        // fallback de Anvil. Permite `PRIVATE_KEY=0x... forge script ...` en entornos
        // reales sin tocar el código.
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", ANVIL_ACCOUNT_0);
        address deployer = vm.addr(deployerKey);

        // 🇪🇸 NOTA: A partir de aquí, las llamadas se firman con `deployerKey`.
        vm.startBroadcast(deployerKey);

        // 🇪🇸 El deployer se convierte en el owner (único autorizado a mint()).
        token = new EuroToken(deployer);

        // 🇪🇸 Acuñamos el suministro inicial al propio deployer.
        token.mint(deployer, INITIAL_MINT);

        vm.stopBroadcast();

        // 🇪🇸 NOTA: Logs de auditoría del despliegue (visibles con -vvv).
        console2.log("=== EuroToken deployed ===");
        console2.log("Contract address :", address(token));
        console2.log("Deployer / owner :", deployer);
        console2.log("Decimals         :", token.decimals());
        console2.log("Deployer balance :", token.balanceOf(deployer));
        console2.log("Total supply     :", token.totalSupply());
    }
}
