// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CartLib} from "../src/libraries/CartLib.sol";

/**
 * @title  CartLibHarness
 * @notice Test-only contract that OWNS per-address cart storage and exposes `external` wrappers so
 *         the library's `internal` functions can be exercised in isolation.
 *
 * 🇪🇸 NOTA: el harness posee `mapping(address => Cart)` (replica cómo Ecommerce tendrá un carrito
 * por cliente). `indexPlusOneOf` RECOMPUTA la key de forma independiente a la lib: si la derivación
 * de key cambiara, los tests lo cazarían. (`_key` sigue siendo private en CartLib.)
 */
contract CartLibHarness {
    using CartLib for CartLib.Cart;

    mapping(address => CartLib.Cart) internal carts;

    function addItem(address who, uint256 companyId, uint256 productId, uint256 quantity) external {
        carts[who].addItem(companyId, productId, quantity);
    }

    function removeItem(address who, uint256 companyId, uint256 productId) external {
        carts[who].removeItem(companyId, productId);
    }

    function clear(address who) external {
        carts[who].clear();
    }

    function getItems(address who) external view returns (CartLib.CartItem[] memory) {
        return carts[who].getItems();
    }

    function itemsLength(address who) external view returns (uint256) {
        return carts[who].items.length;
    }

    function indexPlusOneOf(address who, uint256 companyId, uint256 productId)
        external
        view
        returns (uint256)
    {
        return carts[who].indexPlusOne[keccak256(abi.encode(companyId, productId))];
    }
}

/**
 * @title  CartLib test suite
 * @notice Isolated unit tests for CartLib via a storage-owning harness: add (new/duplicate),
 *         validation, removal with swap-and-pop, clear (with the stale-index regression), and
 *         multi-vendor coexistence.
 */
contract CartLibTest is Test {
    CartLibHarness internal harness;

    address internal user = makeAddr("user");

    // 🇪🇸 NOTA: ids opacos para los tests (CartLib no los interpreta).
    uint256 internal constant C1 = 1;
    uint256 internal constant C2 = 2;
    uint256 internal constant C3 = 3;
    uint256 internal constant P1 = 10;
    uint256 internal constant P2 = 20;
    uint256 internal constant P3 = 30;

    function setUp() public {
        harness = new CartLibHarness();
    }

    /// @notice addItem of a new pair appends one line and sets indexPlusOne to 1.
    function test_addItem_new() public {
        harness.addItem(user, C1, P1, 2);

        assertEq(harness.itemsLength(user), 1, "length should be 1");
        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "indexPlusOne should be 1");

        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items[0].companyId, C1, "companyId should match");
        assertEq(items[0].productId, P1, "productId should match");
        assertEq(items[0].quantity, 2, "quantity should match");
    }

    /// @notice addItem of an existing pair increments quantity without growing the array (D3).
    function test_addItem_duplicate_increments_quantity() public {
        harness.addItem(user, C1, P1, 2);
        harness.addItem(user, C1, P1, 3);

        assertEq(harness.itemsLength(user), 1, "length should stay 1");
        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "indexPlusOne should stay 1");

        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items[0].quantity, 5, "quantity should be accumulated to 5");
    }

    /// @notice addItem with quantity 0 reverts InvalidQuantity() before touching storage.
    function test_addItem_zero_quantity_reverts() public {
        vm.expectRevert(CartLib.InvalidQuantity.selector);
        harness.addItem(user, C1, P1, 0);

        assertEq(harness.itemsLength(user), 0, "nothing should be stored on revert");
    }

    /// @notice removeItem of a pair not in the cart reverts ItemNotInCart(companyId, productId).
    function test_removeItem_absent_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CartLib.ItemNotInCart.selector, C1, P1));
        harness.removeItem(user, C1, P1);
    }

    /// @notice Removing a MIDDLE item swaps the last one into the hole (swap-and-pop, index != last).
    function test_removeItem_middle_swap_and_pop() public {
        harness.addItem(user, C1, P1, 1); // index 0 (A)
        harness.addItem(user, C1, P2, 2); // index 1 (B) <- to remove
        harness.addItem(user, C2, P3, 3); // index 2 (C)

        harness.removeItem(user, C1, P2);

        assertEq(harness.itemsLength(user), 2, "length should be 2");

        // C (the former last) must now occupy the hole at index 1.
        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items[1].companyId, C2, "moved item companyId should be C2");
        assertEq(items[1].productId, P3, "moved item productId should be P3");
        assertEq(items[1].quantity, 3, "moved item quantity should be 3");

        // Indices: A stays 1, C moved to 2, removed B is 0.
        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "A indexPlusOne should stay 1");
        assertEq(harness.indexPlusOneOf(user, C2, P3), 2, "C indexPlusOne should be 2");
        assertEq(harness.indexPlusOneOf(user, C1, P2), 0, "removed B indexPlusOne should be 0");
    }

    /// @notice Removing the LAST item needs no swap (index == lastIndex branch).
    function test_removeItem_last_no_swap() public {
        harness.addItem(user, C1, P1, 1); // index 0 (A)
        harness.addItem(user, C1, P2, 2); // index 1 (B) <- last, to remove

        harness.removeItem(user, C1, P2);

        assertEq(harness.itemsLength(user), 1, "length should be 1");

        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items[0].companyId, C1, "remaining item should be A (companyId)");
        assertEq(items[0].productId, P1, "remaining item should be A (productId)");

        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "A indexPlusOne should stay 1");
        assertEq(harness.indexPlusOneOf(user, C1, P2), 0, "removed B indexPlusOne should be 0");
    }

    /// @notice clear empties the items array and zeroes every key's indexPlusOne.
    function test_clear_empties_items_and_index() public {
        harness.addItem(user, C1, P1, 1);
        harness.addItem(user, C2, P2, 2);

        harness.clear(user);

        assertEq(harness.itemsLength(user), 0, "items should be empty");
        assertEq(harness.indexPlusOneOf(user, C1, P1), 0, "C1/P1 index should be cleared");
        assertEq(harness.indexPlusOneOf(user, C2, P2), 0, "C2/P2 index should be cleared");
    }

    /// @notice clear on an EMPTY cart is a no-op (n == 0, loop body not entered).
    function test_clear_empty_cart_noop() public {
        harness.clear(user);
        assertEq(harness.itemsLength(user), 0, "still empty");
    }

    /// @notice KEY regression: add -> clear -> re-add of the SAME pair works clean (no stale index).
    function test_clear_then_readd_same_pair() public {
        harness.addItem(user, C1, P1, 5);
        harness.clear(user);
        harness.addItem(user, C1, P1, 3);

        assertEq(harness.itemsLength(user), 1, "length should be 1 after re-add");
        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "indexPlusOne should be 1");

        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items[0].quantity, 3, "quantity should reset to 3, not accumulate to 8");
    }

    /// @notice Multi-vendor: items from several companies coexist in the same cart.
    function test_multi_vendor_coexist() public {
        harness.addItem(user, C1, P1, 1);
        harness.addItem(user, C2, P2, 2);
        harness.addItem(user, C3, P3, 3);

        assertEq(harness.itemsLength(user), 3, "length should be 3");
        assertEq(harness.indexPlusOneOf(user, C1, P1), 1, "C1/P1 index should be 1");
        assertEq(harness.indexPlusOneOf(user, C2, P2), 2, "C2/P2 index should be 2");
        assertEq(harness.indexPlusOneOf(user, C3, P3), 3, "C3/P3 index should be 3");

        CartLib.CartItem[] memory items = harness.getItems(user);
        assertEq(items.length, 3, "getItems should return 3 lines");
    }
}
