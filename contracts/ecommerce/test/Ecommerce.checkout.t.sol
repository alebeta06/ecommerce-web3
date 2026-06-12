// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {InvoiceLib} from "../src/libraries/InvoiceLib.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title  MockEURT
 * @notice Minimal standard ERC20 with an open `mint`, used as EURT in these integration tests.
 * @dev    Self-contained: avoids coupling these tests to the separate euro-token Foundry project.
 */
contract MockEURT is ERC20 {
    constructor() ERC20("Mock EURT", "mEURT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title  Ecommerce checkout (phase 1) tests
 * @notice Phase 1 of the two-phase flow: `checkout` groups the cart by company, creates one UNPAID
 *         invoice per company freezing `unitPrice` at the current price, clears the cart and returns
 *         the new invoice ids. It moves NO EURT and touches NO stock — settlement happens in phase 2
 *         (`processPayment`, tested in Ecommerce.payment.t.sol).
 *
 * 🇪🇸 NOTA: checkout ya NO cobra ni decrementa stock, así que aquí NO aprobamos allowance: solo
 * verificamos la CREACIÓN de facturas impagas. El MockEURT se despliega igual (el constructor lo pide)
 * y se acuña saldo al cliente para comprobar que en fase 1 NO se debita.
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
        vm.stopPrank();
    }

    // ── happy paths ──────────────────────────────────────────────────────────────────────────

    /// @notice Single company, two lines: one UNPAID invoice returned, cart cleared, stock & money
    ///         untouched (settlement deferred to phase 2).
    function test_checkout_single_company_creates_unpaid_invoice() public {
        uint256 total = 2 * PRICE1 + 1 * PRICE2; // 45 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.addToCart(1, 2, 1);
        vm.expectEmit(true, true, true, true, address(ecommerce));
        emit InvoiceCreated(1, customer, 1, total);
        uint256[] memory ids = ecommerce.checkout();
        vm.stopPrank();

        assertEq(ids.length, 1, "one invoice id returned");
        assertEq(ids[0], 1, "invoice id is 1");

        InvoiceLib.Invoice memory inv = ecommerce.getInvoice(1);
        assertEq(inv.companyId, 1, "invoice company");
        assertEq(inv.total, total, "invoice total");
        assertEq(inv.lines.length, 2, "two lines");
        assertFalse(inv.isPaid, "invoice UNPAID after checkout");

        assertEq(ecommerce.getCustomerInvoices(customer).length, 1, "one invoice for customer");
        assertEq(ecommerce.getCompanyInvoices(1).length, 1, "one invoice for company A");
        assertEq(ecommerce.getCompanyInvoices(2).length, 0, "no invoice for company B");

        // phase 1 settles nothing
        assertEq(token.balanceOf(payoutA), 0, "no payment in phase 1");
        assertEq(token.balanceOf(customer), MINT, "customer not debited in phase 1");
        assertEq(ecommerce.getProduct(1).stock, 10, "pid1 stock untouched");
        assertEq(ecommerce.getProduct(2).stock, 10, "pid2 stock untouched");
        assertEq(ecommerce.getCart(customer).length, 0, "cart cleared");
    }

    /// @notice Multi-company (company A with 2 lines): two UNPAID invoices, both ids returned.
    /// @dev Covers _distinctCompanies' "already seen" branch (A appears twice) and _issueInvoice's
    ///      multi-line + "skip other company" (continue) branch.
    function test_checkout_multi_company_returns_two_ids() public {
        uint256 totalA = 2 * PRICE1 + 1 * PRICE2; // 45 EURT
        uint256 totalB = 3 * PRICE3; // 150 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // A
        ecommerce.addToCart(1, 2, 1); // A (second line of company A)
        ecommerce.addToCart(2, 3, 3); // B
        uint256[] memory ids = ecommerce.checkout();
        vm.stopPrank();

        assertEq(ids.length, 2, "two invoice ids");
        assertEq(ids[0], 1, "first id (company A, first seen)");
        assertEq(ids[1], 2, "second id (company B)");

        assertEq(ecommerce.getCustomerInvoices(customer).length, 2, "two invoices for customer");
        assertEq(ecommerce.getCompanyInvoices(1).length, 1, "company A one invoice");
        assertEq(ecommerce.getCompanyInvoices(2).length, 1, "company B one invoice");

        InvoiceLib.Invoice memory invA = ecommerce.getInvoice(1);
        assertEq(invA.companyId, 1, "inv1 company A");
        assertEq(invA.lines.length, 2, "inv1 two lines");
        assertEq(invA.total, totalA, "inv1 total");
        assertFalse(invA.isPaid, "inv1 unpaid");

        InvoiceLib.Invoice memory invB = ecommerce.getInvoice(2);
        assertEq(invB.companyId, 2, "inv2 company B");
        assertEq(invB.lines.length, 1, "inv2 one line");
        assertEq(invB.total, totalB, "inv2 total");
        assertFalse(invB.isPaid, "inv2 unpaid");

        // nothing settled, stock intact, cart cleared
        assertEq(token.balanceOf(payoutA), 0, "A not paid");
        assertEq(token.balanceOf(payoutB), 0, "B not paid");
        assertEq(ecommerce.getProduct(1).stock, 10, "pid1");
        assertEq(ecommerce.getProduct(2).stock, 10, "pid2");
        assertEq(ecommerce.getProduct(3).stock, 10, "pid3");
        assertEq(ecommerce.getCart(customer).length, 0, "cart cleared");
    }

    /// @notice The unit price is a snapshot FROZEN at checkout (phase 1), not at add-to-cart time.
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

        InvoiceLib.Invoice memory inv = ecommerce.getInvoice(1);
        assertEq(inv.lines[0].unitPrice, 30e6, "unitPrice frozen at checkout-time price");
        assertEq(inv.total, 2 * 30e6, "total uses checkout-time price");
    }

    // ── reverts ──────────────────────────────────────────────────────────────────────────────

    /// @notice checkout on an empty cart reverts EmptyCart.
    function test_checkout_empty_cart_reverts() public {
        vm.startPrank(customer);
        vm.expectRevert(Ecommerce.EmptyCart.selector);
        ecommerce.checkout();
        vm.stopPrank();
    }

    /// @notice Phase 1 does NOT validate stock: a qty above stock still creates the invoice. Stock is
    ///         taken at payment (phase 2), so an oversized line only fails when `processPayment` runs.
    function test_checkout_does_not_check_stock() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 100); // qty 100 > stock 10 (addToCart never checks stock either)
        uint256[] memory ids = ecommerce.checkout(); // does NOT revert in phase 1
        vm.stopPrank();

        assertEq(ids.length, 1, "invoice created despite low stock");
        assertEq(ecommerce.getInvoice(1).lines[0].quantity, 100, "qty 100 billed");
        assertEq(ecommerce.getProduct(1).stock, 10, "stock untouched in phase 1");
    }
}
