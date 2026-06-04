// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ProductLib} from "../src/libraries/ProductLib.sol";

/**
 * @title  ProductLibHarness
 * @notice Test-only storage owner exposing `external` wrappers over ProductLib's internal funcs.
 */
contract ProductLibHarness {
    using ProductLib for mapping(uint256 => ProductLib.Product);
    using ProductLib for ProductLib.Product;

    mapping(uint256 => ProductLib.Product) internal products;

    function add(
        uint256 id,
        uint256 companyId,
        string calldata name,
        string calldata ipfsCid,
        uint256 price,
        uint256 stock
    ) external {
        products.add(id, companyId, name, ipfsCid, price, stock);
    }

    function update(
        uint256 id,
        string calldata name,
        string calldata ipfsCid,
        uint256 price,
        uint256 stock,
        bool active
    ) external {
        products[id].update(name, ipfsCid, price, stock, active);
    }

    function decreaseStock(uint256 id, uint256 qty) external {
        products[id].decreaseStock(qty);
    }

    function increaseStock(uint256 id, uint256 qty) external {
        products[id].increaseStock(qty);
    }

    function requireInStock(uint256 id, uint256 qty) external view {
        products[id].requireInStock(qty);
    }

    function get(uint256 id) external view returns (ProductLib.Product memory) {
        return products[id];
    }
}

/**
 * @title  ProductLib test suite
 * @notice Isolated unit tests for ProductLib: add state/validation, events, stock arithmetic.
 */
contract ProductLibTest is Test {
    ProductLibHarness internal harness;

    // 🇪🇸 NOTA: CIDv0 real de IPFS (carpeta vacía), 46 chars exactos => pasa la validación de longitud.
    string internal constant CID = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    uint256 internal constant COMPANY_ID = 1;
    uint256 internal constant PRICE = 10e6; // 10 EURT (6 decimales)

    event ProductAdded(uint256 indexed id, uint256 indexed companyId, uint256 price, uint256 stock);
    event ProductUpdated(uint256 indexed id, uint256 price, uint256 stock, bool active);

    function setUp() public {
        harness = new ProductLibHarness();
    }

    /// @notice add writes all fields and defaults active to true.
    function test_add_stores_product() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);

        ProductLib.Product memory p = harness.get(1);
        assertEq(p.id, 1, "id");
        assertEq(p.companyId, COMPANY_ID, "companyId");
        assertEq(p.name, "Widget", "name");
        assertEq(p.ipfsCid, CID, "ipfsCid");
        assertEq(p.price, PRICE, "price");
        assertEq(p.stock, 5, "stock");
        assertTrue(p.active, "active defaults to true");
    }

    /// @notice stock = 0 is allowed at creation ("coming soon").
    function test_add_stock_zero_allowed() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 0);
        assertEq(harness.get(1).stock, 0, "stock 0 allowed");
    }

    /// @notice add emits ProductAdded(id, companyId, price, stock).
    function test_add_emits_event() public {
        vm.expectEmit(true, true, false, true, address(harness));
        emit ProductAdded(1, COMPANY_ID, PRICE, 5);
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);
    }

    /// @notice price = 0 reverts InvalidPrice().
    function test_add_zero_price_reverts() public {
        vm.expectRevert(ProductLib.InvalidPrice.selector);
        harness.add(1, COMPANY_ID, "Widget", CID, 0, 5);
    }

    /// @notice empty name reverts EmptyName().
    function test_add_empty_name_reverts() public {
        vm.expectRevert(ProductLib.EmptyName.selector);
        harness.add(1, COMPANY_ID, "", CID, PRICE, 5);
    }

    /// @notice empty ipfsCid reverts EmptyIpfsCid().
    function test_add_empty_cid_reverts() public {
        vm.expectRevert(ProductLib.EmptyIpfsCid.selector);
        harness.add(1, COMPANY_ID, "Widget", "", PRICE, 5);
    }

    /// @notice non-empty but too-short ipfsCid reverts InvalidIpfsCidLength().
    function test_add_short_cid_reverts() public {
        vm.expectRevert(ProductLib.InvalidIpfsCidLength.selector);
        harness.add(1, COMPANY_ID, "Widget", "Qm123", PRICE, 5);
    }

    /// @notice decreaseStock subtracts when enough stock exists.
    function test_decreaseStock_ok() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);
        harness.decreaseStock(1, 3);
        assertEq(harness.get(1).stock, 2, "stock after decrease");
    }

    /// @notice decreaseStock beyond available reverts InsufficientStock(id, requested, available).
    function test_decreaseStock_insufficient_reverts() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProductLib.InsufficientStock.selector, uint256(1), uint256(10), uint256(5)
            )
        );
        harness.decreaseStock(1, 10);
    }

    /// @notice increaseStock adds to the available stock.
    function test_increaseStock_ok() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);
        harness.increaseStock(1, 7);
        assertEq(harness.get(1).stock, 12, "stock after increase");
    }

    /// @notice requireInStock passes at the boundary and reverts just above it.
    function test_requireInStock_boundary() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);
        harness.requireInStock(1, 5); // exactly available: OK

        vm.expectRevert(
            abi.encodeWithSelector(
                ProductLib.InsufficientStock.selector, uint256(1), uint256(6), uint256(5)
            )
        );
        harness.requireInStock(1, 6);
    }

    /// @notice update overwrites mutable fields, keeps id/companyId, and emits ProductUpdated.
    function test_update_changes_fields_and_emits() public {
        harness.add(1, COMPANY_ID, "Widget", CID, PRICE, 5);

        vm.expectEmit(true, false, false, true, address(harness));
        emit ProductUpdated(1, 20e6, 3, false);
        harness.update(1, "Gadget", CID, 20e6, 3, false);

        ProductLib.Product memory p = harness.get(1);
        assertEq(p.name, "Gadget", "name updated");
        assertEq(p.price, 20e6, "price updated");
        assertEq(p.stock, 3, "stock updated");
        assertTrue(!p.active, "active updated to false");
        assertEq(p.id, 1, "id immutable");
        assertEq(p.companyId, COMPANY_ID, "companyId immutable");
    }
}
