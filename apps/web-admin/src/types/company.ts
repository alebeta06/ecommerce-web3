// 🇪🇸 NOTA: refleja el struct CompanyLib.Company del contrato. read.getCompany() devuelve un Result
// dinámico de ethers (tuple con campos nombrados); toCompany aísla AQUÍ el casteo a tipos TS para
// que el resto de la app no toque `any`.
export interface Company {
  id: number;
  owner: string;
  name: string;
  payoutWallet: string;
  exists: boolean;
}

export function toCompany(raw: {
  id: bigint;
  owner: string;
  name: string;
  payoutWallet: string;
  exists: boolean;
}): Company {
  return {
    id: Number(raw.id),
    owner: String(raw.owner),
    name: String(raw.name),
    payoutWallet: String(raw.payoutWallet),
    exists: Boolean(raw.exists),
  };
}
