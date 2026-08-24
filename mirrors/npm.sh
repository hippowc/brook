# npm —— npm registry（固定 npmmirror）

MIRROR_PROVIDERS="npmmirror（固定）"

mirror_desc() { echo "npm registry（npmmirror）"; }

mirror_detect() {
  if command -v npm >/dev/null 2>&1; then
    echo "适用（npm 已激活）"
  else
    echo "inapplicable（npm 未激活：先装 fnm 并切换 node）"
  fi
}

mirror_status() {
  command -v npm >/dev/null 2>&1 || { echo "-"; return 0; }
  local v
  v="$(npm config get registry 2>/dev/null || true)"
  case "$v" in
    *npmmirror*) echo "✓ $v" ;;
    *) echo "✗ 当前：${v:-未设置}" ;;
  esac
}

mirror_apply() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将执行：npm config set registry https://registry.npmmirror.com"
    return 0
  fi
  npm config set registry https://registry.npmmirror.com
  log "已设置：npm registry=https://registry.npmmirror.com"
}
