// SPDX-License-Identifier: MIT
// 🇪🇸 NOTA: SPDX = licencia del código (obligatorio o el compilador avisa). MIT = permisiva.
pragma solidity 0.8.28;

/**
 * @title  CompanyLib
 * @notice Library that owns the `Company` entity type and the `internal` logic to register,
 *         read and validate companies (the sellers of the multi-vendor marketplace).
 * @dev    Stateless by itself: it operates on storage that LIVES IN the `Ecommerce` contract,
 *         received as a `storage` pointer (`self`). Attached via `using CompanyLib for ...`.
 *
 * 🇪🇸 NOTA — patrón "library internal + using-for":
 *  - Una `library` con funciones `internal` NO tiene estado propio. El contrato `Ecommerce`
 *    es el dueño de TODO el storage (los mappings). Cada función recibe un PUNTERO a ese
 *    storage como primer parámetro `self`: leer/escribir `self` modifica el storage del
 *    contrato directamente (no es una copia).
 *  - `internal` => el compilador INLINEA el código dentro del contrato (no hay delegatecall).
 *    Organiza el código y habilita `using-for`, pero NO reduce el bytecode.
 */
library CompanyLib {
    /**
     * @notice A seller registered on the platform.
     * @dev    `owner`       = address that MANAGES the company (adds/updates products).
     *         `payoutWallet` = address that RECEIVES the EURT payments. May equal `owner`.
     *         `exists`      = sentinel to distinguish a real company from the zero-default
     *                         struct returned by a mapping for an unknown id.
     *
     * 🇪🇸 NOTA: separamos `owner` (rol operativo, p.ej. hot wallet del día a día) de
     * `payoutWallet` (rol financiero, p.ej. cold wallet o multisig). Pueden coincidir.
     */
    struct Company {
        uint256 id;
        address owner;
        string name;
        address payoutWallet;
        bool exists;
    }

    // 🇪🇸 NOTA: Custom errors (no strings). Más baratos en gas y, con argumentos, dan
    // contexto de depuración. Estándar en OpenZeppelin v5 y coherente con EuroToken.
    error EmptyName();
    error InvalidOwner();
    error InvalidPayoutWallet();
    error CompanyNotFound(uint256 id);

    /**
     * @notice Emitted when a new company is registered, for off-chain indexing.
     * @param id           The freshly assigned company id.
     * @param owner        Address that manages the company (indexed for filtering).
     * @param name         Human-readable company name.
     * @param payoutWallet Address that will receive EURT payments.
     *
     * 🇪🇸 NOTA: el evento se DECLARA y se EMITE dentro de la librería. Como las funciones
     * `internal` se inlinan, el log sale como si lo emitiera el propio contrato `Ecommerce`.
     */
    event CompanyRegistered(
        uint256 indexed id, address indexed owner, string name, address payoutWallet
    );

    /**
     * @notice Validate and write a new company into the contract's storage.
     * @param self         Storage pointer to the `id => Company` mapping (lives in Ecommerce).
     * @param id           Pre-computed id assigned by the contract (its counter).
     * @param owner        Managing address (must be non-zero).
     * @param name         Company name (must be non-empty).
     * @param payoutWallet Payout address (must be non-zero; may equal `owner`).
     * @return company     Storage reference to the stored company.
     *
     * 🇪🇸 NOTA: validamos en el BORDE del sistema (entrada de datos). `bytes(name).length`
     * es la forma canónica de medir un string en Solidity (no hay `string.length`).
     */
    function register(
        mapping(uint256 => Company) storage self,
        uint256 id,
        address owner,
        string memory name,
        address payoutWallet
    ) internal returns (Company storage company) {
        if (owner == address(0)) revert InvalidOwner();
        if (payoutWallet == address(0)) revert InvalidPayoutWallet();
        if (bytes(name).length == 0) revert EmptyName();

        company = self[id];
        company.id = id;
        company.owner = owner;
        company.name = name;
        company.payoutWallet = payoutWallet;
        company.exists = true;

        emit CompanyRegistered(id, owner, name, payoutWallet);
    }

    /**
     * @notice Read a company by id, reverting if it does not exist.
     * @param self Storage pointer to the `id => Company` mapping.
     * @param id   Company id to read.
     * @return company Storage reference to the existing company.
     *
     * 🇪🇸 NOTA: comprobamos con el `id` consultado (no con `company.id`) para que el error
     * reporte exactamente lo que se pidió, aunque la entrada no exista (struct a cero).
     */
    function get(mapping(uint256 => Company) storage self, uint256 id)
        internal
        view
        returns (Company storage company)
    {
        company = self[id];
        if (!company.exists) revert CompanyNotFound(id);
    }

    /**
     * @notice Revert unless the given company exists.
     * @param self Storage reference to a company.
     *
     * 🇪🇸 NOTA: helper para el caso en que YA tenemos el puntero (p.ej. en un modifier).
     * Se adjunta con `using CompanyLib for CompanyLib.Company;` y se llama `company.requireExists()`.
     */
    function requireExists(Company storage self) internal view {
        if (!self.exists) revert CompanyNotFound(self.id);
    }
}
