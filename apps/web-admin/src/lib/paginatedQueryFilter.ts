// 🇪🇸 NOTA: lee logs de eventos en VENTANAS de bloques en vez de un único rango gigante, con
// throttling y reintentos para no saturar el RPC.
//
// 🇪🇸 Por qué: pedir 0→latest (lo que hace ethers v6 si omites from/toBlock) revienta en redes
// reales. Pero trocear NO basta: lanzar miles de ventanas a toda velocidad satura el rate-limit por
// segundo del RPC (Alchemy free tier: 500 CUPs/s, eth_getLogs = 75 CU → ~6 req/s → error 429
// "exceeded compute units per second"). Aquí:
//   1. Troceamos [fromBlock, latest] en ventanas de `windowSize` bloques.
//   2. Procesamos las ventanas en LOTES de `concurrency` peticiones simultáneas (no todas a la vez),
//      con una micro-pausa entre lotes.
//   3. Cada ventana reintenta con backoff exponencial SOLO ante errores de rate-limit (429); ante un
//      error de rango (400 "block range") falla rápido, porque reintentar no lo arreglaría.
//
// 🇪🇸 Comportamiento en Anvil: idéntico en DATOS. Recorremos los mismos bloques y devolvemos los
// mismos eventos; el throttling y los reintentos solo cambian el RITMO de las peticiones, no el
// resultado. Anvil no tiene rate-limit, así que los reintentos nunca se disparan.

import { type Contract, type EventLog, type Log, type JsonRpcProvider } from "ethers";

const MAX_RETRIES = 5;
const BASE_BACKOFF_MS = 500; // 500 → 1000 → 2000 → 4000 → 8000
const INTER_BATCH_MS = 150;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// 🇪🇸 ¿Es un error de rate-limit (reintentable) y NO un error de rango (config, no reintentable)?
// ethers v6 envuelve el error JSON-RPC; miramos el mensaje y el código por si acaso.
function isRateLimitError(err: unknown): boolean {
  const e = err as { code?: unknown; error?: { code?: number }; message?: string };
  const msg = (e?.message ?? "").toLowerCase();
  return (
    msg.includes("compute units") ||
    msg.includes("rate limit") ||
    msg.includes("too many requests") ||
    msg.includes("429") ||
    e?.error?.code === 429
  );
}

async function queryWindowWithRetry(
  contract: Contract,
  filter: Parameters<Contract["queryFilter"]>[0],
  start: number,
  end: number,
): Promise<(EventLog | Log)[]> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await contract.queryFilter(filter, start, end);
    } catch (err) {
      // 🇪🇸 Error de rango u otro no-reintentable → propaga (lo verá el hook como error de carga).
      // Solo reintentamos ante rate-limit, y hasta MAX_RETRIES.
      if (!isRateLimitError(err) || attempt >= MAX_RETRIES) throw err;
      await sleep(BASE_BACKOFF_MS * 2 ** attempt);
    }
  }
}

export async function paginatedQueryFilter(
  contract: Contract,
  // 🇪🇸 `filter` es lo que devuelve `contract.filters.EventName()` (un TopicFilter de ethers v6).
  filter: Parameters<Contract["queryFilter"]>[0],
  fromBlock: number,
  windowSize: number,
  concurrency = 4,
): Promise<(EventLog | Log)[]> {
  // 🇪🇸 El runner de un Contract de solo-lectura ES el provider; lo usamos para saber hasta dónde
  // escanear (latest).
  const provider = contract.runner as JsonRpcProvider;
  const latest = await provider.getBlockNumber();

  // 🇪🇸 Precalculamos todas las ventanas [start, end] (inclusivas; la última se recorta a latest).
  const ranges: Array<[number, number]> = [];
  for (let start = fromBlock; start <= latest; start += windowSize) {
    ranges.push([start, Math.min(start + windowSize - 1, latest)]);
  }

  const events: (EventLog | Log)[] = [];
  // 🇪🇸 Procesamos en lotes de `concurrency`: como mucho N peticiones en vuelo a la vez.
  for (let i = 0; i < ranges.length; i += concurrency) {
    const batch = ranges.slice(i, i + concurrency);
    const results = await Promise.all(
      batch.map(([start, end]) => queryWindowWithRetry(contract, filter, start, end)),
    );
    for (const r of results) events.push(...r);
    // 🇪🇸 Micro-pausa entre lotes (no tras el último) para aliviar los compute units por segundo.
    if (i + concurrency < ranges.length) await sleep(INTER_BATCH_MS);
  }
  return events;
}
