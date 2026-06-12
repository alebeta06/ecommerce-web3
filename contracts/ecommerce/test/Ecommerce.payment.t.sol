// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {ProductLib} from "../src/libraries/ProductLib.sol";
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
 * @title  Ecommerce payment (phase 2) tests
 * @notice Phase 2 of the two-phase flow: the gateway pays invoices created in phase 1.
 *         `processPayment` settles one invoice (mark paid, decrement stock, pull EURT, emit
 *         InvoicePaid); `processBatchPayments` settles several atomically (all-or-nothing).
 *
 * 🇪🇸 NOTA: el cliente aprueba allowance a Ecommerce (modelo pull) y hace checkout para crear las
 * facturas IMPAGAS; luego paga. Usamos startPrank/stopPrank. Cada test arma sus propias facturas.
 */
contract EcommercePaymentTest is Test {
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

    event InvoicePaid(uint256 indexed invoiceId, address indexed payer, uint256 total);

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

    // ── processPayment: happy path ─────────────────────────────────────────────────────────────

    /// @notice processPayment settles one invoice: marks it paid, decrements stock, pulls EURT to the
    ///         seller's payoutWallet and emits InvoicePaid.
    function test_processPayment_settles_invoice() public {
        uint256 total = 2 * PRICE1 + 1 * PRICE2; // 45 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.addToCart(1, 2, 1);
        ecommerce.checkout(); // invoice 1, unpaid

        vm.expectEmit(true, true, false, true, address(ecommerce));
        emit InvoicePaid(1, customer, total);
        ecommerce.processPayment(1);
        vm.stopPrank();

        assertTrue(ecommerce.getInvoice(1).isPaid, "invoice marked paid");
        assertEq(token.balanceOf(payoutA), total, "payoutA received total");
        assertEq(token.balanceOf(customer), MINT - total, "customer debited total");
        assertEq(ecommerce.getProduct(1).stock, 8, "pid1 stock 10-2");
        assertEq(ecommerce.getProduct(2).stock, 9, "pid2 stock 10-1");
    }

    // ── processPayment: reverts ────────────────────────────────────────────────────────────────

    /// @notice A non-owner of the invoice cannot pay it: reverts NotInvoiceCustomer(invoiceId, caller).
    function test_processPayment_not_customer_reverts() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.checkout(); // invoice 1 belongs to customer
        vm.stopPrank();

        address intruder = makeAddr("intruder");
        vm.prank(intruder);
        vm.expectRevert(
            abi.encodeWithSelector(Ecommerce.NotInvoiceCustomer.selector, uint256(1), intruder)
        );
        ecommerce.processPayment(1);
    }

    /// @notice Paying an already-paid invoice reverts InvoiceAlreadyPaid(id).
    function test_processPayment_already_paid_reverts() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.checkout();
        ecommerce.processPayment(1);
        vm.expectRevert(abi.encodeWithSelector(InvoiceLib.InvoiceAlreadyPaid.selector, uint256(1)));
        ecommerce.processPayment(1);
        vm.stopPrank();
    }

    /// @notice Stock is taken at PAYMENT: if it dropped below the invoiced qty after checkout, the
    ///         payment reverts InsufficientStock and nothing is settled.
    function test_processPayment_insufficient_stock_reverts() public {
        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 8); // stock 10 at checkout
        ecommerce.checkout(); // invoice 1 bills qty 8
        vm.stopPrank();

        // seller lowers the absolute stock below the invoiced quantity AFTER checkout
        vm.prank(sellerA);
        ecommerce.updateProduct(1, 1, PRICE1, 5, true); // stock -> 5

        vm.startPrank(customer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProductLib.InsufficientStock.selector, uint256(1), uint256(8), uint256(5)
            )
        );
        ecommerce.processPayment(1);
        vm.stopPrank();

        assertFalse(ecommerce.getInvoice(1).isPaid, "invoice still unpaid");
        assertEq(token.balanceOf(payoutA), 0, "no payment");
        assertEq(ecommerce.getProduct(1).stock, 5, "stock unchanged by the failed payment");
    }

    /// @notice An insufficient allowance reverts the pull and rolls back mark-paid and stock decrement.
    function test_processPayment_insufficient_allowance_reverts() public {
        uint256 total = 2 * PRICE1; // 20 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2);
        ecommerce.checkout();
        token.approve(address(ecommerce), total - 1); // 1 base unit short
        vm.expectRevert(); // SafeERC20 reverts on transferFrom
        ecommerce.processPayment(1);
        vm.stopPrank();

        assertFalse(ecommerce.getInvoice(1).isPaid, "invoice still unpaid");
        assertEq(ecommerce.getProduct(1).stock, 10, "stock intact after rollback");
        assertEq(token.balanceOf(payoutA), 0, "no payment");
    }

    // ── processBatchPayments ───────────────────────────────────────────────────────────────────

    /// @notice A batch pays invoices across multiple companies in one tx, each to its own payoutWallet.
    function test_processBatchPayments_multi_company() public {
        uint256 totalA = 2 * PRICE1; // 20 EURT
        uint256 totalB = 1 * PRICE3; // 50 EURT

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // A -> invoice 1
        ecommerce.addToCart(2, 3, 1); // B -> invoice 2
        uint256[] memory ids = ecommerce.checkout(); // [1, 2]
        ecommerce.processBatchPayments(ids);
        vm.stopPrank();

        assertTrue(ecommerce.getInvoice(1).isPaid, "inv1 paid");
        assertTrue(ecommerce.getInvoice(2).isPaid, "inv2 paid");
        assertEq(token.balanceOf(payoutA), totalA, "payoutA total");
        assertEq(token.balanceOf(payoutB), totalB, "payoutB total");
        assertEq(token.balanceOf(customer), MINT - totalA - totalB, "customer debited both");
        assertEq(ecommerce.getProduct(1).stock, 8, "pid1 10-2");
        assertEq(ecommerce.getProduct(3).stock, 9, "pid3 10-1");
    }

    /// @notice Batch atomicity: if the 2nd invoice's pull fails, the 1st invoice's already-executed
    ///         settlement (mark-paid, stock, transfer) is rolled back too — all-or-nothing.
    function test_processBatchPayments_atomic_on_failure() public {
        uint256 totalA = 2 * PRICE1; // 20 EURT; invoice 2 (B) costs 50, so allowance runs out

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // A -> invoice 1 (paid first inside the batch)
        ecommerce.addToCart(2, 3, 1); // B -> invoice 2 (50 EURT, will fail)
        uint256[] memory ids = ecommerce.checkout(); // [1, 2]
        token.approve(address(ecommerce), totalA); // enough for invoice 1 only
        vm.expectRevert(); // SafeERC20 reverts on invoice 2's transferFrom
        ecommerce.processBatchPayments(ids);
        vm.stopPrank();

        assertFalse(ecommerce.getInvoice(1).isPaid, "inv1 settlement rolled back");
        assertFalse(ecommerce.getInvoice(2).isPaid, "inv2 never paid");
        assertEq(token.balanceOf(payoutA), 0, "company A transfer rolled back");
        assertEq(token.balanceOf(payoutB), 0, "company B never paid");
        assertEq(token.balanceOf(customer), MINT, "customer not debited at all");
        assertEq(ecommerce.getProduct(1).stock, 10, "pid1 stock intact");
        assertEq(ecommerce.getProduct(3).stock, 10, "pid3 stock intact");
    }

    /// @notice An empty batch reverts EmptyBatch (nothing to settle; symmetric with EmptyCart).
    function test_processBatchPayments_empty_reverts() public {
        uint256[] memory ids = new uint256[](0);
        vm.prank(customer);
        vm.expectRevert(Ecommerce.EmptyBatch.selector);
        ecommerce.processBatchPayments(ids);
    }
}
