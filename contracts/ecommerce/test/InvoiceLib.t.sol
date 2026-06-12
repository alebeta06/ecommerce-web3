// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {InvoiceLib} from "../src/libraries/InvoiceLib.sol";

/**
 * @title  InvoiceLibHarness
 * @notice Test-only storage owner exposing `external` wrappers over InvoiceLib's internal funcs.
 * @dev    No constructor init: `invoiceCount` starts at 0 (default) and `create` pre-increments it,
 *         so the first invoice id is 1 (same pattern as companyCount/productCount).
 */
contract InvoiceLibHarness {
    using InvoiceLib for InvoiceLib.Storage;

    InvoiceLib.Storage internal store;

    function create(address customer, uint256 companyId, InvoiceLib.InvoiceLine[] calldata lines)
        external
        returns (uint256 id)
    {
        id = store.create(customer, companyId, lines);
    }

    function markPaid(uint256 id) external {
        store.markPaid(id);
    }

    function get(uint256 id) external view returns (InvoiceLib.Invoice memory) {
        return store.get(id);
    }

    function invoiceCount() external view returns (uint256) {
        return store.invoiceCount;
    }

    function customerInvoiceIds(address customer) external view returns (uint256[] memory) {
        return store.customerInvoiceIds(customer);
    }

    function companyInvoiceIds(uint256 companyId) external view returns (uint256[] memory) {
        return store.companyInvoiceIds(companyId);
    }
}

/**
 * @title  InvoiceLib test suite
 * @notice Isolated unit tests for InvoiceLib: sequential ids, total computation from lines, stored
 *         fields, reverse indexes, the InvoiceCreated event and get() existence checks.
 */
