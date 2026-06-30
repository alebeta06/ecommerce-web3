# RPC notes — why web-admin uses two RPCs on Sepolia

> Decisión técnica documentada. **web-admin usa DOS RPCs en Sepolia**: **Alchemy** para las llamadas
> normales y **dRPC** (`https://sepolia.drpc.org`) **solo** para el escaneo de logs de eventos. Este
> documento explica el porqué, la cadena de límites del free tier que tuvimos que sortear, y la
> configuración final. Es una guía de referencia: escanear `eth_getLogs` desde el cliente contra RPCs
> de free tier choca con **muchos** límites distintos, y aquí están todos.

---

## El problema de raíz

La pestaña **Customers** descubre clientes leyendo el evento `CustomerRegistered` del contrato
Ecommerce, porque el contrato **no expone** un enumerador (`getAllCustomers`). Productos y companies
sí tienen getters directos — por eso esos paneles funcionan sin tocar logs; Customers no.

Leer eventos históricos = `eth_getLogs`, y cada RPC de free tier lo capa de una forma distinta.

## La cadena de problemas que resolvimos (en orden)

| # | Síntoma | Causa | Fix |
|---|---------|-------|-----|
| 1 | **400** "up to a 10 block range" (Alchemy) | Alchemy free capa `eth_getLogs` a **10 bloques/petición**, *sin excepción por filtros*. `queryFilter` sin from/toBlock escanea `0→latest`. | **Paginar** en ventanas (`paginatedQueryFilter`) desde el deploy block. |
| 2 | **429** "exceeded compute units per second" (Alchemy) | Free = 500 CUPs/s, `eth_getLogs` = 75 CU → ~6 req/s. Lanzar muchas ventanas rápido lo excede. | **Throttle** (lotes de concurrencia limitada + micro-pausa) + **backoff** ante 429. *(Resultó innecesario — ver #3 — pero queda como red de seguridad.)* |
| 3 | (corrección de cálculo) | Asumimos ~890.000 bloques desde el deploy → ~89k peticiones → "~5 horas". **Falso.** | Verificado empíricamente: `latest`≈11.175.232, deploy=11.146.508 → **span real ~28.700 bloques ≈ ~4 peticiones**. El volumen nunca fue el problema; el throttle es casi irrelevante aquí. |
| 4 | **-32602** "Archive requests require a personal token" (PublicNode) | El deploy es histórico (no en los últimos bloques). PublicNode free **bloquea archive** sin token. | **Cambiar de RPC** a uno que sirva archive sin key. |
| 5 | **code 35** "ranges over 10000 blocks are not supported on freetier" (dRPC) | dRPC free capa `eth_getLogs` a **<10.000 bloques** por petición. | Ventana **9000** (el helper usa `span = windowSize−1 = 8999`, verificado OK; 9999 falla). |
| 6 | **"Batch of more than 3 requests"** (dRPC) | ethers v6 agrupa varias llamadas en un único HTTP request (JSON-RPC batch, `batchMaxCount` default **100**). dRPC free rechaza batches **>3**. Limitar la concurrencia del helper NO lo arregla: el batching ocurre por debajo, en el provider. | **`batchMaxCount: 1`** en el provider de logs → cada petición en su propio HTTP request. |

> 🇪🇸 Lección de #2 y #3: medir antes de optimizar. El throttle se diseñó contra un número (~890k
> bloques) que resultó ~30× inflado. No hizo daño (y protege ante 429 esporádicos), pero el cuello de
> botella real nunca fue el volumen, sino el *gating* por petición (archive, rango, batch).

## Por qué dRPC (y no otros) — verificado empíricamente

Probamos `eth_getLogs` sobre el rango histórico real (curl, sin asumir):

