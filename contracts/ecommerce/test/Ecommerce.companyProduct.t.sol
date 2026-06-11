// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ecommerce} from "../src/Ecommerce.sol";
import {CompanyLib} from "../src/libraries/CompanyLib.sol";
import {ProductLib} from "../src/libraries/ProductLib.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title  Ecommerce company+product integration tests
 * @notice Verifies the orchestrator wires CompanyLib/ProductLib correctly and enforces access:
 *         admin-only company registration and per-company-owner product creation.
 *
 * 🇪🇸 NOTA: el constructor solo GUARDA la dirección de EURT (no la llama esta sesión), así que
 * pasamos una dirección no-cero cualquiera (makeAddr). La integración con EURT llega en sesión 4.
 */
contract EcommerceCompanyProductTest is Test {
    Ecommerce internal ecommerce;

    address internal admin = makeAddr("admin");
    address internal seller = makeAddr("seller");
    address internal payout = makeAddr("payout");
    address internal stranger = makeAddr("stranger");

    string internal constant CID = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    uint256 internal constant PRICE = 10e6;

    // 🇪🇸 NOTA: redeclaramos el evento aquí para usarlo en vm.expectEmit. Lo emite ProductLib, pero
    // al ser librería `internal` se emite desde la dirección del contrato Ecommerce.
    event ProductUpdated(uint256 indexed id, uint256 price, uint256 stock, bool active);

    function setUp() public {
        ecommerce = new Ecommerce(makeAddr("eurt"), admin);
    }

    /// @notice The admin registers a company; state, companyOf index and counter update.
    function test_admin_registers_company() public {
        vm.prank(admin);
        uint256 id = ecommerce.registerCompany(seller, "Acme", payout);

        assertEq(id, 1, "first company id is 1");
        assertEq(ecommerce.companyCount(), 1, "companyCount");
        assertEq(ecommerce.companyOf(seller), 1, "companyOf[seller]");

        CompanyLib.Company memory c = ecommerce.getCompany(1);
        assertEq(c.owner, seller, "owner");
        assertEq(c.payoutWallet, payout, "payoutWallet");
        assertEq(c.name, "Acme", "name");
        assertTrue(c.exists, "exists");
    }

    /// @notice A non-admin cannot register a company (AccessControlUnauthorizedAccount).
    function test_non_admin_register_reverts() public {
        // 🇪🇸 NOTA: leemos el rol ANTES del prank. vm.prank solo afecta a la SIGUIENTE llamada
        // externa; si llamáramos DEFAULT_ADMIN_ROLE() dentro del expectRevert, esa lectura
        // consumiría el prank y registerCompany se ejecutaría como el contrato de test.
        bytes32 adminRole = ecommerce.DEFAULT_ADMIN_ROLE();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, adminRole
            )
        );
        ecommerce.registerCompany(seller, "Acme", payout);
    }

    /// @notice The company owner can add a product; it is stored and readable.
    function test_company_owner_adds_product() public {
        vm.prank(admin);
        ecommerce.registerCompany(seller, "Acme", payout);

        vm.prank(seller);
        uint256 pid = ecommerce.addProduct(1, "Widget", CID, PRICE, 5);

        assertEq(pid, 1, "first product id is 1");
        assertEq(ecommerce.productCount(), 1, "productCount");

        ProductLib.Product memory p = ecommerce.getProduct(1);
        assertEq(p.companyId, 1, "companyId");
        assertEq(p.name, "Widget", "name");
        assertEq(p.price, PRICE, "price");
        assertEq(p.stock, 5, "stock");
        assertTrue(p.active, "active");
    }

    /// @notice A non-owner cannot add a product to a company (NotCompanyOwner).
    function test_non_owner_add_product_reverts() public {
        vm.prank(admin);
        ecommerce.registerCompany(seller, "Acme", payout);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ecommerce.NotCompanyOwner.selector, uint256(1), stranger)
        );
        ecommerce.addProduct(1, "Widget", CID, PRICE, 5);
    }

    /// @notice addProduct on a non-existent company reverts CompanyNotFound (existence before ownership).
    function test_add_product_unknown_company_reverts() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(CompanyLib.CompanyNotFound.selector, uint256(99)));
        ecommerce.addProduct(99, "Widget", CID, PRICE, 5);
    }

    /// @notice getProduct on an unknown id reverts ProductNotFound(id).
    function test_get_product_unknown_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(ProductLib.ProductNotFound.selector, uint256(99)));
        ecommerce.getProduct(99);
    }

    // ── updateProduct ──────────────────────────────────────────────────────────────────────────

    /// @dev Register company 1 owned by `seller` and add one product with `stock`; return its id.
    function _seedProduct(uint256 stock) internal returns (uint256 pid) {
        vm.startPrank(admin);
        ecommerce.registerCompany(seller, "Acme", payout);
        vm.stopPrank();
        vm.startPrank(seller);
        pid = ecommerce.addProduct(1, "Widget", CID, PRICE, stock);
        vm.stopPrank();
    }

    /// @notice The company owner updates price/stock/active and ProductUpdated is emitted.
    function test_updateProduct_owner_updates() public {
        uint256 pid = _seedProduct(5);

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true, address(ecommerce));
        emit ProductUpdated(pid, 20e6, 8, false);
        ecommerce.updateProduct(1, pid, 20e6, 8, false);
        vm.stopPrank();

        ProductLib.Product memory p = ecommerce.getProduct(pid);
        assertEq(p.price, 20e6, "price updated");
        assertEq(p.stock, 8, "stock updated");
        assertFalse(p.active, "active updated to false");
    }

    /// @notice updateProduct preserves name and ipfsCid (only price/stock/active change).
    function test_updateProduct_preserves_name_and_cid() public {
        uint256 pid = _seedProduct(5);

        vm.startPrank(seller);
        ecommerce.updateProduct(1, pid, 20e6, 8, true);
        vm.stopPrank();

        ProductLib.Product memory p = ecommerce.getProduct(pid);
        assertEq(p.name, "Widget", "name preserved");
        assertEq(p.ipfsCid, CID, "ipfsCid preserved");
    }

    /// @notice A deactivated product can be reactivated (updateProduct does NOT block on inactive).
    function test_updateProduct_can_reactivate() public {
        uint256 pid = _seedProduct(5);

        vm.startPrank(seller);
        ecommerce.updateProduct(1, pid, PRICE, 5, false); // deactivate
        ecommerce.updateProduct(1, pid, PRICE, 5, true); // reactivate
        vm.stopPrank();

        assertTrue(ecommerce.getProduct(pid).active, "product reactivated");
    }

    /// @notice A non-owner cannot update a product (NotCompanyOwner).
    function test_updateProduct_non_owner_reverts() public {
        uint256 pid = _seedProduct(5);

        vm.startPrank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ecommerce.NotCompanyOwner.selector, uint256(1), stranger)
        );
        ecommerce.updateProduct(1, pid, 20e6, 8, true);
        vm.stopPrank();
    }

    /// @notice updateProduct on a non-existent product reverts ProductNotFound(id).
    function test_updateProduct_unknown_product_reverts() public {
        _seedProduct(5); // company 1 exists & owned by seller

        vm.startPrank(seller);
        vm.expectRevert(abi.encodeWithSelector(ProductLib.ProductNotFound.selector, uint256(99)));
        ecommerce.updateProduct(1, 99, 20e6, 8, true);
        vm.stopPrank();
    }

    /// @notice updateProduct with a companyId that doesn't own the product reverts ProductCompanyMismatch.
    function test_updateProduct_company_mismatch_reverts() public {
        uint256 pid = _seedProduct(5); // product belongs to company 1 (seller)

        // 🇪🇸 NOTA: segunda empresa (id 2) propiedad de `stranger`; el producto sigue siendo de la 1.
        vm.startPrank(admin);
        ecommerce.registerCompany(stranger, "Globex", payout);
        vm.stopPrank();

        vm.startPrank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ecommerce.ProductCompanyMismatch.selector, uint256(2), pid)
        );
        ecommerce.updateProduct(2, pid, 20e6, 8, true);
        vm.stopPrank();
    }

    /// @notice updateProduct with price 0 reverts InvalidPrice (validated in ProductLib).
    function test_updateProduct_zero_price_reverts() public {
        uint256 pid = _seedProduct(5);

        vm.startPrank(seller);
        vm.expectRevert(ProductLib.InvalidPrice.selector);
        ecommerce.updateProduct(1, pid, 0, 8, true);
        vm.stopPrank();
    }

    /// @notice Deploying with a zero EURT address reverts InvalidEurtAddress().
    function test_constructor_zero_eurt_reverts() public {
        vm.expectRevert(Ecommerce.InvalidEurtAddress.selector);
        new Ecommerce(address(0), admin);
    }

    /// @notice Deploying with a zero admin address reverts InvalidAdmin().
    function test_constructor_zero_admin_reverts() public {
        vm.expectRevert(Ecommerce.InvalidAdmin.selector);
        new Ecommerce(makeAddr("eurt"), address(0));
    }
}
