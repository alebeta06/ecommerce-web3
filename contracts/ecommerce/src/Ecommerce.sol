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
import {CustomerLib} from "./libraries/CustomerLib.sol";
import {CartLib} from "./libraries/CartLib.sol";

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
    // 🇪🇸 NOTA: CustomerLib opera sobre el MAPPING (register/get/updateName reciben el mapping como
    // self). CartLib opera sobre el STRUCT Cart (addItem/removeItem/clear/getItems reciben el Cart).
    using CustomerLib for mapping(address => CustomerLib.Customer);
    using CartLib for CartLib.Cart;

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

    // 🇪🇸 NOTA: clientes y carritos son self-service (sin roles): la clave es la wallet del cliente.
    //  - `customers` es `public` (auto-getter gratis) + `getCustomer` (que revierte si no existe),
    //    mismo patrón que `companies` + `getCompany`.
    //  - `carts` DEBE ser `private`: el struct `Cart` contiene un mapping y Solidity no puede generar
    //    el getter automático de un mapping anidado. Se lee vía `getCart`.
    mapping(address => CustomerLib.Customer) public customers;
    mapping(address => CartLib.Cart) private carts;

    error InvalidEurtAddress();
    error InvalidAdmin();
    error NotCompanyOwner(uint256 companyId, address caller);
    // 🇪🇸 NOTA: el carrito denormaliza `companyId` en cada línea. Validamos que coincida con el
    // `companyId` REAL del producto: sin esto, en checkout (sesión 4) se pagaría a la empresa
    // equivocada (la línea se trocea por `companyId`). Args ⇒ contexto de depuración.
    error ProductCompanyMismatch(uint256 companyId, uint256 productId);

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
        _requireProductExists(productId);
        return products[productId];
    }

    /**
     * @notice Update a product's price, stock and visibility. Only that company's owner can call.
     * @param companyId The owning company id.
     * @param productId The product id (must belong to `companyId`).
     * @param newPrice  New unit price in EURT base units (6 decimals, > 0).
     * @param newStock  New absolute stock (0 allowed).
     * @param active    New visibility flag (true = visible/addable, false = hidden).
     *
     * 🇪🇸 NOTA: este endpoint NO edita `name` ni `ipfsCid` (se preservan); reusa
     * `ProductLib.update()` pasándole los valores actuales de esos campos. Usamos
     * `_requireCompanyProduct` (existencia + pertenencia) y NO `_requireAddableProduct`: este último
     * revierte en productos inactivos, lo que haría IMPOSIBLE reactivar uno. El control de acceso
     * es por empresa: `onlyCompanyOwner` valida `msg.sender == company.owner`. La lib valida
     * `price > 0` y emite `ProductUpdated` (no añadimos evento aquí).
     */
    function updateProduct(
        uint256 companyId,
        uint256 productId,
        uint256 newPrice,
        uint256 newStock,
        bool active
    ) external onlyCompanyOwner(companyId) {
        ProductLib.Product storage product = _requireCompanyProduct(companyId, productId);
        product.update(product.name, product.ipfsCid, newPrice, newStock, active);
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // Customers (self-service: the customer is always msg.sender)
    // ─────────────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Register the caller as a customer. The customer IS `msg.sender`.
     * @param name Display name (non-empty).
     *
     * 🇪🇸 NOTA: self-service, sin roles. `CustomerLib.register` valida (wallet≠0, name no vacío,
     * no re-registro), sella `createdAt` y emite `CustomerRegistered`.
     */
    function registerCustomer(string calldata name) external {
        customers.register(msg.sender, name);
    }

    /**
     * @notice Update the caller's display name.
     * @param newName New display name (non-empty).
     *
     * 🇪🇸 NOTA: `updateName` revierte `CustomerNotFound` si el caller no está registrado y emite
     * `CustomerUpdated`. No añadimos eventos nuevos aquí (ya los emite CustomerLib).
     */
    function updateCustomerName(string calldata newName) external {
        customers.updateName(msg.sender, newName);
    }

    /**
     * @notice Read a customer by wallet. Reverts `CustomerNotFound` if not registered.
     * @param wallet The customer's address.
     * @return The stored customer (copied to memory for the external return).
     */
    function getCustomer(address wallet) external view returns (CustomerLib.Customer memory) {
        return customers.get(wallet);
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // Cart (self-service: the cart is always carts[msg.sender])
    // ─────────────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Add `quantity` of a company's product to the caller's cart.
     * @param companyId Owning company id (must match the product's real company).
     * @param productId Global product id (must exist).
     * @param quantity  Amount to add (must be > 0; validated by CartLib).
     *
     * 🇪🇸 NOTA — orquestación de la validación cruzada (D1: CartLib es pura, valida AQUÍ):
     *  1) `customers.get(msg.sender)` exige cliente registrado (D6); revierte CustomerNotFound.
     *  2) `_requireAddableProduct` valida existencia + coincidencia de empresa.
     *  3) El stock NO se valida al añadir (D5): se reserva en el checkout (sesión 4).
     *  4) `cart.addItem` valida `quantity > 0` y acumula si el par ya estaba (D3).
     */
    function addToCart(uint256 companyId, uint256 productId, uint256 quantity) external {
        customers.get(msg.sender);
        _requireAddableProduct(companyId, productId);
        carts[msg.sender].addItem(companyId, productId, quantity);
    }

    /**
     * @notice Remove a product line from the caller's cart entirely.
     * @param companyId The line's company id.
     * @param productId The line's product id.
     *
     * 🇪🇸 NOTA: no exigimos registro: un no-registrado nunca pudo añadir nada, así que su carrito
     * está vacío y `removeItem` revierte `ItemNotInCart`. Mínimo y seguro.
     */
    function removeFromCart(uint256 companyId, uint256 productId) external {
        carts[msg.sender].removeItem(companyId, productId);
    }

    /**
     * @notice Empty the caller's cart.
     *
     * 🇪🇸 NOTA: idempotente: sobre un carrito vacío es un no-op (CartLib.clear no revierte).
     */
    function clearCart() external {
        carts[msg.sender].clear();
    }

    /**
     * @notice Read a wallet's cart lines.
     * @param wallet The cart owner's address.
     * @return The cart items copied to memory.
     */
    function getCart(address wallet) external view returns (CartLib.CartItem[] memory) {
        return carts[wallet].getItems();
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────────────────────

    /**
     * @dev Revert unless `productId` refers to an existing product.
     *
     * 🇪🇸 NOTA: misma condición EXACTA que tenía `getProduct` (ids secuenciales 1..productCount,
     * no se borran). Extraída para reusarla en `getProduct` y en la validación del carrito.
     */
    function _requireProductExists(uint256 productId) private view {
        if (productId == 0 || productId > productCount) {
            revert ProductLib.ProductNotFound(productId);
        }
    }

    /**
     * @dev Resolve a product that exists AND belongs to `companyId`, returning its storage ref.
     * @param companyId Claimed owning company id.
     * @param productId Global product id.
     * @return product  Storage reference to the validated product.
     *
     * 🇪🇸 NOTA: existencia + coincidencia de empresa, SIN chequear `active`. Es la base compartida
     * por `_requireAddableProduct` (carrito) y `updateProduct`. Este último NO puede exigir `active`
     * porque entonces sería imposible reactivar un producto desactivado.
     */
    function _requireCompanyProduct(uint256 companyId, uint256 productId)
        private
        view
        returns (ProductLib.Product storage product)
    {
        _requireProductExists(productId);
        product = products[productId];
        if (product.companyId != companyId) revert ProductCompanyMismatch(companyId, productId);
    }

    /**
     * @dev Cross-validate a product before it enters a cart (D1 lives here, not in CartLib).
     * @param companyId Claimed owning company id.
     * @param productId Global product id.
     *
     * 🇪🇸 NOTA: existencia + empresa (vía `_requireCompanyProduct`) + VISIBILIDAD (`active`). NO
     * validamos `stock` aquí: separamos responsabilidades — `active` = addability/visibilidad (se
     * exige al añadir al carrito), `stock` = comprabilidad (se reserva en checkout, D5). Un producto
     * inactivo no puede entrar al carrito; revierte `ProductInactive`.
     */
    function _requireAddableProduct(uint256 companyId, uint256 productId) private view {
        ProductLib.Product storage product = _requireCompanyProduct(companyId, productId);
        if (!product.active) revert ProductLib.ProductInactive(productId);
    }
}