| Endpoint | Key | Archive histórico | Veredicto |
|----------|-----|-------------------|-----------|
| **`https://sepolia.drpc.org`** (dRPC) | no | ✅ devolvió los logs reales | ✅ **elegido** (cap de rango <10k → ventana 9000) |
| `https://rpc.ankr.com/eth_sepolia` | **sí** | — | ❌ ahora exige API key |
| `https://1rpc.io/sepolia` | no | — | ❌ cap de **50 bloques** por request |
| `https://rpc.sepolia.org` | no | — | ❌ muerto (404) |
| `https://ethereum-sepolia-rpc.publicnode.com` | no | ❌ | ❌ archive token requerido (problema #4) |

## La solución final: dos RPCs + paginación + sin batching

- **Llamadas normales** (`getCustomer`, `getAllProducts`, escrituras vía MetaMask) → **Alchemy**
  (`NEXT_PUBLIC_RPC_URL`). Son `eth_call`, no `eth_getLogs`: fiable y sin estos límites. **Conserva su
  batching** (ahí es beneficioso).
- **Escaneo de logs** (`queryFilter` de `CustomerRegistered`) → **dRPC** (`NEXT_PUBLIC_LOGS_RPC_URL`),
  **sin API key**, con `batchMaxCount: 1`.

Resultado: ~28.700 / 9000 ≈ **~4 peticiones** → Customers carga en **~1–2 s**, sin 400/429/archive/batch.

### Detalles de implementación

- **`apps/web-admin/src/hooks/useEcommerce.ts`** — `logsRead` es un Contract sobre `logsRpcUrl`,
  construido con `new JsonRpcProvider(url, undefined, { batchMaxCount: 1 })` (ethers v6: el 3er arg es
  `JsonRpcApiProviderOptions`; todos sus campos son opcionales). Si `logsRpcUrl === rpcUrl` (Anvil),
  reutiliza `read` sin crear un segundo provider. **Solo `logsRead`** lleva `batchMaxCount:1`; `read`
  (Alchemy) mantiene su batching por defecto.
- **`apps/web-admin/src/lib/paginatedQueryFilter.ts`** — trocea `[deployBlock, latest]` en ventanas de
  `windowSize`, en **lotes de `concurrency`** con micro-pausa, y **reintenta con backoff** (500ms→8s, 5
  intentos) **solo** ante 429/rate-limit; ante error de rango (config) **falla rápido**.

## Configuración por entorno

| Entorno | `NEXT_PUBLIC_RPC_URL` | `NEXT_PUBLIC_LOGS_RPC_URL` | `NEXT_PUBLIC_LOG_WINDOW_SIZE` | `NEXT_PUBLIC_LOG_CONCURRENCY` | `NEXT_PUBLIC_DEPLOY_BLOCK` |
|---------|------------------------|-----------------------------|------------------------------|------------------------------|----------------------------|
| **Anvil (local)** | `http://localhost:8545` | *(vacío → cae a RPC_URL)* | `10` (default; pocos bloques) | `4` (default) | `0` |
| **Sepolia (Vercel)** | Alchemy Sepolia | `https://sepolia.drpc.org` | `9000` | `4` (indiferente con batchMaxCount:1) | `11146508` |

> **Anvil queda idéntico:** sin `NEXT_PUBLIC_LOGS_RPC_URL`, `logsRead === read` (mismo nodo local, con
> batching, que Anvil maneja sin problema). `batchMaxCount:1`, el throttle y los reintentos solo cambian
> el transporte/ritmo HTTP, **nunca los datos**. Mismos clientes mostrados.

## Limitación de fondo y solución de producción

Escanear `eth_getLogs` desde el cliente contra un RPC de free tier **no escala y es frágil**: como
muestra la tabla de #1–#6, cada provider impone límites distintos (rango, throughput, archive, batch)
y pueden cambiar sin aviso. Para este demo —contrato recién desplegado, pocos clientes— es suficiente
y didáctico. La solución **de producción** sería una de estas, en orden de robustez:

1. **Getter on-chain** `getAllCustomers()` en el contrato (como ya tienen products/companies → por eso
   esos paneles nunca tuvieron este problema). Elimina los logs por completo. Requiere
   redeploy+verify+reseed.
2. **Indexer** (p.ej. The Graph): indexa los eventos off-chain y los sirve por GraphQL, sin tocar RPC.
3. **RPC de pago** (Alchemy PAYG): rango "unlimited" en Ethereum, sin estos caps.
