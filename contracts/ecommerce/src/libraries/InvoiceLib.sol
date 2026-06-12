// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  InvoiceLib
 * @notice Library that owns the `Invoice` entity and the `internal` logic to create and read
 *         per-company invoices generated at checkout in the multi-vendor marketplace.
 * @dev    Stateless by itself: it operates on a `Storage` struct that LIVES IN the `Ecommerce`
 *         contract, received as a `storage` pointer (`self`). Attached via `using InvoiceLib for ...`.
 *
 * 🇪🇸 NOTA — modelo multi-vendor (1 factura por empresa):
 *  - `checkout` agrupa el carrito por empresa y llama `create` una vez por empresa presente. Cada
 *    `Invoice` lista SOLO los productos de esa empresa y su `total` se cobra a su `payoutWallet`.
 *
 * 🇪🇸 NOTA — pago en DOS FASES (`isPaid`):
 *  - Fase 1 (`checkout`): la factura nace IMPAGA (`isPaid=false`) con `unitPrice` congelado al precio
 *    del momento. NO se cobra EURT ni se toca stock todavía.
 *  - Fase 2 (`processPayment`, la pasarela): `markPaid` voltea `isPaid` a `true`; el orquestador
 *    `Ecommerce` cobra EURT y decrementa stock. Una factura ya pagada no puede re-pagarse
 *    (`InvoiceAlreadyPaid`).
 *
 * 🇪🇸 NOTA — `total` como fuente única de verdad:
 *  - `create` COMPUTA `total = Σ(unitPrice * quantity)` a partir de las líneas y lo almacena; nadie
 *    lo pasa desde fuera. Así el invariante `total == suma de líneas` vive aquí y el pago lee el
 *    importe a cobrar de la propia factura.
 */
