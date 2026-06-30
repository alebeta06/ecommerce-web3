# RPC notes — why web-admin uses two RPCs on Sepolia

> Decisión técnica documentada. **web-admin usa DOS RPCs en Sepolia**: Alchemy para las llamadas
> normales y un RPC público (PublicNode) **solo** para el escaneo de logs de eventos. Este documento
> explica el porqué, el problema que resuelve y cómo configurarlo.

---

## El problema

La pestaña **Customers** descubre clientes leyendo el evento `CustomerRegistered` del contrato
Ecommerce, porque el contrato **no expone** un enumerador (`getAllCustomers`). Productos y companies
sí tienen getters directos — por eso esos paneles funcionan sin tocar logs; Customers no.

Leer eventos históricos = `eth_getLogs`. Y ahí chocan **dos límites del free tier de Alchemy**:

1. **Rango de bloques.** El free tier capa `eth_getLogs` a **10 bloques por petición**, *regardless
   of filtering parameters* (confirmado en los docs de Alchemy — no hay excepción por filtrar por
   address/topic). Pedir `0 → latest` devuelve **error 400** ("up to a 10 block range… Upgrade to PAYG").
2. **Throughput.** Free tier = **500 CUPs/s**; `eth_getLogs` cuesta **75 CU** → **~6 peticiones/s**
   como techo. Disparar muchas ventanas rápido devuelve **error 429** ("exceeded compute units per
   second capacity").

El contrato se desplegó en el bloque **11146508**. Desde ahí hasta `latest` hay **~890.000 bloques**
(~4 meses de Sepolia). Con la ventana clavada en 10 por el cap → **~89.000 peticiones**. Aun
throttleando a ~5/s, eso es **~5 horas**: **inviable** escanear logs desde el cliente en Alchemy free.

## Por qué NO otras vías (decisiones descartadas)

| Vía | Por qué se descartó |
|-----|---------------------|
| Subir la ventana en Alchemy | El cap de 10 bloques es **hard, sin excepción por filtros** → reintroduce el 400. |
| Alchemy PAYG (rango "unlimited") | Es la solución "real", pero **de pago**. Descartada por ahora. |
| `getAllCustomers()` en el contrato | El fix de raíz (como products/companies), pero exige **redeploy + verify + re-seed** en Sepolia. Más adelante. |
| Caché incremental (localStorage) | Solo ayuda en **recargas**, no en la primera carga. |

## La solución: dos RPCs

- **Llamadas normales** (`getCustomer`, `getAllProducts`, escrituras vía MetaMask, etc.) → **Alchemy**
  (`NEXT_PUBLIC_RPC_URL`). Fiable y suficiente: son `eth_call`, no `eth_getLogs`.
- **Escaneo de logs** (`queryFilter` de `CustomerRegistered`) → **RPC público con rangos grandes**
  (`NEXT_PUBLIC_LOGS_RPC_URL`). Recomendado: **PublicNode**
  `https://ethereum-sepolia-rpc.publicnode.com` — **sin API key** (no añade ningún secret nuevo).

Con un RPC que admite rangos grandes, subimos la ventana a **2000** bloques:
~890.000 / 2000 ≈ **445 peticiones** → con concurrencia 4 + backoff, carga en **~40–60 s**.

> ℹ️ PublicNode **no publica** un cap exacto de `eth_getLogs`; la guía típica de nodos Ethereum es
> 2.000–10.000 bloques. **2000 es el suelo seguro** del rango documentado. Si compruebas que aguanta,
> puedes subir `NEXT_PUBLIC_LOG_WINDOW_SIZE` hacia `10000` (~89 peticiones, ~10 s) **sin redeploy de
> código** (es env var).

### Robustez del escaneo (`paginatedQueryFilter`)

El helper `apps/web-admin/src/lib/paginatedQueryFilter.ts`, además de trocear:

- procesa las ventanas en **lotes de concurrencia limitada** (`NEXT_PUBLIC_LOG_CONCURRENCY`, default 4)
  con micro-pausa entre lotes — para no exceder los compute units/segundo;
- **reintenta con backoff exponencial** (500ms → 8s, hasta 5 veces) **solo** ante errores de
  rate-limit (429); ante un error de **rango (400)** falla rápido (es config, no se reintenta).

## Configuración por entorno

| Entorno | `NEXT_PUBLIC_RPC_URL` | `NEXT_PUBLIC_LOGS_RPC_URL` | `NEXT_PUBLIC_LOG_WINDOW_SIZE` | `NEXT_PUBLIC_DEPLOY_BLOCK` |
|---------|------------------------|-----------------------------|------------------------------|----------------------------|
| **Anvil (local)** | `http://localhost:8545` | *(vacío → cae a RPC_URL)* | `10` (default; pocos bloques, da igual) | `0` |
| **Sepolia (Vercel)** | Alchemy Sepolia | `https://ethereum-sepolia-rpc.publicnode.com` | `2000` | `11146508` |

> **Anvil queda idéntico:** al no definir `NEXT_PUBLIC_LOGS_RPC_URL`, el escaneo cae al mismo nodo
> local; el throttling y los reintentos no cambian los datos, solo el ritmo. Mismos clientes mostrados.

## Limitación honesta y futuro

Escanear logs desde el cliente **no escala**: el nº de peticiones crece con la antigüedad del
contrato. Para este demo, cercano al deploy, basta. La solución de producción sería un **indexer**
(p.ej. The Graph) o **Alchemy PAYG**, o añadir `getAllCustomers()` al contrato. Documentado como
mejora futura.
