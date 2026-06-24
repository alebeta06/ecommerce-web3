import { Contract, type ContractRunner, type InterfaceAbi } from "ethers";
import EuroTokenAbi from "@/abi/EuroToken.json";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: factory de instancias de contrato. Un `ContractRunner` puede ser un Provider (solo
// lectura) o un Signer (lectura + escritura). Esta app solo habla con EuroToken (balanceOf para
// mostrar saldo; el mint vive server-side en la API route), así que centralizamos SOLO su address
// + ABI aquí. El ABI lo sincroniza `pnpm sync-abis`.
export function getEuroTokenContract(runner: ContractRunner): Contract {
  return new Contract(env.euroTokenAddress, EuroTokenAbi as InterfaceAbi, runner);
}
