// 🇪🇸 NOTA: lee logs de eventos en VENTANAS de bloques en vez de un único rango gigante.
// El free tier de Alchemy limita `eth_getLogs` a un rango de 10 bloques; pedir 0→latest (lo que
// hace ethers v6 por defecto si omites fromBlock/toBlock) revienta en Sepolia. Aquí troceamos
// [fromBlock, latest] en trozos de `windowSize` bloques y ACUMULAMOS los eventos.
//
// 🇪🇸 Comportamiento en Anvil: idéntico en DATOS. Recorremos los mismos bloques (desde fromBlock,
// que en local es 0) y devolvemos exactamente los mismos eventos; solo cambia el número de
// peticiones RPC (Anvil no tiene límite, así que da igual cuántas ventanas sean).

import { type Contract, type EventLog, type Log, type JsonRpcProvider } from "ethers";

export async function paginatedQueryFilter(
  contract: Contract,
  // 🇪🇸 `filter` es lo que devuelve `contract.filters.EventName()` (un TopicFilter de ethers v6).
  filter: Parameters<Contract["queryFilter"]>[0],
  fromBlock: number,
  windowSize: number,
): Promise<(EventLog | Log)[]> {
  // 🇪🇸 El runner de un Contract de solo-lectura ES el provider (JsonRpcProvider). Lo usamos para
  // saber hasta qué bloque escanear (latest).
  const provider = contract.runner as JsonRpcProvider;
  const latest = await provider.getBlockNumber();

  const events: (EventLog | Log)[] = [];
  for (let start = fromBlock; start <= latest; start += windowSize) {
    // 🇪🇸 Ventana inclusiva [start, end]; el último trozo se recorta a `latest`.
    const end = Math.min(start + windowSize - 1, latest);
    events.push(...(await contract.queryFilter(filter, start, end)));
  }
  return events;
}
