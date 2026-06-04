// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: SPDX = licencia del código (obligatorio o el compilador avisa). MIT = permisiva.
pragma solidity 0.8.28;

/**
 * @title  ProductLib
 * @notice Library that owns the `Product` entity type and the `internal` logic to add, update
 *         and manage the stock of catalog products belonging to a company.
 * @dev    Like CompanyLib, it is stateless: it operates on storage owned by the `Ecommerce`
 *         contract through `storage` pointers (`self`), attached via `using ProductLib for ...`.
 *
 * 🇪🇸 NOTA: mismo patrón que CompanyLib (library internal + using-for). El contrato `Ecommerce`
 * posee el mapping `products`; aquí solo validamos y mutamos ese storage vía el puntero `self`.
 */
library ProductLib {
    /**
     * @notice A catalog product sold by a company.
     * @dev    `companyId` links the product to its seller. `ipfsCid` is the IPFS Content ID of
     *         the product image (string: supports CIDv0 "Qm..." and CIDv1 "bafy..."). `stock`
     *         is the on-chain available quantity; `active` toggles visibility independently of
     *         stock (a product can exist with stock 0 — "coming soon" — and still be active).
     *
     * 🇪🇸 NOTA: `stock` (disponibilidad) y `active` (visibilidad) son conceptos SEPARADOS.
     * Por eso permitimos crear un producto con stock 0: la validación de stock vive en el
     * checkout (requireInStock, sesión 4), no en la creación.
     */
    struct Product {
        uint256 id;
        uint256 companyId;
        string name;
        string ipfsCid;
        uint256 price;
        uint256 stock;
        bool active;
    }

    // 🇪🇸 NOTA: Custom errors con argumentos (mismo criterio que CompanyLib).
    error EmptyName();
    error InvalidPrice();
    error EmptyIpfsCid();
    error InvalidIpfsCidLength();
    error InsufficientStock(uint256 productId, uint256 requested, uint256 available);
    error ProductNotFound(uint256 id);
    error ProductInactive(uint256 id);

    // 🇪🇸 NOTA: longitud mínima de un CID. CIDv0 ("Qm..." base58) mide EXACTAMENTE 46 chars;
    // CIDv1 ("bafy..." base32) es más largo. Con `>= 46` aceptamos ambos y rechazamos basura.
    uint256 internal constant MIN_CID_LENGTH = 46;

    /**
     * @notice Emitted when a product is added to the catalog.
     * @param id        Assigned product id (indexed).
     * @param companyId Owning company id (indexed).
     * @param price     Unit price in EURT base units (6 decimals).
     * @param stock     Initial stock.
     */
    event ProductAdded(uint256 indexed id, uint256 indexed companyId, uint256 price, uint256 stock);

    /**
     * @notice Emitted when a product's mutable fields are updated.
     * @param id     Product id (indexed).
     * @param price  New unit price.
     * @param stock  New stock.
     * @param active New visibility flag.
     */
    event ProductUpdated(uint256 indexed id, uint256 price, uint256 stock, bool active);

    /**
     * @notice Validate and write a new product into the contract's storage.
     * @param self      Storage pointer to the `id => Product` mapping (lives in Ecommerce).
     * @param id        Pre-computed id assigned by the contract (its counter).
     * @param companyId Owning company id.
     * @param name      Product name (must be non-empty).
     * @param ipfsCid   IPFS CID of the image (non-empty, length >= 46).
     * @param price     Unit price (must be > 0).
     * @param stock     Initial stock (0 is allowed).
     * @return product  Storage reference to the stored product.
     *
     * 🇪🇸 NOTA: `stock` NO se valida (0 permitido). `active` arranca en `true`.
     */
    function add(
        mapping(uint256 => Product) storage self,
        uint256 id,
        uint256 companyId,
        string memory name,
        string memory ipfsCid,
        uint256 price,
        uint256 stock
    ) internal returns (Product storage product) {
        _validate(name, ipfsCid, price);

        product = self[id];
        product.id = id;
        product.companyId = companyId;
        product.name = name;
        product.ipfsCid = ipfsCid;
        product.price = price;
        product.stock = stock;
        product.active = true;

        emit ProductAdded(id, companyId, price, stock);
    }

    /**
     * @notice Validate and overwrite a product's mutable fields.
     * @param self    Storage reference to an existing product.
     * @param name    New name (non-empty).
     * @param ipfsCid New IPFS CID (non-empty, length >= 46).
     * @param price   New unit price (> 0).
     * @param stock   New stock (0 allowed).
     * @param active  New visibility flag.
     *
     * 🇪🇸 NOTA: se adjunta con `using ProductLib for ProductLib.Product;` => `product.update(...)`.
     * `id` y `companyId` son inmutables (no se tocan aquí).
     */
    function update(
        Product storage self,
        string memory name,
        string memory ipfsCid,
        uint256 price,
        uint256 stock,
        bool active
    ) internal {
        _validate(name, ipfsCid, price);

        self.name = name;
        self.ipfsCid = ipfsCid;
        self.price = price;
        self.stock = stock;
        self.active = active;

        emit ProductUpdated(self.id, price, stock, active);
    }

    /**
     * @notice Decrease stock by `qty`, reverting if insufficient.
     * @param self Storage reference to the product.
     * @param qty  Quantity to subtract.
     *
     * 🇪🇸 NOTA: comprobamos ANTES de restar (requireInStock). Como garantiza stock >= qty,
     * la resta nunca hace underflow (y 0.8 revertiría de todos modos).
     */
    function decreaseStock(Product storage self, uint256 qty) internal {
        requireInStock(self, qty);
        self.stock -= qty;
    }

    /**
     * @notice Increase stock by `qty` (restock).
     * @param self Storage reference to the product.
     * @param qty  Quantity to add.
     *
     * 🇪🇸 NOTA: Solidity 0.8 revierte automáticamente si la suma desborda (overflow check nativo).
     */
    function increaseStock(Product storage self, uint256 qty) internal {
        self.stock += qty;
    }

    /**
     * @notice Revert unless the product has at least `qty` in stock.
     * @param self Storage reference to the product.
     * @param qty  Required quantity.
     *
     * 🇪🇸 NOTA: helper reutilizable en checkout (sesión 4). El error transporta id, pedido y
     * disponible para depuración clara.
     */
    function requireInStock(Product storage self, uint256 qty) internal view {
        if (self.stock < qty) revert InsufficientStock(self.id, qty, self.stock);
    }

    /**
     * @dev Shared field validation for `add` and `update`.
     *
     * 🇪🇸 NOTA: función `private` de la librería (solo visible aquí, se inlina). Evita
     * duplicar las validaciones en add/update (principio DRY).
     */
    function _validate(string memory name, string memory ipfsCid, uint256 price) private pure {
        if (bytes(name).length == 0) revert EmptyName();
        if (price == 0) revert InvalidPrice();
        uint256 cidLength = bytes(ipfsCid).length;
        if (cidLength == 0) revert EmptyIpfsCid();
        if (cidLength < MIN_CID_LENGTH) revert InvalidIpfsCidLength();
    }
}
