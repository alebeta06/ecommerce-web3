// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {ProductLib} from "../src/libraries/ProductLib.sol";
import {InvoiceLib} from "../src/libraries/InvoiceLib.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title  MockEURT
 * @notice Minimal standard ERC20 with an open `mint`, used as EURT in checkout integration tests.
 * @dev    Self-contained: avoids coupling these tests to the separate euro-token Foundry project.
 */
contract MockEURT is ERC20 {
    constructor() ERC20("Mock EURT", "mEURT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title  Ecommerce checkout integration tests
 * @notice End-to-end checkout: per-company invoicing, stock decrement, cart clearing, EURT pulls to
 *         each payoutWallet, the price snapshot taken at checkout, and the all-or-nothing atomicity
 *         of both stock and payments across multiple companies.
 *
 * 🇪🇸 NOTA: ahora el constructor SÍ usa EURT (checkout llama transferFrom), así que desplegamos un
 * MockEURT real, acuñamos saldo al cliente y aprobamos a Ecommerce. Usamos startPrank/stopPrank.
 */
contract EcommerceCheckoutTest is Test {
    Ecommerce internal ecommerce;
    MockEURT internal token;

    address internal admin = makeAddr("admin");
    address internal sellerA = makeAddr("sellerA");
    address internal sellerB = makeAddr("sellerB");
    address internal payoutA = makeAddr("payoutA");
    address internal payoutB = makeAddr("payoutB");
    address internal customer = makeAddr("customer");

    string internal constant CID = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";

    // Company A (id 1): products 1 (10 EURT) and 2 (25 EURT). Company B (id 2): product 3 (50 EURT).
    uint256 internal constant PRICE1 = 10e6;
    uint256 internal constant PRICE2 = 25e6;
    uint256 internal constant PRICE3 = 50e6;
    uint256 internal constant MINT = 1000e6;

    event InvoiceCreated(
        uint256 indexed id, address indexed customer, uint256 indexed companyId, uint256 total
    );

    function setUp() public {
        token = new MockEURT();
        ecommerce = new Ecommerce(address(token), admin);

        vm.startPrank(admin);
        ecommerce.registerCompany(sellerA, "Acme", payoutA); // company id 1
        ecommerce.registerCompany(sellerB, "Globex", payoutB); // company id 2
        vm.stopPrank();

        vm.startPrank(sellerA);
        ecommerce.addProduct(1, "A1", CID, PRICE1, 10); // product id 1
        ecommerce.addProduct(1, "A2", CID, PRICE2, 10); // product id 2
        vm.stopPrank();

        vm.startPrank(sellerB);
        ecommerce.addProduct(2, "B1", CID, PRICE3, 10); // product id 3
        vm.stopPrank();

        token.mint(customer, MINT);
        vm.startPrank(customer);
        ecommerce.registerCustomer("Alice");
        token.approve(address(ecommerce), MINT);
        vm.stopPrank();
    }

    // ── happy paths ──────────────────────────────────────────────────────────────────────────

    /// @notice Single company, two lines: one invoice, stock decremented, cart cleared, seller paid.
    function test_checkout_single_company() public {
        uint256 total = 2 * PRICE1 + 1 * PRICE2; // 45 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.addToCart(1, 2, 1);
        vm.expectEmit(true, true, true, true, address(ecommerce));
        emit InvoiceCreated(1, customer, 1, total);
        ecommerce.checkout();
        vm.stopPrank();

        assertEq(token.balanceOf(payoutA), total, "payoutA received total");
        assertEq(token.balanceOf(customer), MINT - total, "customer debited total");

        assertEq(ecommerce.getCustomerInvoices(customer).length, 1, "one invoice for customer");
        assertEq(ecommerce.getCompanyInvoices(1).length, 1, "one invoice for company A");
        assertEq(ecommerce.getCompanyInvoices(2).length, 0, "no invoice for company B");

        InvoiceLib.Invoice memory inv = ecommerce.getInvoice(1);
        assertEq(inv.companyId, 1, "invoice company");
        assertEq(inv.total, total, "invoice total");
        assertEq(inv.lines.length, 2, "two lines");

        assertEq(ecommerce.getProduct(1).stock, 8, "pid1 stock 10-2");
        assertEq(ecommerce.getProduct(2).stock, 9, "pid2 stock 10-1");
        assertEq(ecommerce.getCart(customer).length, 0, "cart cleared");
    }

    /// @notice Multi-company (company A with 2 lines): two invoices, each seller paid its own total.
    /// @dev Covers _distinctCompanies' "already seen" branch (A appears twice) and _issueInvoice's
    ///      multi-line + "skip other company" (continue) branch.
    function test_checkout_multi_company_groups_per_company() public {
        uint256 totalA = 2 * PRICE1 + 1 * PRICE2; // 45 EURT
        uint256 totalB = 3 * PRICE3; // 150 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // A
        ecommerce.addToCart(1, 2, 1); // A (second line of company A)
        ecommerce.addToCart(2, 3, 3); // B
        ecommerce.checkout();
        vm.stopPrank();

        assertEq(token.balanceOf(payoutA), totalA, "payoutA total");
        assertEq(token.balanceOf(payoutB), totalB, "payoutB total");
        assertEq(token.balanceOf(customer), MINT - totalA - totalB, "customer debited both");

        assertEq(ecommerce.getCustomerInvoices(customer).length, 2, "two invoices for customer");
        assertEq(ecommerce.getCompanyInvoices(1).length, 1, "company A one invoice");
        assertEq(ecommerce.getCompanyInvoices(2).length, 1, "company B one invoice");

        InvoiceLib.Invoice memory invA = ecommerce.getInvoice(1); // first-seen company A
        assertEq(invA.companyId, 1, "inv1 company A");
        assertEq(invA.lines.length, 2, "inv1 two lines");
        assertEq(invA.total, totalA, "inv1 total");

        InvoiceLib.Invoice memory invB = ecommerce.getInvoice(2);
        assertEq(invB.companyId, 2, "inv2 company B");
        assertEq(invB.lines.length, 1, "inv2 one line");
        assertEq(invB.total, totalB, "inv2 total");

        assertEq(ecommerce.getProduct(1).stock, 8, "pid1");
        assertEq(ecommerce.getProduct(2).stock, 9, "pid2");
        assertEq(ecommerce.getProduct(3).stock, 7, "pid3 10-3");
        assertEq(ecommerce.getCart(customer).length, 0, "cart cleared");
    }

    /// @notice The unit price is a snapshot taken AT CHECKOUT, not when the item entered the cart.
    function test_checkout_price_snapshot_at_checkout() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // current price 10 EURT
        vm.stopPrank();

        vm.startPrank(sellerA);
        ecommerce.updateProduct(1, 1, 30e6, 10, true); // raise price to 30 EURT before checkout
        vm.stopPrank();

        vm.startPrank(customer);
        ecommerce.checkout();
        vm.stopPrank();

        uint256 expected = 2 * 30e6; // checkout-time price wins
        InvoiceLib.Invoice memory inv = ecommerce.getInvoice(1);
        assertEq(inv.lines[0].unitPrice, 30e6, "unitPrice = checkout-time price");
        assertEq(inv.total, expected, "total uses checkout-time price");
        assertEq(token.balanceOf(payoutA), expected, "payout uses checkout-time price");
    }

    // ── reverts & atomicity ──────────────────────────────────────────────────────────────────

    /// @notice checkout on an empty cart reverts EmptyCart.
    function test_checkout_empty_cart_reverts() public {
        vm.startPrank(customer);
        vm.expectRevert(Ecommerce.EmptyCart.selector);
        ecommerce.checkout();
        vm.stopPrank();
    }

    /// @notice Insufficient stock reverts ProductLib.InsufficientStock and rolls everything back.
    function test_checkout_insufficient_stock_reverts() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 100); // qty 100 > stock 10 (addToCart does not check stock, D5)
        vm.expectRevert(
            abi.encodeWithSelector(
                ProductLib.InsufficientStock.selector, uint256(1), uint256(100), uint256(10)
            )
        );
        ecommerce.checkout();
        vm.stopPrank();

        assertEq(ecommerce.getProduct(1).stock, 10, "stock unchanged after revert");
        assertEq(token.balanceOf(payoutA), 0, "no payment");
        assertEq(ecommerce.getCart(customer).length, 1, "cart intact");
    }

    /// @notice Payment atomicity ACROSS companies: if company B's collect fails for lack of
    ///         allowance, company A's already-executed transfer is rolled back too.
    function test_checkout_payment_atomic_on_insufficient_allowance() public {
        uint256 totalA = 2 * PRICE1 + 1 * PRICE2; // 45 EURT

        vm.startPrank(customer);
        token.approve(address(ecommerce), totalA); // enough for A only; B (50 EURT) will fail
        ecommerce.addToCart(1, 1, 2); // A (paid first)
        ecommerce.addToCart(1, 2, 1); // A
        ecommerce.addToCart(2, 3, 1); // B
        vm.expectRevert(); // SafeERC20 reverts on B's transferFrom (allowance exhausted)
        ecommerce.checkout();
        vm.stopPrank();

        // company A was paid FIRST inside checkout, but the whole tx reverts -> its transfer undone
        assertEq(token.balanceOf(payoutA), 0, "company A transfer rolled back");
        assertEq(token.balanceOf(payoutB), 0, "company B never paid");
        assertEq(token.balanceOf(customer), MINT, "customer not debited at all");

        assertEq(ecommerce.getCustomerInvoices(customer).length, 0, "no invoices created");
        assertEq(ecommerce.getProduct(1).stock, 10, "pid1 stock intact");
        assertEq(ecommerce.getProduct(3).stock, 10, "pid3 stock intact");
        assertEq(ecommerce.getCart(customer).length, 3, "cart intact");
    }
}
