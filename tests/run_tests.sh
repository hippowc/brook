#!/usr/bin/env bash
# brook 测试入口：L0/L1 bats + L2 schema 校验（本地与 CI 共用）
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

echo "== L0/L1: bats 测试 =="
if command -v bats >/dev/null 2>&1; then
  BATS="bats"
else
  CACHE="${BATS_CACHE:-$ROOT/.cache/bats-core}"
  if [ ! -x "$CACHE/bin/bats" ]; then
    echo "（本地未装 bats，clone bats-core 到 $CACHE）"
    mkdir -p "$(dirname "$CACHE")"
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$CACHE"
  fi
  BATS="$CACHE/bin/bats"
fi
"$BATS" "$ROOT"/tests/*.bats

echo
echo "== L2: schema 静态校验 =="
python3 "$ROOT/tests/schema_check.py"

echo
echo "✅ 全部通过"
