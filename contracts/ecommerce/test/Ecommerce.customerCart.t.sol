// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {CustomerLib} from "../src/libraries/CustomerLib.sol";
import {CartLib} from "../src/libraries/CartLib.sol";
import {ProductLib} from "../src/libraries/ProductLib.sol";

/**
 * @title  Ecommerce customer+cart integration tests
 * @notice Verifies the orchestrator wires CustomerLib/CartLib correctly: self-service customer
 *         registration, cart cross-validation (product exists + company matches), D5 (stock not
 *         checked on add) and D6 (registration required), plus swap-and-pop sequences end-to-end.
 *
 * 🇪🇸 NOTA: el constructor solo GUARDA la dirección de EURT (no la llama esta sesión); pasamos una
 * dirección no-cero cualquiera. Usamos vm.startPrank/stopPrank (regla del proyecto).
 */
contract EcommerceCustomerCartTest is Test {
    Ecommerce internal ecommerce;

    address internal admin = makeAddr("admin");
    address internal seller = makeAddr("seller");
    address internal seller2 = makeAddr("seller2");
    address internal payout = makeAddr("payout");
    address internal customer = makeAddr("customer");

    string internal constant CID = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    uint256 internal constant PRICE = 10e6;

    function setUp() public {
        ecommerce = new Ecommerce(makeAddr("eurt"), admin);
    }

    // ── helpers ────────────────────────────────────────────────────────────────────────────────

    /// @dev Register one company owned by `owner` and return its id.
    function _registerCompany(address owner, string memory name) internal returns (uint256 id) {
        vm.startPrank(admin);
        id = ecommerce.registerCompany(owner, name, payout);
        vm.stopPrank();
    }

    /// @dev Add one product to `companyId` as `owner` and return its id.
    function _addProduct(address owner, uint256 companyId, uint256 stock)
        internal
        returns (uint256 pid)
    {
        vm.startPrank(owner);
        pid = ecommerce.addProduct(companyId, "Widget", CID, PRICE, stock);
        vm.stopPrank();
    }

    // ── customers ────────────────────────────────────────────────────────────────────────────

    /// @notice registerCustomer stores the caller and getCustomer reads it back.
    function test_registerCustomer_and_get() public {
        vm.warp(1_700_000_000);
        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        vm.stopPrank();

        CustomerLib.Customer memory c = ecommerce.getCustomer(customer);
        assertEq(c.wallet, customer, "wallet");
        assertEq(c.name, "Alice", "name");
        assertTrue(c.registered, "registered");
        assertEq(c.createdAt, 1_700_000_000, "createdAt");
    }

    /// @notice Registering twice reverts CustomerAlreadyRegistered(caller).
    function test_registerCustomer_twice_reverts() public {
        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        vm.expectRevert(
            abi.encodeWithSelector(CustomerLib.CustomerAlreadyRegistered.selector, customer)
        );
        ecommerce.registerCustomer("Alice 2");
        vm.stopPrank();
    }

    /// @notice getCustomer on an unregistered wallet reverts CustomerNotFound(wallet).
    function test_getCustomer_unregistered_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(CustomerLib.CustomerNotFound.selector, customer));
        ecommerce.getCustomer(customer);
    }

    /// @notice updateCustomerName updates the stored name for a registered caller.
    function test_updateCustomerName_ok() public {
        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.updateCustomerName("Alicia");
        vm.stopPrank();

        CustomerLib.Customer memory c = ecommerce.getCustomer(customer);
        assertEq(c.name, "Alicia", "name should be updated");
    }

    /// @notice updateCustomerName by an unregistered caller reverts CustomerNotFound(caller).
    function test_updateCustomerName_unregistered_reverts() public {
        vm.startPrank(customer);
        vm.expectRevert(abi.encodeWithSelector(CustomerLib.CustomerNotFound.selector, customer));
        ecommerce.updateCustomerName("Alicia");
        vm.stopPrank();
    }

    // ── cart: happy path & cross-validation ──────────────────────────────────────────────────

    /// @notice Full happy path: company -> product -> customer -> addToCart -> getCart line.
    function test_addToCart_happy_path() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pid, 2);
        vm.stopPrank();

        CartLib.CartItem[] memory items = ecommerce.getCart(customer);
        assertEq(items.length, 1, "one line");
        assertEq(items[0].companyId, companyId, "companyId");
        assertEq(items[0].productId, pid, "productId");
        assertEq(items[0].quantity, 2, "quantity");
    }

    /// @notice addToCart of a non-existent product reverts ProductNotFound(productId).
    function test_addToCart_unknown_product_reverts() public {
        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        vm.expectRevert(abi.encodeWithSelector(ProductLib.ProductNotFound.selector, uint256(99)));
        ecommerce.addToCart(1, 99, 1);
        vm.stopPrank();
    }

    /// @notice addToCart by an unregistered customer reverts CustomerNotFound (D6).
    function test_addToCart_unregistered_customer_reverts() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        vm.expectRevert(abi.encodeWithSelector(CustomerLib.CustomerNotFound.selector, customer));
        ecommerce.addToCart(companyId, pid, 1);
        vm.stopPrank();
    }

    /// @notice addToCart with a companyId that does not own the product reverts ProductCompanyMismatch.
    function test_addToCart_company_mismatch_reverts() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 otherCompany = _registerCompany(seller2, "Globex");
        uint256 pid = _addProduct(seller, companyId, 5); // product belongs to companyId

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        vm.expectRevert(
            abi.encodeWithSelector(Ecommerce.ProductCompanyMismatch.selector, otherCompany, pid)
        );
        ecommerce.addToCart(otherCompany, pid, 1);
        vm.stopPrank();
    }

    /// @notice D5: a product with stock 0 (but active) CAN be added to the cart.
    function test_addToCart_zero_stock_allowed() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 0); // stock 0

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pid, 3);
        vm.stopPrank();

        CartLib.CartItem[] memory items = ecommerce.getCart(customer);
        assertEq(items.length, 1, "zero-stock product must be addable");
        assertEq(items[0].quantity, 3, "quantity");
    }

    /// @notice addToCart with quantity 0 surfaces CartLib.InvalidQuantity through the orchestrator.
    function test_addToCart_zero_quantity_reverts() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        vm.expectRevert(CartLib.InvalidQuantity.selector);
        ecommerce.addToCart(companyId, pid, 0);
        vm.stopPrank();
    }

    // ── cart: remove / clear / sequences ─────────────────────────────────────────────────────

    /// @notice removeFromCart deletes a line; removing an absent line reverts ItemNotInCart.
    function test_removeFromCart_and_absent_reverts() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pid, 2);
        ecommerce.removeFromCart(companyId, pid);
        vm.stopPrank();

        assertEq(ecommerce.getCart(customer).length, 0, "cart should be empty after remove");

        vm.startPrank(customer);
        vm.expectRevert(abi.encodeWithSelector(CartLib.ItemNotInCart.selector, companyId, pid));
        ecommerce.removeFromCart(companyId, pid);
        vm.stopPrank();
    }

    /// @notice clearCart empties a multi-line cart in one call.
    function test_clearCart() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pidA = _addProduct(seller, companyId, 5);
        uint256 pidB = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pidA, 1);
        ecommerce.addToCart(companyId, pidB, 1);
        ecommerce.clearCart();
        vm.stopPrank();

        assertEq(ecommerce.getCart(customer).length, 0, "cart should be empty after clear");
    }

    /// @notice Sequence: remove then re-add the same pair works clean (no stale index).
    function test_remove_then_readd_same_pair() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pid = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pid, 5);
        ecommerce.removeFromCart(companyId, pid);
        ecommerce.addToCart(companyId, pid, 2);
        vm.stopPrank();

        CartLib.CartItem[] memory items = ecommerce.getCart(customer);
        assertEq(items.length, 1, "one line");
        assertEq(items[0].quantity, 2, "quantity should be 2 (fresh), not accumulated");
    }

    /// @notice Sequence: remove a MIDDLE item; the last one fills the hole (swap-and-pop), via getCart.
    function test_remove_middle_swap_and_pop_e2e() public {
        uint256 companyId = _registerCompany(seller, "Acme");
        uint256 pidA = _addProduct(seller, companyId, 5);
        uint256 pidB = _addProduct(seller, companyId, 5);
        uint256 pidC = _addProduct(seller, companyId, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(companyId, pidA, 1); // index 0
        ecommerce.addToCart(companyId, pidB, 2); // index 1 <- remove
        ecommerce.addToCart(companyId, pidC, 3); // index 2
        ecommerce.removeFromCart(companyId, pidB);
        vm.stopPrank();

        CartLib.CartItem[] memory items = ecommerce.getCart(customer);
        assertEq(items.length, 2, "two lines remain");
        assertEq(items[1].productId, pidC, "C moved into the hole at index 1");
        assertEq(items[1].quantity, 3, "C quantity preserved");
        assertEq(items[0].productId, pidA, "A stays at index 0");
    }

    /// @notice Multi-vendor: one customer holds lines from two different companies.
    function test_multi_vendor_cart() public {
        uint256 c1 = _registerCompany(seller, "Acme");
        uint256 c2 = _registerCompany(seller2, "Globex");
        uint256 p1 = _addProduct(seller, c1, 5);
        uint256 p2 = _addProduct(seller2, c2, 5);

        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        ecommerce.addToCart(c1, p1, 1);
        ecommerce.addToCart(c2, p2, 4);
        vm.stopPrank();

        CartLib.CartItem[] memory items = ecommerce.getCart(customer);
        assertEq(items.length, 2, "two lines from two companies");
        assertEq(items[0].companyId, c1, "first line company");
        assertEq(items[1].companyId, c2, "second line company");
        assertEq(items[1].quantity, 4, "second line quantity");
    }
}
