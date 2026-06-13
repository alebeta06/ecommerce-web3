// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployEcommerce} from "../script/DeployEcommerce.s.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {EuroToken} from "euro-token/src/EuroToken.sol";

/**
 * @title  Ecommerce end-to-end integration test
 * @notice Exercises the full two-phase flow through the REAL deployment path: setUp runs
 *         DeployEcommerce.run() (validating the script) and uses the REAL EuroToken (not a mock),
 *         so this single suite covers the script AND the multi-company purchase flow.
 *
 * 🇪🇸 NOTA: el script despliega EuroToken (Ownable) + Ecommerce y devuelve ambos. El deployer es a
 * la vez owner del token (puede mint()) y DEFAULT_ADMIN_ROLE de Ecommerce; lo recuperamos con
 * token.owner() en vez de hardcodear la address de Anvil. Usamos startPrank/stopPrank.
 */
contract EcommerceE2ETest is Test {
    Ecommerce internal ecommerce;
    EuroToken internal token;

    // 🇪🇸 deployer = owner del token = admin de Ecommerce (defaults del script, sin env vars).
    address internal deployer;

    address internal sellerA = makeAddr("sellerA");
    address internal sellerB = makeAddr("sellerB");
    address internal payoutA = makeAddr("payoutA");
    address internal payoutB = makeAddr("payoutB");
    address internal customer = makeAddr("customer");

    string internal constant CID = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";

    // Company A (id 1): products 1 (10 EURT) and 2 (25 EURT). Company B (id 2): product 3 (7 EURT).
    uint256 internal constant PRICE_A1 = 10e6;
    uint256 internal constant PRICE_A2 = 25e6;
    uint256 internal constant PRICE_B1 = 7e6;
    uint256 internal constant BUDGET = 1000e6;

    function setUp() public {
        // 🇪🇸 NOTA: el setUp dispara el SCRIPT de despliegue real (no instancia a mano). Así el E2E
        // valida también DeployEcommerce: si el script se rompe, este test lo detecta.
        DeployEcommerce deployScript = new DeployEcommerce();
        (token, ecommerce) = deployScript.run();
        deployer = token.owner(); // = ADMIN de Ecommerce con los defaults del script

        // 🇪🇸 El admin (deployer) registra dos empresas; cada seller gestiona sus productos.
        vm.startPrank(deployer);
        ecommerce.registerCompany(sellerA, "Acme", payoutA); // company id 1
        ecommerce.registerCompany(sellerB, "Globex", payoutB); // company id 2
        vm.stopPrank();

        vm.startPrank(sellerA);
        ecommerce.addProduct(1, "A1", CID, PRICE_A1, 10); // product id 1
        ecommerce.addProduct(1, "A2", CID, PRICE_A2, 10); // product id 2
        vm.stopPrank();

        vm.startPrank(sellerB);
        ecommerce.addProduct(2, "B1", CID, PRICE_B1, 10); // product id 3
        vm.stopPrank();

        // 🇪🇸 El owner del token (deployer) acuña EURT al cliente para que pueda pagar.
        vm.prank(deployer);
        token.mint(customer, BUDGET);

        vm.prank(customer);
        ecommerce.registerCustomer("Alice");
    }

    /// @notice Full happy path across two companies: register → add to cart → checkout (phase 1) →
    ///         processBatchPayments (phase 2). Asserts invoices paid, stock decremented, EURT routed
    ///         to each payoutWallet, cart emptied, and per-customer/per-company invoice indexing.
    function test_e2e_multi_company_purchase() public {
        uint256 totalA = 2 * PRICE_A1 + 1 * PRICE_A2; // 45 EURT (company A)
        uint256 totalB = 3 * PRICE_B1; // 21 EURT (company B)
        uint256 grandTotal = totalA + totalB; // 66 EURT

        vm.startPrank(customer);
        token.approve(address(ecommerce), grandTotal);
        ecommerce.addToCart(1, 1, 2); // A: 2 x product 1
        ecommerce.addToCart(1, 2, 1); // A: 1 x product 2
        ecommerce.addToCart(2, 3, 3); // B: 3 x product 3

        // ── Phase 1: checkout splits the cart into one invoice per company and empties the cart ──
        uint256[] memory ids = ecommerce.checkout();
        assertEq(ids.length, 2, "one invoice per company");
        assertEq(ecommerce.getCart(customer).length, 0, "cart emptied by checkout");

        // ── Phase 2: pay both invoices atomically ──
        ecommerce.processBatchPayments(ids);
        vm.stopPrank();

        // Invoices settled.
        assertTrue(ecommerce.getInvoice(ids[0]).isPaid, "invoice A paid");
        assertTrue(ecommerce.getInvoice(ids[1]).isPaid, "invoice B paid");

        // Stock decremented per product.
        assertEq(ecommerce.getProduct(1).stock, 8, "pid1 stock 10-2");
        assertEq(ecommerce.getProduct(2).stock, 9, "pid2 stock 10-1");
        assertEq(ecommerce.getProduct(3).stock, 7, "pid3 stock 10-3");

        // EURT routed to each seller's payoutWallet; customer debited the grand total.
        assertEq(token.balanceOf(payoutA), totalA, "payoutA received company A total");
        assertEq(token.balanceOf(payoutB), totalB, "payoutB received company B total");
        assertEq(token.balanceOf(customer), BUDGET - grandTotal, "customer debited grand total");

        // Invoice indexing: 2 for the customer, 1 per company.
        assertEq(ecommerce.getCustomerInvoices(customer).length, 2, "customer has 2 invoices");
        assertEq(ecommerce.getCompanyInvoices(1).length, 1, "company A has 1 invoice");
        assertEq(ecommerce.getCompanyInvoices(2).length, 1, "company B has 1 invoice");
    }

    /// @notice Phase-2 atomicity: an allowance covering only invoice A makes invoice B's pull fail,
    ///         and the whole batch reverts — invoice A's already-executed settlement rolls back too.
    ///         Nothing changes: no isPaid, no stock decrement, no EURT moved.
    function test_e2e_batch_payment_atomic_on_insufficient_allowance() public {
        uint256 totalA = 2 * PRICE_A1; // 20 EURT, paid first inside the batch

        vm.startPrank(customer);
        ecommerce.addToCart(1, 1, 2); // A -> invoice 1
        ecommerce.addToCart(2, 3, 1); // B -> invoice 2 (7 EURT, will fail: allowance exhausted)
        uint256[] memory ids = ecommerce.checkout();

        token.approve(address(ecommerce), totalA); // enough for invoice A only
        vm.expectRevert(); // SafeERC20 reverts on invoice B's transferFrom (insufficient allowance)
        ecommerce.processBatchPayments(ids);
        vm.stopPrank();

        // All-or-nothing: nothing settled, nothing moved.
        assertFalse(ecommerce.getInvoice(ids[0]).isPaid, "invoice A settlement rolled back");
        assertFalse(ecommerce.getInvoice(ids[1]).isPaid, "invoice B never paid");
        assertEq(ecommerce.getProduct(1).stock, 10, "pid1 stock intact");
        assertEq(ecommerce.getProduct(3).stock, 10, "pid3 stock intact");
        assertEq(token.balanceOf(payoutA), 0, "company A not paid");
        assertEq(token.balanceOf(payoutB), 0, "company B not paid");
        assertEq(token.balanceOf(customer), BUDGET, "customer not debited at all");
    }
}
