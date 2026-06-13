import { Contract, type ContractRunner, type InterfaceAbi } from "ethers";
import EcommerceAbi from "@/abi/Ecommerce.json";
import EuroTokenAbi from "@/abi/EuroToken.json";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: factory genérica de instancias de contrato. Un `ContractRunner` puede ser un Provider
// (solo lectura) o un Signer (lectura + escritura). Centralizar address + ABI aquí evita repetirlos
// por toda la app y mantiene una única fuente de verdad. Los ABIs los sincroniza `pnpm sync-abis`.

export function getEcommerceContract(runner: ContractRunner): Contract {
  return new Contract(env.ecommerceAddress, EcommerceAbi as InterfaceAbi, runner);
}

export function getEuroTokenContract(runner: ContractRunner): Contract {
  return new Contract(env.euroTokenAddress, EuroTokenAbi as InterfaceAbi, runner);
}
