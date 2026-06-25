// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// 🇪🇸 NOTA: forge-std/Script.sol da el contrato base `Script` (con el objeto `vm`)
// y `console2` para imprimir logs legibles durante la ejecución/simulación.
import {Script, console2} from "forge-std/Script.sol";
import {EuroToken} from "euro-token/src/EuroToken.sol";
import {Ecommerce} from "../src/Ecommerce.sol";

/**
 * @title  SeedSepolia
 * @notice Reproducible demo seed for a live network (e.g. Ethereum Sepolia). Mirrors the seed that
 *         `restart-all.sh` performs via `cast` on Anvil, but as a reproducible Solidity script.
 *         Parametrized ONLY by environment variables — it hardcodes NO keys and NO addresses.
 *         It does NOT deploy: it expects the contracts to be already deployed.
 *
 * @dev    Env vars (REQUIRED — read with vm.envAddress, which reverts if missing; no fallbacks, so
 *         nothing local leaks into the repo):
 *           ECOMMERCE_ADDRESS    deployed Ecommerce contract
 *           EURO_TOKEN_ADDRESS   deployed EuroToken (EURT) contract
 *           DEPLOYER             admin account. ROLE MAP: it is simultaneously the EuroToken owner
 *                                (the only minter), the platform admin (DEFAULT_ADMIN_ROLE in
 *                                Ecommerce) and the owner of the TechShop company. The signing key is
 *                                supplied on the CLI (--private-key / --account), never in the repo —
 *                                same pattern as DeployEcommerce.s.sol.
 *           DEMO_ACCOUNT         demo buyer that receives the minted EURT (separate from the admin).
 *
 *         Env vars (OPTIONAL):
 *           DEMO_MINT_EURT       whole EUR to mint to DEMO_ACCOUNT (default 1000). Multiplied by
 *                                10**decimals() read from the token, so it never assumes 6 decimals.
 *
 *         Run (example — fill the real addresses/key at execution time):
 *           ECOMMERCE_ADDRESS=0x.. EURO_TOKEN_ADDRESS=0x.. DEPLOYER=0x.. DEMO_ACCOUNT=0x.. \
 *             forge script script/SeedSepolia.s.sol \
 *             --rpc-url "$SEPOLIA_RPC_URL" --broadcast --private-key "$DEPLOYER_PRIVATE_KEY"
 *
 * 🇪🇸 NOTA: Lo que va dentro de startBroadcast/stopBroadcast se emite como transacciones firmadas
 * (reales con --broadcast, simuladas sin él). Todas las llamadas se emiten como `admin`, que debe
 * coincidir con la clave de firma de la CLI para que `mint`/`registerCompany`/`addProduct` (con
 * control de acceso) tengan permiso.
 */
contract SeedSepolia is Script {
    function run() external {
        // 🇪🇸 Direcciones y cuentas: requeridas (sin fallback hardcodeado).
        address ecommerceAddr = vm.envAddress("ECOMMERCE_ADDRESS");
        address euroTokenAddr = vm.envAddress("EURO_TOKEN_ADDRESS");
        address admin = vm.envAddress("DEPLOYER");
        address demo = vm.envAddress("DEMO_ACCOUNT");

        Ecommerce ecommerce = Ecommerce(ecommerceAddr);
        EuroToken token = EuroToken(euroTokenAddr);

        // 🇪🇸 Cantidad a mintear: leemos EUROS enteros de env (default 1000) y multiplicamos por
        // 10**decimals() leído del PROPIO contrato — así no asumimos 6 decimales hardcodeados.
        uint256 demoEur = vm.envOr("DEMO_MINT_EURT", uint256(1000));
        uint256 demoMint = demoEur * (uint256(10) ** token.decimals());

        vm.startBroadcast(admin);

        // 1) Empresa TechShop — owner = payoutWallet = admin.
        uint256 companyId = ecommerce.registerCompany(admin, "TechShop", admin);

        // 2) Productos (caller = admin = dueño de la empresa). CIDs reales de Pinata, idénticos a los
        //    que siembra restart-all.sh. Precios en unidades base (6 decimales) y stock.
        ecommerce.addProduct(
            companyId, "Smartphone", "bafkreib536nfcvmdjnaxmanfzrkkzpedsoxoypqyz7gppfehrfiyrf65hi", 278990000, 7
        );
        ecommerce.addProduct(
            companyId, "Laptop", "bafkreiguxp3on6ouekheftx32qpt3ckpzsgzdkjt6iy6msozyv7irqrnyi", 800990000, 4
        );
        ecommerce.addProduct(
            companyId, "Bicicleta", "bafkreiczboif47b47voibbru4ri4sfyk2ut3cdaiknj3asme3ueaiuzm4i", 445990000, 8
        );

        // 3) Mint de EURT de demo al comprador.
        token.mint(demo, demoMint);

        vm.stopBroadcast();

        // 🇪🇸 NOTA: Logs de auditoría del seed (visibles con -vvv).
        console2.log("=== Sepolia seed complete ===");
        console2.log("TechShop companyId  :", companyId);
        console2.log("Admin / owner       :", admin);
        console2.log("Demo buyer          :", demo);
        console2.log("Minted EURT (whole) :", demoEur);
        console2.log("Minted EURT (base)  :", demoMint);
    }
}
