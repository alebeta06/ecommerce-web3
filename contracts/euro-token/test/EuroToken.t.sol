// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// 🇪🇸 NOTA: forge-std/Test.sol nos da:
//  - Test: contrato base con assertions (assertEq, assertTrue…) y el objeto `vm`.
//  - vm:   el "cheatcode engine" de Foundry para manipular la EVM en tests
//          (vm.prank = suplantar msg.sender, vm.expectRevert, vm.expectEmit…).
import {Test} from "forge-std/Test.sol";
import {EuroToken} from "../src/EuroToken.sol";

// 🇪🇸 NOTA: Importamos Ownable SOLO para referenciar su error custom de v5
// (OwnableUnauthorizedAccount) al construir el revert esperado en el test negativo.
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  EuroToken test suite
 * @notice Unit tests for the EURT stablecoin: deploy state, 6 decimals, owner-only
 *         minting, event emission, transfers and supply accounting.
 * @dev    Foundry test contract. Each `test_*` function is an isolated test: the EVM
 *         state from setUp() is re-applied fresh before every one of them.
 */
contract EuroTokenTest is Test {
    EuroToken internal token;

    // 🇪🇸 NOTA: makeAddr("label") deriva una dirección determinista a partir de un
    // string y además la etiqueta en los traces (-vvv) para legibilidad.
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    // 🇪🇸 NOTA: 1_000 EURT expresados en unidades base (6 decimales). El sufijo `e6`
    // = multiplicar por 10**6. Recordatorio: on-chain NO hay decimales, todo es entero.
    uint256 internal constant ONE_THOUSAND = 1_000e6;

    // 🇪🇸 NOTA: Redeclaramos el evento Mint aquí porque vm.expectEmit compara contra
    // un evento que debe ser visible en este archivo. Debe coincidir EXACTAMENTE con
    // el del contrato (misma firma, mismo `indexed`).
    event Mint(address indexed to, uint256 amount);

    /**
     * @dev Runs before EACH test. Deploys a fresh EuroToken owned by `owner`.
     * 🇪🇸 NOTA: setUp() se ejecuta antes de cada test con un estado limpio, así los
     * tests no se contaminan entre sí (aislamiento).
     */
    function setUp() public {
        token = new EuroToken(owner);
    }

    /// @notice Initial metadata and zero supply right after deployment.
    function test_deploy_initial_state() public view {
        assertEq(token.name(), "EuroToken", "name should be EuroToken");
        assertEq(token.symbol(), "EURT", "symbol should be EURT");
        assertEq(token.totalSupply(), 0, "initial supply should be 0");
        assertEq(token.owner(), owner, "owner should be the deployer-set owner");
    }

    /// @notice EURT uses 6 decimals (not the ERC20 default of 18).
    function test_decimals_is_6() public view {
        assertEq(token.decimals(), 6, "decimals should be 6");
    }

    /// @notice The owner can mint; balance and totalSupply increase accordingly.
    function test_mint_by_owner() public {
        // 🇪🇸 NOTA: vm.prank hace que la SIGUIENTE llamada tenga msg.sender = owner.
        vm.prank(owner);
        token.mint(alice, ONE_THOUSAND);

        assertEq(token.balanceOf(alice), ONE_THOUSAND, "alice balance after mint");
        assertEq(token.totalSupply(), ONE_THOUSAND, "totalSupply after mint");
    }

    /// @notice A non-owner cannot mint: reverts with OwnableUnauthorizedAccount(caller).
    function test_mint_by_non_owner_reverts() public {
        // 🇪🇸 NOTA: En OZ v5 los reverts usan ERRORES CUSTOM (más baratos en gas que
        // strings). Construimos el revert esperado con su selector + el argumento
        // (la dirección no autorizada). El orden importa: expectRevert ANTES de la
        // llamada que debe revertir.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, ONE_THOUSAND);
    }

    /// @notice mint() emits the Mint(to, amount) audit event.
    function test_mint_emits_event() public {
        // 🇪🇸 NOTA: vm.expectEmit(checkTopic1, checkTopic2, checkTopic3, checkData).
        // Mint tiene 1 parámetro indexed (`to` -> topic1) y 1 no indexado (`amount` ->
        // data). Así: topic1=true, topic2/3=false, data=true. Tras expectEmit, emitimos
        // el evento ESPERADO y luego ejecutamos la acción real; Foundry compara ambos.
        vm.expectEmit(true, false, false, true, address(token));
        emit Mint(alice, ONE_THOUSAND);

        vm.prank(owner);
        token.mint(alice, ONE_THOUSAND);
    }

    /// @notice Standard ERC20 transfer between two accounts moves balances correctly.
    function test_transfer_between_accounts() public {
        vm.prank(owner);
        token.mint(alice, ONE_THOUSAND);

        // 🇪🇸 NOTA: alice transfiere a bob. transfer() usa msg.sender como origen,
        // por eso prankeamos a alice. Comprobamos el bool de retorno (buena práctica:
        // un ERC20 conforme devuelve true; nunca se debe ignorar ese valor).
        vm.prank(alice);
        assertTrue(token.transfer(bob, 400e6), "transfer should return true");

        assertEq(token.balanceOf(alice), 600e6, "alice balance after transfer");
        assertEq(token.balanceOf(bob), 400e6, "bob balance after transfer");
        assertEq(token.totalSupply(), ONE_THOUSAND, "transfer must not change supply");
    }

    /// @notice Two mints accumulate: totalSupply equals the sum of minted amounts.
    function test_total_supply_increases_on_mint() public {
        vm.startPrank(owner);
        token.mint(alice, ONE_THOUSAND);
        token.mint(bob, 500e6);
        vm.stopPrank();

        // 🇪🇸 NOTA: vm.startPrank/stopPrank mantiene el suplantador para VARIAS
        // llamadas seguidas (a diferencia de vm.prank, que solo afecta a la siguiente).
        assertEq(token.totalSupply(), ONE_THOUSAND + 500e6, "supply = sum of mints");
    }

    /**
     * @notice Fuzz: minting any amount to any non-zero address keeps balance/supply
     *         consistent. Empuja la cobertura de mint() con cientos de entradas.
     * @dev    Foundry ejecuta este test muchas veces con `to`/`amount` aleatorios.
     * 🇪🇸 NOTA: vm.assume descarta entradas inválidas (address(0) revertiría en _mint).
     */
    function testFuzz_mint(address to, uint256 amount) public {
        vm.assume(to != address(0));

        vm.prank(owner);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount, "fuzz: balance equals minted amount");
        assertEq(token.totalSupply(), amount, "fuzz: supply equals minted amount");
    }
}
