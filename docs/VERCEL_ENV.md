# Vercel env configuration guide — Sepolia deployment

> Guía de variables de entorno para desplegar las **4 apps Next.js** en Vercel desde la rama
> `testnet`, cada una como **proyecto Vercel independiente** con su propio **Root Directory**.
> Esta guía NO despliega nada: solo lista, por app, qué variables setear y con qué valor en Sepolia.
>
> <!-- 🇪🇸 NOTA: los nombres de variable de abajo se leyeron directamente de cada
> `apps/<app>/.env.example` — no están inventados. Ojo a la inconsistencia real del repo:
> `compra-stablecoin` usa `NEXT_PUBLIC_EUROTOKEN_ADDRESS` (sin guion bajo), mientras que las otras
> 3 apps usan `NEXT_PUBLIC_EURO_TOKEN_ADDRESS` (con guion bajo). Está reflejado por app. -->

---

## Valores comunes de Sepolia

Estos valores se repiten en varias apps. Donde aplique, úsalos tal cual.

| Concepto                     | Valor                                                                 |
|------------------------------|-----------------------------------------------------------------------|
| `NEXT_PUBLIC_CHAIN_ID`       | `11155111`                                                            |
| `NEXT_PUBLIC_NETWORK_NAME`   | `Ethereum Sepolia`                                                    |
| `NEXT_PUBLIC_RPC_URL`        | **(la pones tú)** URL de Alchemy Sepolia — `https://eth-sepolia.g.alchemy.com/v2/<API_KEY>` |
| EuroToken address            | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3`                          |
| Ecommerce address            | `0xf8db42Bd1c711b60a810a0790Af4eB5219df2764`                         |
| `NEXT_PUBLIC_IPFS_GATEWAY`   | `https://gateway.pinata.cloud/ipfs/`                                  |

> 🔑 **Secretos** (los valores los pones tú, **nunca** se commitean): `STRIPE_SECRET_KEY`,
> `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `WALLET_PRIVATE_KEY` (= clave de **Alebeta Admin**,
> owner del EuroToken), `PINATA_JWT`.
> Aunque `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` lleva prefijo público (va al navegador), es una
> credencial de Stripe: trátala como dato que pegas tú, no un valor genérico.

> 🐔🥚 **URLs cruzadas** (`NEXT_PUBLIC_PAYMENT_GATEWAY_URL`, `NEXT_PUBLIC_BUY_TOKENS_URL`): son el
> problema huevo-gallina. No las conoces hasta que la app destino está desplegada en Vercel. Estrategia:
> despliega primero la app sin dependencias (payment-gateway), copia su URL pública de Vercel, y
> rellena estas variables en las apps que la consumen; luego redeploy de esas apps para que tomen
> el valor (las `NEXT_PUBLIC_*` se inyectan **en build time**, así que un cambio exige rebuild).

---

## 1. compra-stablecoin

- **Root Directory en Vercel:** `apps/compra-stablecoin`
- **Fuente:** `apps/compra-stablecoin/.env.example`

| Variable                              | Tipo            | Valor en Sepolia |
|---------------------------------------|-----------------|------------------|
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`  | público (Stripe)| 🔑 la pones tú (`pk_live_…` o `pk_test_…`) |
| `NEXT_PUBLIC_EUROTOKEN_ADDRESS` ⚠️    | público         | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3` |
| `NEXT_PUBLIC_RPC_URL`                 | público         | 🔧 Alchemy Sepolia (la pones tú) |
| `NEXT_PUBLIC_CHAIN_ID`                | público         | `11155111` |
| `NEXT_PUBLIC_PAYMENT_GATEWAY_URL`     | público         | 🐔🥚 rellenar con la URL pública de Vercel de **payment-gateway** tras desplegarla |
| `NEXT_PUBLIC_NETWORK_NAME`            | público         | `Ethereum Sepolia` |
| `STRIPE_SECRET_KEY`                   | **secret (server)** | 🔑 la pones tú (`sk_live_…` o `sk_test_…`) |
| `WALLET_PRIVATE_KEY`                  | **secret (server)** | 🔑 clave privada de **Alebeta Admin** (owner del EuroToken, única que puede `mint()`) |
| `RPC_URL`                             | **server-side** | 🔧 Alchemy Sepolia (la pones tú) — provider de ethers en la API route del mint |

> ⚠️ Esta app usa `NEXT_PUBLIC_EUROTOKEN_ADDRESS` **sin guion bajo** (única que lo hace).
> `RPC_URL` (server-side, sin prefijo) puede llevar el **mismo** valor de Alchemy que
> `NEXT_PUBLIC_RPC_URL`, pero son dos variables distintas: hay que setear ambas.

---

## 2. payment-gateway

- **Root Directory en Vercel:** `apps/payment-gateway`
- **Fuente:** `apps/payment-gateway/.env.example`
- **Sin secretos server-side ni IPFS** — todas son `NEXT_PUBLIC_*` (solo lecturas/escrituras on-chain vía MetaMask).

| Variable                          | Tipo     | Valor en Sepolia |
|-----------------------------------|----------|------------------|
| `NEXT_PUBLIC_RPC_URL`             | público  | 🔧 Alchemy Sepolia (la pones tú) |
| `NEXT_PUBLIC_CHAIN_ID`            | público  | `11155111` |
| `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | público  | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3` |
| `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | público  | `0xf8db42Bd1c711b60a810a0790Af4eB5219df2764` |
| `NEXT_PUBLIC_NETWORK_NAME`        | público  | `Ethereum Sepolia` |

