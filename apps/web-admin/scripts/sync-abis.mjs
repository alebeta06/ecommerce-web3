// 🇪🇸 NOTA: ABI bridge reproducible. Los artefactos de Foundry viven en
// contracts/<proj>/out/ (gitignored) y se regeneran con `forge build`. Este script extrae
// SOLO el array `.abi` de cada artefacto y lo escribe en src/abi/, que es lo único que el
// frontend (ethers.js) necesita. Reejecutable: si el contrato cambia y se recompila, basta
// con `pnpm sync-abis`. Node puro, sin dependencias.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../.."); // apps/web-admin/scripts -> repo root
const outDir = resolve(here, "../src/abi");

// 🇪🇸 Solo los ABIs que web-admin consume: la tienda y el token.
const SOURCES = [
  { name: "Ecommerce", artifact: "contracts/ecommerce/out/Ecommerce.sol/Ecommerce.json" },
  { name: "EuroToken", artifact: "contracts/euro-token/out/EuroToken.sol/EuroToken.json" },
];

mkdirSync(outDir, { recursive: true });

for (const { name, artifact } of SOURCES) {
  const src = resolve(repoRoot, artifact);
  let raw;
  try {
    raw = readFileSync(src, "utf8");
  } catch {
    console.error(`✗ Missing artifact: ${artifact}`);
    console.error("  Compile the contracts first (forge build).");
    process.exit(1);
  }
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed.abi)) {
    console.error(`✗ ${artifact} has no top-level .abi array`);
    process.exit(1);
  }
  const dest = resolve(outDir, `${name}.json`);
  writeFileSync(dest, `${JSON.stringify(parsed.abi, null, 2)}\n`);
  console.log(`✓ ${name}: ${parsed.abi.length} ABI entries -> src/abi/${name}.json`);
}
