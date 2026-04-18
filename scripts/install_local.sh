#!/usr/bin/env bash
# 在本地源码树中编译并安装到本机 PATH（使用 go build，不依赖远程模块版本）。
# 在仓库根目录执行：
#   ./scripts/install_local.sh
# 环境变量：
#   INSTALL_DIR=...     安装目录（默认 /usr/local/bin 或可写则用 ~/.local/bin）
#   CGO_ENABLED=...     默认 0（与 scripts/build_release.sh 一致）
#   EXTRA_GOFLAGS=...   额外 go build 参数（空格分隔，例如 "-tags=foo"）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pick_dest() {
  if [[ -n "${INSTALL_DIR:-}" ]]; then
    mkdir -p "$INSTALL_DIR"
    echo "$INSTALL_DIR"
    return
  fi
  if [[ -d /usr/local/bin ]] && [[ -w /usr/local/bin ]]; then
    echo "/usr/local/bin"
    return
  fi
  mkdir -p "${HOME}/.local/bin"
  echo "${HOME}/.local/bin"
}

export CGO_ENABLED="${CGO_ENABLED:-0}"
LDFLAGS="-s -w"

dest="$(pick_dest)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

echo "==> go build brook -> ${dest}/brook"
# shellcheck disable=SC2086
go build -trimpath -ldflags="$LDFLAGS" ${EXTRA_GOFLAGS:-} -o "$stage/brook" "./cmd/brook"
install -m 0755 "$stage/brook" "${dest}/brook"

echo "Installed -> ${dest}/brook"
echo "请确认 ${dest} 已在 PATH 中（例如 export PATH=\"${dest}:\$PATH\"）。"
