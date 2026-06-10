// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: SPDX = licencia del código (obligatorio o el compilador avisa). MIT = permisiva.
pragma solidity 0.8.28;

/**
 * @title  CustomerLib
 * @notice Library that owns the `Customer` entity type and the `internal` logic to register,
 *         read and rename the customers (the buyers of the multi-vendor marketplace).
 * @dev    Stateless by itself: it operates on storage that LIVES IN the `Ecommerce` contract,
 *         received as a `storage` pointer (`self`). Attached via `using CustomerLib for ...`.
 *
 * 🇪🇸 NOTA — mismo patrón que CompanyLib/ProductLib (library internal + using-for):
 *  - La `library` no tiene estado propio. El contrato `Ecommerce` posee el mapping
 *    `address => Customer`; aquí solo validamos y mutamos ese storage vía el puntero `self`.
 *  - A diferencia de Company (clave `uint256 id` asignada por un contador), el cliente se
 *    indexa por su PROPIA wallet: la dirección ES su identidad. El struct guarda igualmente
 *    `wallet` en su interior (espejo de `Company.id`) para que `getCustomer` devuelva un struct
 *    autocontenido que ya incluye su clave.
 *  - El bool `registered` hace de CENTINELA de existencia (equivalente al `exists` de Company):
 *    un struct a cero (cliente desconocido) tiene `registered == false`.
 */
library CustomerLib {
    /**
     * @notice A buyer registered on the platform.
     * @dev    `wallet`     = the customer's address; it is also the mapping key (stored inside
     *                        the struct for self-contained reads, mirroring `Company.id`).
     *         `name`       = human-readable display name (must be non-empty).
     *         `registered` = existence sentinel (false on the zero-default struct of an unknown
     *                        wallet; true once registered).
     *         `createdAt`  = block timestamp of registration (audit / ordering off-chain).
     *
     * 🇪🇸 NOTA: no añadimos flag `active` (decisión de diseño): el alta es permanente; no
     * modelamos baja lógica de clientes en este módulo.
     */
    struct Customer {
        address wallet;
        string name;
        bool registered;
        uint256 createdAt;
    }

    // 🇪🇸 NOTA: Custom errors (no strings). Más baratos en gas y, con argumentos, dan contexto de
    // depuración. Sin prefijo cuando son genéricos (EmptyName/InvalidWallet, estilo CompanyLib);
    // con prefijo `Customer*` cuando el contexto de la entidad ayuda a leer el revert.
    error EmptyName();
    error InvalidWallet();
    error CustomerAlreadyRegistered(address wallet);
    error CustomerNotFound(address wallet);

    /**
     * @notice Emitted when a new customer is registered, for off-chain indexing.
     * @param wallet    The registered customer's address (indexed for filtering).
     * @param name      Human-readable customer name.
     * @param createdAt Block timestamp captured at registration.
     *
     * 🇪🇸 NOTA: el evento se DECLARA y se EMITE dentro de la librería. Como las funciones
     * `internal` se inlinan, el log sale como si lo emitiera el propio contrato `Ecommerce`.
     */
    event CustomerRegistered(address indexed wallet, string name, uint256 createdAt);

    /**
     * @notice Emitted when a customer's display name is updated.
     * @param wallet  The customer's address (indexed for filtering).
     * @param newName The new display name.
     *
     * 🇪🇸 NOTA: simetría con `ProductUpdated`: los `update*` de las librerías emiten su evento.
     */
    event CustomerUpdated(address indexed wallet, string newName);

    /**
     * @notice Validate and write a new customer into the contract's storage.
     * @param self   Storage pointer to the `wallet => Customer` mapping (lives in Ecommerce).
     * @param wallet The customer's address (must be non-zero; becomes the mapping key).
     * @param name   Display name (must be non-empty).
     * @return customer Storage reference to the stored customer.
     *
     * 🇪🇸 NOTA: validamos en el BORDE del sistema. Comprobamos `registered` para impedir un
     * RE-registro que pisaría `createdAt` (el alta es idempotente: re-registrar es un error).
     */
    function register(mapping(address => Customer) storage self, address wallet, string memory name)
        internal
        returns (Customer storage customer)
    {
        if (wallet == address(0)) revert InvalidWallet();
        if (bytes(name).length == 0) revert EmptyName();

        customer = self[wallet];
        if (customer.registered) revert CustomerAlreadyRegistered(wallet);

        customer.wallet = wallet;
        customer.name = name;
        customer.registered = true;
        customer.createdAt = block.timestamp;

        emit CustomerRegistered(wallet, name, block.timestamp);
    }

    /**
     * @notice Read a customer by wallet, reverting if not registered.
     * @param self   Storage pointer to the `wallet => Customer` mapping.
     * @param wallet The customer's address to read.
     * @return customer Storage reference to the existing customer.
     *
     * 🇪🇸 NOTA: revertimos con el `wallet` consultado (no con `customer.wallet`) para reportar
     * exactamente lo pedido aunque la entrada no exista (struct a cero, wallet interna == 0).
     */
    function get(mapping(address => Customer) storage self, address wallet)
        internal
        view
        returns (Customer storage customer)
    {
        customer = self[wallet];
        if (!customer.registered) revert CustomerNotFound(wallet);
    }

    /**
     * @notice Validate existence and overwrite a customer's display name.
     * @param self    Storage pointer to the `wallet => Customer` mapping.
     * @param wallet  The customer's address (must be registered).
     * @param newName The new display name (must be non-empty).
     *
     * 🇪🇸 NOTA: reutilizamos `get` para la comprobación de existencia (revierte
     * CustomerNotFound si no está registrado) antes de validar el nombre. DRY: una sola fuente
     * de verdad para "¿existe este cliente?".
     */
    function updateName(
        mapping(address => Customer) storage self,
        address wallet,
        string memory newName
    ) internal {
        Customer storage customer = get(self, wallet);
        if (bytes(newName).length == 0) revert EmptyName();

        customer.name = newName;

        emit CustomerUpdated(wallet, newName);
    }
}
