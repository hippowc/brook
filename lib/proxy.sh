# proxy.sh —— GitHub 下载代理
# 预设在 proxies.conf：
#   名字|prefix|https://代理地址/          → 完整 URL 前拼接（gh-proxy 系）
#   名字|replace|github.com|镜像域名       → 域名替换
# 使用：--proxy <名字> 或 BROOK_PROXY=<名字>；--proxy 也可直接给 URL 前缀

list_proxies() {
  echo "可用代理预设（--proxy <名字> 或 BROOK_PROXY=<名字>）："
  grep -Ev '^[[:space:]]*(#|$)' "$BROOK_HOME/proxies.conf" | while IFS='|' read -r name mode rest; do
    printf '  %-12s %-8s %s\n' "$name" "$mode" "$rest"
  done
  echo "也可以直接传 URL 前缀：--proxy https://ghfast.top/"
  echo "提示：--proxy none 强制直连（覆盖 BROOK_PROXY 环境变量）"
}

proxy_apply() {
  local url="$1"
  if [ -z "$PROXY_NAME" ] || [ "$PROXY_NAME" = "none" ]; then
    echo "$url"
    return 0
  fi
  case "$PROXY_NAME" in
    http://*|https://*)
      echo "${PROXY_NAME%/}/$url"
      return 0
      ;;
  esac
  local line mode
  line="$(grep -E "^${PROXY_NAME}\|" "$BROOK_HOME/proxies.conf" 2>/dev/null | head -1 || true)"
  [ -n "$line" ] || die "未知代理 '$PROXY_NAME'（brook proxies 查看预设）"
  mode="$(printf '%s' "$line" | cut -d'|' -f2)"
  case "$mode" in
    prefix)
      local p
      p="$(printf '%s' "$line" | cut -d'|' -f3)"
      echo "${p%/}/$url"
      ;;
    replace)
      local from to
      from="$(printf '%s' "$line" | cut -d'|' -f3)"
      to="$(printf '%s' "$line" | cut -d'|' -f4)"
      echo "${url//$from/$to}"
      ;;
    *) die "代理模式无效: $mode" ;;
  esac
}
