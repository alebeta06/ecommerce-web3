# web-admin (Component 5)

<!-- 🇪🇸 NOTA: Placeholder. App Next.js que se inicializará más adelante. -->

Next.js 15 **merchant back-office**. Register and manage companies, CRUD products (with image
uploads to IPFS), and review invoices and customers. Dark mode + responsive.

## Responsibilities
- Register/manage companies (`CompanyLib`).
- Product CRUD with stock; upload images to **IPFS** and store only the CID on-chain (`ProductLib`).
- List & detail invoices (`InvoiceLib`); list customers with history (`CustomerLib`).
- Custom hooks: `useWallet`, `useContract`, etc.

## Planned structure
```
src/app/            # /companies, /products, /invoices, /customers, dashboard
src/components/      # tables, forms, image uploader, theme toggle
src/hooks/           # useWallet, useContract, useIpfsUpload
src/lib/             # ethers client, pinata/ipfs client
src/types/
.env.example
```

## Key concepts (🇪🇸)
- **IPFS / CID:** almacenamiento direccionado por contenido; on-chain guardamos el hash (CID), no
  los bytes de la imagen (sería carísimo en gas).
- **AccessControl:** el contrato restringe acciones de admin por roles.

See [`../../CLAUDE.md`](../../CLAUDE.md) for env vars and design rationale.
