// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// 🇪🇸 NOTA: forge-std/Script.sol da el contrato base `Script` (con el objeto `vm`)
// y `console2` para imprimir logs legibles durante la ejecución/simulación.
import {Script, console2} from "forge-std/Script.sol";
import {EuroToken} from "euro-token/src/EuroToken.sol";
import {Ecommerce} from "../src/Ecommerce.sol";

/**
 * @title  DeployEcommerce
 * @notice Deployment script for the store. Deploys the EURT stablecoin (EuroToken) and the
 *         Ecommerce contract in a single pass, wiring the freshly deployed EURT address into
 *         Ecommerce's immutable `eurt`. Deploy-only: it seeds NO demo state.
 * @dev    Run a dry-run (no chain) with:
 *           forge script script/DeployEcommerce.s.sol -vvv
 *         Broadcast against a local Anvil node with:
 *           forge script script/DeployEcommerce.s.sol --rpc-url http://localhost:8545 --broadcast
 *         On a real network, pass the signing key via the CLI (e.g. --private-key / --account)
 *         and set DEPLOYER / ADMIN env vars to the intended addresses.
 *
 * 🇪🇸 NOTA: Un "script" en Foundry es Solidity que se ejecuta off-chain para orquestar
 * despliegues. Lo que va dentro de startBroadcast/stopBroadcast se convierte en
 * transacciones firmadas (reales con --broadcast, simuladas sin él).
 */
contract DeployEcommerce is Script {
    // 🇪🇸 NOTA: Address PÚBLICA de la CUENTA 0 por defecto de Anvil (mnemónico estándar
    // "test test ... junk"). SOLO para desarrollo local — NUNCA en producción. Sirve de
    // fallback para que el script corra sin configurar nada.
    address internal constant ANVIL_ACCOUNT_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external returns (EuroToken token, Ecommerce ecommerce) {
        // 🇪🇸 NOTA: vm.envOr lee la env var; si NO está definida, usa el fallback de Anvil.
        // DEPLOYER firma el despliegue y será el owner del token (único que puede mint()).
        // ADMIN recibe DEFAULT_ADMIN_ROLE en Ecommerce; por defecto coincide con el deployer.
        address deployer = vm.envOr("DEPLOYER", ANVIL_ACCOUNT_0);
        address admin = vm.envOr("ADMIN", deployer);

        // 🇪🇸 NOTA: A partir de aquí, las llamadas se emiten como `deployer`. Con address
        // (en vez de clave privada), el broadcast real toma la firma de la CLI; en simulación
        // y en tests basta con la address.
        vm.startBroadcast(deployer);

        // 🇪🇸 El deployer se convierte en el owner del token (autorizado a mint()).
        token = new EuroToken(deployer);

        // 🇪🇸 Ecommerce recibe la address del EURT recién desplegado (immutable) y el admin.
        ecommerce = new Ecommerce(address(token), admin);

        vm.stopBroadcast();

        // 🇪🇸 NOTA: Logs de auditoría del despliegue (visibles con -vvv).
        console2.log("=== Ecommerce deployed ===");
        console2.log("EuroToken :", address(token));
        console2.log("Ecommerce :", address(ecommerce));
        console2.log("Deployer  :", deployer);
        console2.log("Admin     :", admin);
    }
}