library InvoiceLib {
    /**
     * @notice A single billed line: a product, its quantity and the unit price at purchase time.
     * @dev    `unitPrice` is a SNAPSHOT of `product.price` taken at checkout; later price changes
     *         must not alter an already-issued invoice.
     */
    struct InvoiceLine {
        uint256 productId;
        uint256 quantity;
        uint256 unitPrice;
    }

    /**
     * @notice An issued invoice: one customer, one company, its billed lines, the total and whether
     *         it has already been paid.
     * @dev    `id` is sequential (1..). `isPaid` is created `false` at checkout (phase 1) and flipped
     *         to `true` in phase-2 `processPayment`. `createdAt` is the block timestamp at creation.
     *
     * 🇪🇸 NOTA: un struct con un array dinámico SÍ puede devolverse en `memory` (a diferencia de uno
     * con `mapping`). Por eso `get` puede exponer la `Invoice` completa hacia el exterior.
     */
    struct Invoice {
        uint256 id;
        address customer;
        uint256 companyId;
        InvoiceLine[] lines;
        uint256 total;
        uint256 createdAt;
        bool isPaid;
    }

    /**
     * @notice Storage root for all invoices plus the reverse indexes and the id counter.
     * @dev    `invoices`         = id => Invoice.
     *         `customerInvoices` = customer => issued invoice ids (history for the buyer).
     *         `companyInvoices`  = companyId => issued invoice ids (each seller sees only its own).
     *         `invoiceCount`     = number of invoices issued so far; also the last assigned id.
     *
     * 🇪🇸 NOTA — `invoiceCount` arranca en 0 (default) y `create` usa PRE-incremento
     * `++invoiceCount`, así que la primera factura recibe el id 1 y el 0 queda como centinela
     * "no existe" (lo usa `get`). Es el MISMO patrón que `companyCount`/`productCount` en
     * `Ecommerce`: no requiere inicialización en el constructor.
     */
    struct Storage {
        mapping(uint256 => Invoice) invoices;
        mapping(address => uint256[]) customerInvoices;
        mapping(uint256 => uint256[]) companyInvoices;
        uint256 invoiceCount;
    }

    /**
     * @notice Emitted when an invoice is issued.
     * @dev    `id`, `customer` and `companyId` are indexed for off-chain filtering; `total` is data.
     */
    event InvoiceCreated(
        uint256 indexed id, address indexed customer, uint256 indexed companyId, uint256 total
    );

    // 🇪🇸 NOTA: transporta el `id` consultado para depurar lecturas inválidas.
    error InvoiceNotFound(uint256 id);
    // 🇪🇸 NOTA: una factura solo se paga una vez; el segundo intento revierte con su `id`.
    error InvoiceAlreadyPaid(uint256 id);

    /**
     * @notice Create one invoice for `customer`/`companyId` from its billed lines.
     * @param self      Storage reference to the invoice root.
     * @param customer  The buyer the invoice belongs to.
     * @param companyId The selling company the invoice is billed to.
     * @param lines     The billed lines (product, quantity, unit-price snapshot).
     * @return id       The newly assigned invoice id (starts at 1).
     *
     * 🇪🇸 NOTA: copiamos las líneas `memory` a `storage` con un `push` por línea (no se puede asignar
     * un array `memory` a uno `storage` de structs en bloque) y acumulamos `total` en la misma
     * pasada (un solo recorrido). Luego registramos el id en los índices inverso de cliente y empresa.
     * El bucle está acotado por el número de líneas de la empresa en el carrito.
     */
    function create(
        Storage storage self,
        address customer,
        uint256 companyId,
        InvoiceLine[] memory lines
    ) internal returns (uint256 id) {
        id = ++self.invoiceCount;

        Invoice storage invoice = self.invoices[id];
        invoice.id = id;
        invoice.customer = customer;
        invoice.companyId = companyId;
        invoice.createdAt = block.timestamp;

        uint256 total;
        uint256 n = lines.length;
        for (uint256 i = 0; i < n; i++) {
            invoice.lines.push(lines[i]);
            total += lines[i].unitPrice * lines[i].quantity;
        }
        invoice.total = total;

        self.customerInvoices[customer].push(id);
        self.companyInvoices[companyId].push(id);

        emit InvoiceCreated(id, customer, companyId, total);
    }

    /**
     * @notice Mark invoice `id` as paid (phase-2 settlement). Reverts `InvoiceNotFound` if it does
     *         not exist or `InvoiceAlreadyPaid` if it was already settled.
     * @param self Storage reference to the invoice root.
     * @param id   The invoice id being settled.
     *
     * 🇪🇸 NOTA: SOLO voltea el flag `isPaid`. Reusa `get` (que revierte `InvoiceNotFound` si el id no
     * existe), así no duplicamos la comprobación de existencia. El cobro de EURT y el descuento de
     * stock los orquesta `Ecommerce.processPayment`: la lib NO llama a otras libs (ProductLib/
     * PaymentLib) por diseño (las libs no se llaman entre sí; coordina el contrato).
     */
    function markPaid(Storage storage self, uint256 id) internal {
        Invoice storage invoice = get(self, id);
        if (invoice.isPaid) revert InvoiceAlreadyPaid(id);
        invoice.isPaid = true;
    }

    /**
     * @notice Read an invoice by id. Reverts `InvoiceNotFound` if it does not exist.
     * @param self Storage reference to the invoice root.
     * @param id   The invoice id.
     * @return invoice Storage reference to the stored invoice.
     *
     * 🇪🇸 NOTA: existencia por rango del contador (ids secuenciales 1..invoiceCount, nunca se
     * borran), igual que productos. `id == 0` y `id > invoiceCount` son inexistentes.
     */
    function get(Storage storage self, uint256 id) internal view returns (Invoice storage invoice) {
        if (id == 0 || id > self.invoiceCount) revert InvoiceNotFound(id);
        invoice = self.invoices[id];
    }

    /**
     * @notice Return the invoice ids issued to `customer` (purchase history).
     * @param self     Storage reference to the invoice root.
     * @param customer The buyer.
     * @return The customer's invoice ids copied to memory.
     */
    function customerInvoiceIds(Storage storage self, address customer)
        internal
        view
        returns (uint256[] memory)
    {
        return self.customerInvoices[customer];
    }

    /**
     * @notice Return the invoice ids billed to `companyId` (seller's own invoices).
     * @param self      Storage reference to the invoice root.
     * @param companyId The selling company.
     * @return The company's invoice ids copied to memory.
     */
    function companyInvoiceIds(Storage storage self, uint256 companyId)
        internal
        view
        returns (uint256[] memory)
    {
        return self.companyInvoices[companyId];
    }
}
