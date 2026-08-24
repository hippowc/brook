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
  echo
  echo "用法："
  echo "  brook install codex --proxy gh-proxy    # 单次指定"
  echo "  export BROOK_PROXY=gh-proxy             # 全局（写进 shell rc 永久生效）"
  echo "  brook install codex --proxy https://ghfast.top/   # 直接给 URL 前缀"
  echo "  --proxy none 可强制直连（覆盖 BROOK_PROXY）"
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

# 实测各预设当前下载速度（用 codex 仓库的小资产 bwrap，约 0.2MB）
_measure_speed() {
  local url="$1" out speed time
  out="$(curl -fsSL -o /dev/null --connect-timeout 8 --max-time 60 -w '%{speed_download}|%{time_total}' "$url" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    echo "0|不可达或超时"
    return 0
  fi
  speed="${out%%|*}"
  time="${out##*|}"
  echo "${speed%.*}|${time}s"
}

_fmt_speed() {
  awk -v s="$1" 'BEGIN{ if (s>=1048576) printf "%.1fMB/s", s/1048576; else if (s>=1024) printf "%.0fKB/s", s/1024; else printf "%.0fB/s", s }'
}

proxies_test() {
  local repo="openai/codex" loc tag base
  log "解析测试资产（$repo 最新 release）..."
  loc="$(curl -fsSL -o /dev/null --max-redirs 5 -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null || true)"
  tag="$(printf '%s' "$loc" | sed -n 's#.*/releases/tag/\(.*\)$#\1#p')"
  [ -n "$tag" ] || die "无法解析测试资产（网络问题）"
  base="https://github.com/$repo/releases/download/$tag/bwrap-x86_64-unknown-linux-musl.zst"
  log "测试资产：bwrap（~0.2MB，tag=$tag）；结果受当时网络波动影响"
  local results name mode rest url from to
  results="direct|$(_measure_speed "$base")"
  while IFS='|' read -r name mode rest; do
    case "$mode" in
      prefix) url="${rest%/}/$base" ;;
      replace)
        from="$(printf '%s' "$rest" | cut -d'|' -f1)"
        to="$(printf '%s' "$rest" | cut -d'|' -f2)"
        url="${base//$from/$to}" ;;
      *) continue ;;
    esac
    results="$results
$name|$(_measure_speed "$url")"
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$BROOK_HOME/proxies.conf")
  echo
  printf '%-14s %-12s %s\n' "预设" "速度" "结果"
  printf '%s\n' "$results" | sort -t'|' -k2 -rn | while IFS='|' read -r n speed note; do
    printf '%-14s %-12s %s\n' "$n" "$(_fmt_speed "$speed")" "$note"
  done
  echo
  echo "用法：安装命令加 --proxy <预设>，或 export BROOK_PROXY=<预设>"
}
