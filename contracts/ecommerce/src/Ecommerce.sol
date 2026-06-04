// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: SPDX = licencia del código (obligatorio o el compilador avisa). MIT = permisiva.
pragma solidity 0.8.28;

// 🇪🇸 NOTA: importamos 3 piezas de OpenZeppelin v5 (auditadas y estándar):
//  - AccessControl:   control de acceso por ROLES (bytes32), no por un único owner.
//  - IERC20:          la INTERFAZ del token EURT. Solo necesitamos su firma (transferFrom,
//                     balanceOf, allowance…), NO el bytecode de EuroToken => bajo acoplamiento.
//  - ReentrancyGuard: provee el modifier `nonReentrant`. Se hereda ya (lo usará processPayment
//                     en la sesión 4); reservar su slot ahora deja la base lista.
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {CompanyLib} from "./libraries/CompanyLib.sol";
import {ProductLib} from "./libraries/ProductLib.sol";

/**
 * @title  Ecommerce
 * @notice On-chain store logic (Component 4): companies and their products, settled in EURT.
 *         This is the BASE version (session 2): company registration + product catalog. Carts,
 *         invoices and payments arrive in later sessions.
 * @dev    Orchestrator that OWNS all storage and delegates entity logic to internal libraries
 *         (`CompanyLib`, `ProductLib`) via `using-for`. Access is role-based (AccessControl).
 *
 * 🇪🇸 NOTA — AccessControl vs Ownable (recordatorio):
 *  - Ownable (usado en EuroToken) = UN solo `owner` con todos los privilegios. Simple.
 *  - AccessControl = ROLES (bytes32) que se conceden a direcciones. Aquí hay varios actores
 *    privilegiados (admin de plataforma + dueños de cada empresa), así que los roles encajan
 *    mejor. `DEFAULT_ADMIN_ROLE` es el rol raíz que ya trae AccessControl.
 */
contract Ecommerce is AccessControl, ReentrancyGuard {
    // 🇪🇸 NOTA: `using LibX for T;` adjunta las funciones de la librería al tipo T, de modo que
    // se pueden llamar como métodos. El receptor se pasa como primer parámetro `self`.
    //  - Sobre el MAPPING: companies.register(...), companies.get(...), products.add(...).
    //  - Sobre el STRUCT Product: product.decreaseStock(...), etc. (se usará en sesiones futuras).
    using CompanyLib for mapping(uint256 => CompanyLib.Company);
    using ProductLib for mapping(uint256 => ProductLib.Product);
    using ProductLib for ProductLib.Product;

    // 🇪🇸 NOTA: `immutable` => se fija UNA vez en el constructor y se graba en el bytecode (no en
    // storage), por lo que leerlo es barato. La dirección de EURT nunca cambia tras el deploy.
    IERC20 public immutable eurt;

    // 🇪🇸 NOTA: el contrato es el ÚNICO dueño del storage. Las librerías solo lo mutan vía punteros.
    mapping(uint256 => CompanyLib.Company) public companies;
    uint256 public companyCount;

    mapping(uint256 => ProductLib.Product) public products;
    uint256 public productCount;

    // 🇪🇸 NOTA: índice inverso owner => companyId (1:1 en esta sesión). Permite a `onlyCompanyOwner`
    // y al front saber qué empresa gestiona una dirección. id 0 = "sin empresa" (centinela).
    mapping(address => uint256) public companyOf;

    error InvalidEurtAddress();
    error InvalidAdmin();
    error NotCompanyOwner(uint256 companyId, address caller);

    /**
     * @param eurtAddress Address of the deployed EURT (EuroToken) ERC20.
     * @param admin       Address granted `DEFAULT_ADMIN_ROLE` (platform administrator).
     *
     * 🇪🇸 NOTA: `_grantRole` es la función interna de AccessControl que asigna un rol. El admin
     * podrá registrar empresas y, por ser rol raíz, gestionar otros roles en el futuro.
     */
    constructor(address eurtAddress, address admin) {
        if (eurtAddress == address(0)) revert InvalidEurtAddress();
        if (admin == address(0)) revert InvalidAdmin();
        eurt = IERC20(eurtAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Restrict a call to the OWNER of a specific company.
     * @param companyId The company whose owner is required.
     *
     * 🇪🇸 NOTA — modifier custom: a diferencia de `onlyRole` (permiso GLOBAL), esto es un permiso
     * POR-EMPRESA: comprueba que msg.sender == el `owner` de ESA empresa. `companies.get` revierte
     * CompanyNotFound si la empresa no existe (se valida existencia antes que propiedad).
     */
    modifier onlyCompanyOwner(uint256 companyId) {
        CompanyLib.Company storage company = companies.get(companyId);
        if (msg.sender != company.owner) revert NotCompanyOwner(companyId, msg.sender);
        _;
    }

    /**
     * @notice Register a new seller company. Only the platform admin can call this.
     * @param owner        Address that will MANAGE the company (add/update products).
     * @param name         Human-readable company name (non-empty).
     * @param payoutWallet Address that will RECEIVE EURT payments (non-empty; may equal owner).
     * @return id          The newly assigned company id (starts at 1).
     *
     * 🇪🇸 NOTA: pre-incremento `++companyCount` => el primer id es 1 (dejamos el 0 como centinela
     * "no existe" en `companyOf`). El contrato asigna el id y la librería valida/escribe.
     */
    function registerCompany(address owner, string calldata name, address payoutWallet)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256 id)
    {
        id = ++companyCount;
        companies.register(id, owner, name, payoutWallet);
        companyOf[owner] = id;
    }

    /**
     * @notice Read a company by id. Reverts `CompanyNotFound` if it does not exist.
     * @param companyId The company id.
     * @return The stored company (copied to memory for the external return).
     */
    function getCompany(uint256 companyId) external view returns (CompanyLib.Company memory) {
        return companies.get(companyId);
    }

    /**
     * @notice Add a product to a company's catalog. Only that company's owner can call this.
     * @param companyId The owning company id.
     * @param name      Product name (non-empty).
     * @param ipfsCid   IPFS CID of the product image (non-empty, length >= 46).
     * @param price     Unit price in EURT base units (6 decimals, > 0).
     * @param stock     Initial stock (0 allowed).
     * @return id        The newly assigned product id (starts at 1).
     */
    function addProduct(
        uint256 companyId,
        string calldata name,
        string calldata ipfsCid,
        uint256 price,
        uint256 stock
    ) external onlyCompanyOwner(companyId) returns (uint256 id) {
        id = ++productCount;
        products.add(id, companyId, name, ipfsCid, price, stock);
    }

    /**
     * @notice Read a product by id. Reverts `ProductNotFound` if it does not exist.
     * @param productId The product id.
     * @return The stored product (copied to memory for the external return).
     *
     * 🇪🇸 NOTA: `Product` no tiene campo `exists`; comprobamos por rango del contador (los ids
     * son secuenciales 1..productCount y no se borran), reutilizando el error de ProductLib.
     */
    function getProduct(uint256 productId) external view returns (ProductLib.Product memory) {
        if (productId == 0 || productId > productCount) {
            revert ProductLib.ProductNotFound(productId);
        }
        return products[productId];
    }
}