> ✅ Esta app **no depende de la URL de ninguna otra** → despliégala **primero** para romper el
> huevo-gallina de las URLs cruzadas.

---

## 3. web-admin

- **Root Directory en Vercel:** `apps/web-admin`
- **Fuente:** `apps/web-admin/.env.example`

| Variable                          | Tipo                 | Valor en Sepolia |
|-----------------------------------|----------------------|------------------|
| `NEXT_PUBLIC_RPC_URL`             | público              | 🔧 Alchemy Sepolia (la pones tú) |
| `NEXT_PUBLIC_CHAIN_ID`            | público              | `11155111` |
| `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | público              | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3` |
| `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | público              | `0xf8db42Bd1c711b60a810a0790Af4eB5219df2764` |
| `PINATA_JWT`                      | **secret (server)**  | 🔑 la pones tú (JWT de Pinata para subir imágenes a IPFS) |
| `NEXT_PUBLIC_IPFS_GATEWAY`        | público              | `https://gateway.pinata.cloud/ipfs/` |
| `NEXT_PUBLIC_NETWORK_NAME`        | público              | `Ethereum Sepolia` |

> ✅ No depende de la URL de ninguna otra app.

---

## 4. web-customer

- **Root Directory en Vercel:** `apps/web-customer`
- **Fuente:** `apps/web-customer/.env.example`
- **Sin secretos server-side** — todas son `NEXT_PUBLIC_*`.

| Variable                          | Tipo     | Valor en Sepolia |
|-----------------------------------|----------|------------------|
| `NEXT_PUBLIC_RPC_URL`             | público  | 🔧 Alchemy Sepolia (la pones tú) |
| `NEXT_PUBLIC_CHAIN_ID`            | público  | `11155111` |
| `NEXT_PUBLIC_EURO_TOKEN_ADDRESS`  | público  | `0x6d3b3054140fc52AEb63f7fb2467177f1AeDbec3` |
| `NEXT_PUBLIC_ECOMMERCE_ADDRESS`   | público  | `0xf8db42Bd1c711b60a810a0790Af4eB5219df2764` |
| `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` | público  | 🐔🥚 rellenar con la URL pública de Vercel de **payment-gateway** tras desplegarla (fail-fast: la app no arranca si falta) |
| `NEXT_PUBLIC_IPFS_GATEWAY`        | público  | `https://gateway.pinata.cloud/ipfs/` |
| `NEXT_PUBLIC_NETWORK_NAME`        | público  | `Ethereum Sepolia` |
| `NEXT_PUBLIC_BUY_TOKENS_URL`      | público  | 🐔🥚 rellenar con la URL pública de Vercel de **compra-stablecoin** tras desplegarla (fail-fast: la app no arranca si falta) |

---

## Grafo de dependencias cruzadas (qué app necesita la URL de cuál)

| App (consumidora) | Variable                          | App destino (provee la URL) |
|-------------------|-----------------------------------|-----------------------------|
| compra-stablecoin | `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` | payment-gateway             |
| web-customer      | `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` | payment-gateway             |
| web-customer      | `NEXT_PUBLIC_BUY_TOKENS_URL`      | compra-stablecoin           |
| payment-gateway   | —                                 | (no depende de nadie)       |
| web-admin         | —                                 | (no depende de nadie)       |

**Orden de despliegue sugerido** (para minimizar redeploys por el huevo-gallina):

1. **payment-gateway** — no depende de nadie. Anota su URL pública de Vercel.
2. **compra-stablecoin** — rellena `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` con la URL del paso 1. Anota su URL.
3. **web-customer** — rellena `NEXT_PUBLIC_PAYMENT_GATEWAY_URL` (paso 1) y `NEXT_PUBLIC_BUY_TOKENS_URL` (paso 2).
4. **web-admin** — independiente; puede desplegarse en cualquier momento.

> 🔁 Recuerda: las `NEXT_PUBLIC_*` se hornean en **build time**. Si cambias una URL cruzada después,
> Vercel necesita un **redeploy** de esa app para que el nuevo valor llegue al bundle del cliente.

---

## Nota sobre el monorepo (pnpm + Turborepo)

Cada proyecto Vercel apunta a `apps/<app>` como **Root Directory**, pero las dependencias viven en
el **workspace root** (pnpm symlinkea desde `node_modules` raíz). Si el build de Vercel falla por
dependencias no resueltas (módulos del workspace, paquetes no instalados):

- Vercel suele autodetectar pnpm por el `pnpm-lock.yaml` de la raíz. Verifica que el
  **Install Command** instale desde la **raíz del repo**, no solo dentro de `apps/<app>`
  (p. ej. `pnpm install` ejecutado en la raíz del workspace, o
  `pnpm install --frozen-lockfile`).
- Asegúrate de que Vercel detecta la raíz del monorepo (presencia de `pnpm-workspace.yaml` +
  `pnpm-lock.yaml`). El **Root Directory** apunta a la app, pero la instalación de deps debe ver el
  workspace completo.
- Si persiste, fija la versión de pnpm (campo `packageManager` en el `package.json` raíz o
  `ENABLE_EXPERIMENTAL_COREPACK=1` en las env vars de Vercel) para que el builder use la misma
  versión que en local.
- El **Build Command** por defecto de Next (`next build`, o `pnpm build` vía Turborepo) funciona
  siempre que la instalación desde la raíz haya enlazado bien las deps del workspace.