contract InvoiceLibTest is Test {
    InvoiceLibHarness internal harness;

    address internal customer = makeAddr("customer");
    uint256 internal constant COMPANY_ID = 7;

    event InvoiceCreated(
        uint256 indexed id, address indexed customer, uint256 indexed companyId, uint256 total
    );

    function setUp() public {
        harness = new InvoiceLibHarness();
    }

    // ── helpers ──────────────────────────────────────────────────────────────────────────────

    /// @dev Build a two-line array: (productId 1, qty 2, price 10) and (productId 2, qty 1, price 5).
    function _twoLines() internal pure returns (InvoiceLib.InvoiceLine[] memory lines) {
        lines = new InvoiceLib.InvoiceLine[](2);
        lines[0] = InvoiceLib.InvoiceLine({productId: 1, quantity: 2, unitPrice: 10e6});
        lines[1] = InvoiceLib.InvoiceLine({productId: 2, quantity: 1, unitPrice: 5e6});
    }

    // ── create ───────────────────────────────────────────────────────────────────────────────

    /// @notice The counter starts at 0; create pre-increments it, assigning sequential ids from 1.
    function test_create_assigns_sequential_ids() public {
        assertEq(harness.invoiceCount(), 0, "counter starts at 0");

        uint256 id1 = harness.create(customer, COMPANY_ID, _twoLines());
        uint256 id2 = harness.create(customer, COMPANY_ID, _twoLines());

        assertEq(id1, 1, "first id is 1");
        assertEq(id2, 2, "second id is 2");
        assertEq(harness.invoiceCount(), 2, "invoiceCount advanced to 2");
    }

    /// @notice create computes total = sum(unitPrice * quantity) and stores all fields + lines.
    function test_create_computes_total_and_stores_fields() public {
        vm.warp(1_700_000_000);
        uint256 id = harness.create(customer, COMPANY_ID, _twoLines());

        InvoiceLib.Invoice memory inv = harness.get(id);
        assertEq(inv.id, 1, "id");
        assertEq(inv.customer, customer, "customer");
        assertEq(inv.companyId, COMPANY_ID, "companyId");
        assertEq(inv.total, 2 * 10e6 + 1 * 5e6, "total = 25 EURT");
        assertEq(inv.createdAt, 1_700_000_000, "createdAt sealed");

        assertEq(inv.lines.length, 2, "two lines");
        assertEq(inv.lines[0].productId, 1, "line0 productId");
        assertEq(inv.lines[0].quantity, 2, "line0 quantity");
        assertEq(inv.lines[0].unitPrice, 10e6, "line0 unitPrice");
        assertEq(inv.lines[1].productId, 2, "line1 productId");
        assertEq(inv.lines[1].unitPrice, 5e6, "line1 unitPrice");
    }

    /// @notice create registers the new id in both the customer and company reverse indexes.
    function test_create_populates_indexes() public {
        uint256 id1 = harness.create(customer, COMPANY_ID, _twoLines());
        uint256 id2 = harness.create(customer, COMPANY_ID, _twoLines());

        uint256[] memory byCustomer = harness.customerInvoiceIds(customer);
        assertEq(byCustomer.length, 2, "two invoices for customer");
        assertEq(byCustomer[0], id1, "customer idx[0]");
        assertEq(byCustomer[1], id2, "customer idx[1]");

        uint256[] memory byCompany = harness.companyInvoiceIds(COMPANY_ID);
        assertEq(byCompany.length, 2, "two invoices for company");
        assertEq(byCompany[0], id1, "company idx[0]");
        assertEq(byCompany[1], id2, "company idx[1]");
    }

    /// @notice create emits InvoiceCreated(id, customer, companyId, total).
    function test_create_emits_event() public {
        vm.expectEmit(true, true, true, true, address(harness));
        emit InvoiceCreated(1, customer, COMPANY_ID, 2 * 10e6 + 1 * 5e6);
        harness.create(customer, COMPANY_ID, _twoLines());
    }

    // ── get ──────────────────────────────────────────────────────────────────────────────────

    /// @notice get returns the stored invoice for a valid id.
    function test_get_returns_invoice() public {
        uint256 id = harness.create(customer, COMPANY_ID, _twoLines());
        assertEq(harness.get(id).total, 25e6, "get reads back the invoice");
    }

    /// @notice get(0) reverts InvoiceNotFound(0) (id 0 is the sentinel for "no invoice").
    function test_get_zero_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(InvoiceLib.InvoiceNotFound.selector, uint256(0)));
        harness.get(0);
    }

    /// @notice get of an id >= nextInvoiceId reverts InvoiceNotFound(id) (never issued).
    function test_get_unissued_reverts() public {
        harness.create(customer, COMPANY_ID, _twoLines()); // invoiceCount becomes 1
        vm.expectRevert(abi.encodeWithSelector(InvoiceLib.InvoiceNotFound.selector, uint256(99)));
        harness.get(99);
    }

    // ── markPaid ─────────────────────────────────────────────────────────────────────────────

    /// @notice A freshly created invoice starts unpaid (phase-1 semantics: created at checkout).
    function test_create_invoice_starts_unpaid() public {
        uint256 id = harness.create(customer, COMPANY_ID, _twoLines());
        assertFalse(harness.get(id).isPaid, "new invoice is unpaid");
    }

    /// @notice markPaid flips isPaid to true (phase-2 settlement).
    function test_markPaid_sets_flag() public {
        uint256 id = harness.create(customer, COMPANY_ID, _twoLines());
        harness.markPaid(id);
        assertTrue(harness.get(id).isPaid, "invoice marked paid");
    }

    /// @notice markPaid on an already-paid invoice reverts InvoiceAlreadyPaid(id).
    function test_markPaid_twice_reverts() public {
        uint256 id = harness.create(customer, COMPANY_ID, _twoLines());
        harness.markPaid(id);
        vm.expectRevert(abi.encodeWithSelector(InvoiceLib.InvoiceAlreadyPaid.selector, id));
        harness.markPaid(id);
    }

    /// @notice markPaid on a non-existent id reverts InvoiceNotFound(id) (reused from get).
    function test_markPaid_nonexistent_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(InvoiceLib.InvoiceNotFound.selector, uint256(99)));
        harness.markPaid(99);
    }
}
