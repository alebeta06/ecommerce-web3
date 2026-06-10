// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CustomerLib} from "../src/libraries/CustomerLib.sol";

/**
 * @title  CustomerLibHarness
 * @notice Test-only contract that OWNS the customer storage and exposes `external` wrappers so the
 *         library's `internal` functions can be exercised in isolation.
 *
 * 🇪🇸 NOTA: este harness replica el rol de Ecommerce como dueño del storage. Los wrappers
 * external permiten llamar register/get/updateName (internal) desde los tests.
 */
contract CustomerLibHarness {
    using CustomerLib for mapping(address => CustomerLib.Customer);

    mapping(address => CustomerLib.Customer) internal customers;

    function register(address wallet, string calldata name) external {
        customers.register(wallet, name);
    }

    function get(address wallet) external view returns (CustomerLib.Customer memory) {
        return customers.get(wallet);
    }

    function updateName(address wallet, string calldata newName) external {
        customers.updateName(wallet, newName);
    }
}

/**
 * @title  CustomerLib test suite
 * @notice Isolated unit tests for CustomerLib via a storage-owning harness: register state,
 *         event emission, input validation, existence checks and name updates.
 */
contract CustomerLibTest is Test {
    CustomerLibHarness internal harness;

    address internal wallet = makeAddr("wallet");

    // 🇪🇸 NOTA: redeclaramos los eventos para vm.expectEmit; deben coincidir EXACTAMENTE con los de la lib.
    event CustomerRegistered(address indexed wallet, string name, uint256 createdAt);
    event CustomerUpdated(address indexed wallet, string newName);

    function setUp() public {
        harness = new CustomerLibHarness();
    }

    /// @notice register writes all fields, sets the registered sentinel and stamps createdAt.
    function test_register_stores_customer() public {
        // 🇪🇸 NOTA: fijamos el timestamp para poder aseverar createdAt de forma determinista.
        vm.warp(1_700_000_000);
        harness.register(wallet, "Alice");

        CustomerLib.Customer memory c = harness.get(wallet);
        assertEq(c.wallet, wallet, "wallet should match");
        assertEq(c.name, "Alice", "name should match");
        assertTrue(c.registered, "registered should be true");
        assertEq(c.createdAt, 1_700_000_000, "createdAt should be the block timestamp");
    }

    /// @notice register emits CustomerRegistered(wallet, name, createdAt).
    function test_register_emits_event() public {
        vm.warp(1_700_000_000);
        vm.expectEmit(true, false, false, true, address(harness));
        emit CustomerRegistered(wallet, "Alice", 1_700_000_000);
        harness.register(wallet, "Alice");
    }

    /// @notice Empty name reverts EmptyName().
    function test_register_empty_name_reverts() public {
        vm.expectRevert(CustomerLib.EmptyName.selector);
        harness.register(wallet, "");
    }

    /// @notice Zero wallet reverts InvalidWallet().
    function test_register_zero_wallet_reverts() public {
        vm.expectRevert(CustomerLib.InvalidWallet.selector);
        harness.register(address(0), "Alice");
    }

    /// @notice Registering an already-registered wallet reverts CustomerAlreadyRegistered(wallet).
    function test_register_already_registered_reverts() public {
        harness.register(wallet, "Alice");
        vm.expectRevert(
            abi.encodeWithSelector(CustomerLib.CustomerAlreadyRegistered.selector, wallet)
        );
        harness.register(wallet, "Alice 2");
    }

    /// @notice get on an unknown wallet reverts CustomerNotFound(wallet) with the queried wallet.
    function test_get_unknown_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CustomerLib.CustomerNotFound.selector, wallet));
        harness.get(wallet);
    }

    /// @notice get returns the stored customer after registration.
    function test_get_returns_customer() public {
        harness.register(wallet, "Alice");
        CustomerLib.Customer memory c = harness.get(wallet);
        assertEq(c.wallet, wallet, "wallet should match");
        assertEq(c.name, "Alice", "name should match");
    }

    /// @notice updateName overwrites the name and emits CustomerUpdated.
    function test_updateName_updates_and_emits() public {
        vm.warp(1_700_000_000);
        harness.register(wallet, "Alice");

        vm.expectEmit(true, false, false, true, address(harness));
        emit CustomerUpdated(wallet, "Alicia");
        harness.updateName(wallet, "Alicia");

        CustomerLib.Customer memory c = harness.get(wallet);
        assertEq(c.name, "Alicia", "name should be updated");
        assertEq(c.createdAt, 1_700_000_000, "createdAt must be unchanged");
        assertTrue(c.registered, "registered must stay true");
    }

    /// @notice updateName on an unregistered wallet reverts CustomerNotFound(wallet).
    function test_updateName_unregistered_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CustomerLib.CustomerNotFound.selector, wallet));
        harness.updateName(wallet, "Alicia");
    }

    /// @notice updateName with an empty name reverts EmptyName().
    function test_updateName_empty_name_reverts() public {
        harness.register(wallet, "Alice");
        vm.expectRevert(CustomerLib.EmptyName.selector);
        harness.updateName(wallet, "");
    }
}
