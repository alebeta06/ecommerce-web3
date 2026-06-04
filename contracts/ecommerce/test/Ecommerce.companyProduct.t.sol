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
