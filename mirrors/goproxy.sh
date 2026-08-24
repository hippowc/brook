# goproxy —— Go 模块代理（GOPROXY，固定 goproxy.cn）

MIRROR_PROVIDERS="goproxy.cn（固定）"

mirror_desc() { echo "Go 模块代理（GOPROXY）"; }

mirror_detect() {
  if command -v go >/dev/null 2>&1; then
    echo "适用（go 已激活）"
  else
    echo "inapplicable（go 未激活：先装 g 并切换工具链）"
  fi
}

mirror_status() {
  command -v go >/dev/null 2>&1 || { echo "-"; return 0; }
  local v
  v="$(go env GOPROXY 2>/dev/null || true)"
  case "$v" in
    *goproxy.cn*) echo "✓ $v" ;;
    *) echo "✗ 当前：${v:-未设置}" ;;
  esac
}

mirror_apply() {
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将执行：go env -w GOPROXY=https://goproxy.cn,direct"
    return 0
  fi
  go env -w GOPROXY=https://goproxy.cn,direct
  log "已设置：GOPROXY=https://goproxy.cn,direct"
}
