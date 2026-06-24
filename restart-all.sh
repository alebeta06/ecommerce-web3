#!/usr/bin/env bash
# 🇪🇸 restart-all.sh — arranca el sistema Web3 completo en local:
#   mata procesos previos → Anvil → deploy de contratos → siembra datos → 4 apps Next.js.
# Requiere en PATH: anvil, forge, cast (Foundry) y corepack (pnpm). Idempotente: re-ejecutable.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

RPC=http://localhost:8545
ECOM=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
EURT=0x5FbDB2315678afecb367f032d93F642f64180aa3
PK_ADMIN=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
PK_CUSTOMER=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
ACCT1=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

# ── 1) Matar procesos anteriores ─────────────────────────────────────────────
echo "▶ Stopping previous processes…"
pkill -9 -f "anvil"       2>/dev/null
pkill -9 -f "next-server" 2>/dev/null
pkill -9 -f "next dev"    2>/dev/null
for port in 6001 6002 6003 6004 8545; do
  pid=$( { ss -ltnp 2>/dev/null || netstat -ltnp 2>/dev/null; } \
         | grep ":$port " | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2 )
  [ -n "${pid:-}" ] && kill -9 "$pid" 2>/dev/null
done
sleep 2

# ── 2) Arrancar Anvil ────────────────────────────────────────────────────────
echo "▶ Starting Anvil (chainId 31337)…"
anvil --chain-id 31337 > /tmp/anvil.log 2>&1 &
for i in $(seq 1 30); do
  cast block-number --rpc-url "$RPC" >/dev/null 2>&1 && break
  sleep 1
done
cast block-number --rpc-url "$RPC" >/dev/null 2>&1 || { echo "✗ Anvil did not start (see /tmp/anvil.log)"; exit 1; }
echo "  ✓ Anvil up on $RPC"

# ── 3) Deploy de contratos ───────────────────────────────────────────────────
echo "▶ Deploying contracts…"
DEPLOY_OUT=$(cd "$REPO_ROOT/contracts/ecommerce" && \
  forge script script/DeployEcommerce.s.sol --rpc-url "$RPC" --broadcast --private-key "$PK_ADMIN" 2>&1)
if ! echo "$DEPLOY_OUT" | grep -q "$EURT" || ! echo "$DEPLOY_OUT" | grep -q "$ECOM"; then
  echo "✗ Deploy address mismatch (expected deterministic addresses). Full output:"
  echo "$DEPLOY_OUT"
  exit 1
fi
echo "  ✓ EuroToken: $EURT"
echo "  ✓ Ecommerce: $ECOM"

# ── 4) Sembrar datos de prueba ───────────────────────────────────────────────
echo "▶ Seeding test data…"
cast send --rpc-url "$RPC" --private-key "$PK_ADMIN" "$ECOM" \
  "registerCompany(address,string,address)" "$ACCT1" "TechShop" "$ACCT1" >/dev/null \
  || { echo "✗ registerCompany failed"; exit 1; }
echo "  ✓ company: TechShop (companyId=1)"

add_product() {  # $1=name  $2=cid  $3=price(base units)  $4=stock — caller = acct1 (owner)
  cast send --rpc-url "$RPC" --private-key "$PK_CUSTOMER" "$ECOM" \
    "addProduct(uint256,string,string,uint256,uint256)" 1 "$1" "$2" "$3" "$4" >/dev/null \
    || { echo "✗ addProduct '$1' failed"; exit 1; }
  echo "  ✓ product: $1"
}
add_product "Smartphone" "bafkreib536nfcvmdjnaxmanfzrkkzpedsoxoypqyz7gppfehrfiyrf65hi" 278990000 7
add_product "Laptop"     "bafkreiguxp3on6ouekheftx32qpt3ckpzsgzdkjt6iy6msozyv7irqrnyi" 800990000 4
add_product "Bicicleta"  "bafkreiczboif47b47voibbru4ri4sfyk2ut3cdaiknj3asme3ueaiuzm4i" 445990000 8

cast send --rpc-url "$RPC" --private-key "$PK_ADMIN" "$EURT" \
  "mint(address,uint256)" "$ACCT1" 1000000000 >/dev/null \
  || { echo "✗ mint failed"; exit 1; }
echo "  ✓ minted 1000 EURT to acct1"

# ── 5) Arrancar las 4 apps ───────────────────────────────────────────────────
echo "▶ Starting apps…"
corepack pnpm --filter compra-stablecoin dev > /tmp/app-6001.log 2>&1 &
corepack pnpm --filter payment-gateway   dev > /tmp/app-6002.log 2>&1 &
corepack pnpm --filter web-admin         dev > /tmp/app-6003.log 2>&1 &
corepack pnpm --filter web-customer      dev > /tmp/app-6004.log 2>&1 &

# ── 6) Esperar HTTP 200 en cada puerto ───────────────────────────────────────
wait_http() {  # $1=port
  for i in $(seq 1 120); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$1" 2>/dev/null)
    if [ "$code" = "200" ]; then
      echo "  ✓ :$1 ready"
      return 0
    fi
    sleep 1
  done
  echo "  ✗ :$1 did not respond within 120s (see /tmp/app-$1.log)"
  return 1
}
echo "▶ Waiting for apps…"
wait_http 6001
wait_http 6002
wait_http 6003
wait_http 6004

# ── 7) Resumen ───────────────────────────────────────────────────────────────
cat <<'EOF'

┌─────────────────────────────────────────────┐
│  Sistema listo                              │
│  Anvil:          http://localhost:8545      │
│  compra-EURT:    http://localhost:6001      │
│  payment-gw:     http://localhost:6002      │
│  web-admin:      http://localhost:6003      │
│  web-customer:   http://localhost:6004      │
│                                             │
│  TechShop (companyId=1)                     │
│  Productos: Smartphone, Laptop, Bicicleta   │
│  Cliente acct1 con 1000 EURT               │
│  Logs: /tmp/anvil.log /tmp/app-600X.log    │
└─────────────────────────────────────────────┘
EOF
