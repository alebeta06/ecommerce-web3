// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: SPDX = licencia del código (obligatorio o el compilador avisa). MIT = permisiva.
pragma solidity 0.8.28;

/**
 * @title  CartLib
 * @notice Library that owns the on-chain shopping `Cart` entity and the `internal` logic to add,
 *         remove and clear cart items for a buyer of the multi-vendor marketplace.
 * @dev    Stateless by itself: it operates on storage that LIVES IN the `Ecommerce` contract,
 *         received as a `storage` pointer (`self`). Attached via `using CartLib for ...`.
 *
 * 🇪🇸 NOTA — librería PURA (decisión de diseño D1):
 *  - CartLib NO importa ni referencia ProductLib/CompanyLib. Trata `(companyId, productId)` como
 *    IDENTIFICADORES OPACOS: no valida que sean != 0 ni que el producto/empresa existan. Toda la
 *    validación cruzada (producto existe, empresa activa, cliente registrado, stock) vive en el
 *    orquestador `Ecommerce.sol`. Aquí solo se mantiene la INTEGRIDAD de la estructura del carrito.
 *
 * 🇪🇸 NOTA — estructura array + índice (decisión D4):
 *  - `items` es la lista de líneas del carrito (iterable, p.ej. para el checkout).
 *  - `indexPlusOne[key]` mapea cada `(companyId, productId)` a su posición en `items` MÁS UNO.
 *    Guardamos index+1 para que el valor 0 (default del mapping) signifique "ausente": así
 *    distinguimos "está en el índice 0" de "no está", sin un bool extra.
 *  - Mutaciones O(1): alta por push, baja por swap-and-pop (mover el último al hueco y pop).
 */
library CartLib {
    /**
     * @notice A single line of a cart: a product of a company with a desired quantity.
     * @dev    `companyId` + `productId` together identify the catalog product; `quantity` is the
     *         accumulated desired amount (incremented when the same line is added again, D3).
     */
    struct CartItem {
        uint256 companyId;
        uint256 productId;
        uint256 quantity;
    }

    /**
     * @notice A buyer's on-chain cart: the item list plus an index for O(1) lookups/removals.
     * @dev    `items`        = insertion-ordered lines (mutated via swap-and-pop on removal).
     *         `indexPlusOne` = key => (position in `items`) + 1; 0 means the key is absent.
     *
     * 🇪🇸 NOTA: un struct que contiene un `mapping` SOLO puede vivir en `storage`; no se puede
     * devolver en `memory`. Por eso el getter público es `getItems` (devuelve el array), no `Cart`.
     */
    struct Cart {
        CartItem[] items;
        mapping(bytes32 => uint256) indexPlusOne;
    }

    // 🇪🇸 NOTA: Custom errors. `InvalidQuantity` no lleva arg (siempre es por quantity == 0, no hay
    // nada que depurar). `ItemNotInCart` sí transporta el par para contexto al depurar.
    error InvalidQuantity();
    error ItemNotInCart(uint256 companyId, uint256 productId);

    /**
     * @notice Add `quantity` of `(companyId, productId)` to the cart.
     * @param self      Storage reference to the cart.
     * @param companyId Opaque company identifier.
     * @param productId Opaque product identifier.
     * @param quantity  Amount to add (must be > 0).
     *
     * 🇪🇸 NOTA: dos caminos. Si el par YA está, INCREMENTA su quantity (D3) sin tocar el índice
     * (la posición no cambia). Si es NUEVO, primero `push` y luego fija `indexPlusOne = length`
     * (que tras el push es exactamente index+1). Validamos quantity ANTES de tocar storage (fail fast).
     */
    function addItem(Cart storage self, uint256 companyId, uint256 productId, uint256 quantity)
        internal
    {
        if (quantity == 0) revert InvalidQuantity();

        bytes32 key = _key(companyId, productId);
        uint256 idxPlusOne = self.indexPlusOne[key];

        if (idxPlusOne != 0) {
            // 🇪🇸 NOTA: ya presente => acumulamos cantidad; el índice se mantiene intacto.
            self.items[idxPlusOne - 1].quantity += quantity;
        } else {
            // 🇪🇸 NOTA: nuevo => push primero, índice después. length post-push == index+1.
            self.items.push(CartItem(companyId, productId, quantity));
            self.indexPlusOne[key] = self.items.length;
        }
    }

    /**
     * @notice Remove the `(companyId, productId)` line from the cart entirely.
     * @param self      Storage reference to the cart.
     * @param companyId Opaque company identifier.
     * @param productId Opaque product identifier.
     *
     * 🇪🇸 NOTA — swap-and-pop (D4): movemos el ÚLTIMO item al hueco del eliminado, corregimos el
     * índice del item movido, borramos la key del eliminado y hacemos pop del duplicado del final.
     * Así mantenemos el array compacto en O(1) sin desplazar el resto.
     */
    function removeItem(Cart storage self, uint256 companyId, uint256 productId) internal {
        bytes32 key = _key(companyId, productId);
        uint256 idxPlusOne = self.indexPlusOne[key];
        if (idxPlusOne == 0) revert ItemNotInCart(companyId, productId);

        uint256 index = idxPlusOne - 1;
        uint256 lastIndex = self.items.length - 1;

        if (index != lastIndex) {
            // 🇪🇸 NOTA: solo si NO es el último. `movedKey` se calcula ANTES de la copia, desde los
            // campos aún válidos del último (lastIndex no cambia hasta el pop). Keys distintas =>
            // el delete posterior nunca pisa `movedKey`.
            CartItem storage moved = self.items[lastIndex];
            bytes32 movedKey = _key(moved.companyId, moved.productId);
            self.items[index] = moved; // copia storage -> storage
            self.indexPlusOne[movedKey] = index + 1;
        }

        delete self.indexPlusOne[key];
        self.items.pop();
    }

    /**
     * @notice Empty the cart: remove every item and clear the whole index.
     * @param self Storage reference to the cart.
     *
     * 🇪🇸 NOTA — el bug clásico de D4: `delete self.items` resetea el ARRAY pero NO el mapping
     * `indexPlusOne`. Si no borrásemos sus entradas, un `addItem` posterior del mismo par leería
     * un índice OBSOLETO y escribiría fuera de rango (panic 0x32). Por eso iteramos `items` ANTES
     * de borrarlo y limpiamos cada key. Coste O(n) con n acotado por el tamaño del carrito.
     */
    function clear(Cart storage self) internal {
        uint256 n = self.items.length;
        for (uint256 i = 0; i < n; i++) {
            CartItem storage item = self.items[i];
            delete self.indexPlusOne[_key(item.companyId, item.productId)];
        }
        delete self.items;
    }

    /**
     * @notice Return all cart lines as a memory array.
     * @param self Storage reference to the cart.
     * @return The cart items copied to memory.
     *
     * 🇪🇸 NOTA: no podemos devolver `Cart` (contiene un mapping); devolvemos solo `items`.
     */
    function getItems(Cart storage self) internal view returns (CartItem[] memory) {
        return self.items;
    }

    /**
     * @dev Derive the index key for a `(companyId, productId)` pair.
     *
     * 🇪🇸 NOTA: `abi.encode` (no `encodePacked`) => codificación sin ambigüedad de los dos uint256.
     * Función `private pure`: solo visible aquí y se inlina.
     */
    function _key(uint256 companyId, uint256 productId) private pure returns (bytes32) {
        return keccak256(abi.encode(companyId, productId));
    }
}
