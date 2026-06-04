// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CompanyLib} from "../src/libraries/CompanyLib.sol";

/**
 * @title  CompanyLibHarness
 * @notice Test-only contract that OWNS the company storage and exposes `external` wrappers so the
 *         library's `internal` functions can be exercised in isolation.
 *
 * 🇪🇸 NOTA: este harness replica el rol de Ecommerce como dueño del storage. Los wrappers
 * external permiten llamar register/get/requireExists (internal) desde los tests.
 */
contract CompanyLibHarness {
    using CompanyLib for mapping(uint256 => CompanyLib.Company);
    using CompanyLib for CompanyLib.Company;

    mapping(uint256 => CompanyLib.Company) internal companies;

    function register(uint256 id, address owner, string calldata name, address payoutWallet)
        external
    {
        companies.register(id, owner, name, payoutWallet);
    }

    function get(uint256 id) external view returns (CompanyLib.Company memory) {
        return companies.get(id);
    }

    function requireExists(uint256 id) external view {
        companies[id].requireExists();
    }
}

/**
 * @title  CompanyLib test suite
 * @notice Isolated unit tests for CompanyLib via a storage-owning harness: register state,
 *         event emission, input validation and existence checks.
 */
contract CompanyLibTest is Test {
    CompanyLibHarness internal harness;

    address internal owner = makeAddr("owner");
    address internal payout = makeAddr("payout");

    // 🇪🇸 NOTA: redeclaramos el evento para vm.expectEmit; debe coincidir EXACTAMENTE con el de la lib.
    event CompanyRegistered(
        uint256 indexed id, address indexed owner, string name, address payoutWallet
    );

    function setUp() public {
        harness = new CompanyLibHarness();
    }

    /// @notice register writes all fields and sets the exists sentinel.
    function test_register_stores_company() public {
        harness.register(1, owner, "Acme", payout);

        CompanyLib.Company memory c = harness.get(1);
        assertEq(c.id, 1, "id should be 1");
        assertEq(c.owner, owner, "owner should match");
        assertEq(c.name, "Acme", "name should match");
        assertEq(c.payoutWallet, payout, "payoutWallet should match");
        assertTrue(c.exists, "exists should be true");
    }

    /// @notice register emits CompanyRegistered(id, owner, name, payoutWallet).
    function test_register_emits_event() public {
        vm.expectEmit(true, true, false, true, address(harness));
        emit CompanyRegistered(1, owner, "Acme", payout);
        harness.register(1, owner, "Acme", payout);
    }

    /// @notice owner and payoutWallet are allowed to be the same address.
    function test_register_owner_equals_payout_allowed() public {
        harness.register(1, owner, "Acme", owner);
        CompanyLib.Company memory c = harness.get(1);
        assertEq(c.owner, c.payoutWallet, "owner may equal payoutWallet");
    }

    /// @notice Empty name reverts EmptyName().
    function test_register_empty_name_reverts() public {
        vm.expectRevert(CompanyLib.EmptyName.selector);
        harness.register(1, owner, "", payout);
    }

    /// @notice Zero owner reverts InvalidOwner().
    function test_register_zero_owner_reverts() public {
        vm.expectRevert(CompanyLib.InvalidOwner.selector);
        harness.register(1, address(0), "Acme", payout);
    }

    /// @notice Zero payoutWallet reverts InvalidPayoutWallet().
    function test_register_zero_payout_reverts() public {
        vm.expectRevert(CompanyLib.InvalidPayoutWallet.selector);
        harness.register(1, owner, "Acme", address(0));
    }

    /// @notice get on an unknown id reverts CompanyNotFound(id) with the queried id.
    function test_get_unknown_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CompanyLib.CompanyNotFound.selector, uint256(99)));
        harness.get(99);
    }

    /// @notice requireExists reverts CompanyNotFound for a missing company (reports stored id 0).
    function test_requireExists_missing_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CompanyLib.CompanyNotFound.selector, uint256(0)));
        harness.requireExists(42);
    }
}
