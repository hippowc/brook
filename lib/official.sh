# official.sh —— 超级官方应用：委托官网首屏一行命令安装
# 与 tools/ 二进制流水线完全独立：brook 只管"装"，装后由工具自身管理

_official_installed() {
  local b
  for b in ${BINARIES:-}; do
    if command -v "$b" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

official_list() {
  local f name desc status
  [ -d "$BROOK_HOME/official" ] || return 0
  for f in "$BROOK_HOME"/official/*.conf; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .conf)"
    desc="$(
      # shellcheck source=/dev/null
      source "$f"
      echo "${DESC:-}"
    )"
    if (
      # shellcheck source=/dev/null
      source "$f"
      _official_installed
    ); then
      status="✓ 已安装"
    else
      status="✗ 未安装"
    fi
    printf '%-16s %-12s %s\n' "$name" "$status" "$desc"
  done
  return 0
}

official_install() {
  local name="$1" tmp
  [ -n "${SCRIPT_URL:-}" ] || die "$name：conf 缺少 SCRIPT_URL"
  if _official_installed; then
    log "$name 已安装，无需重复（如需重装请用官方方式）"
    return 0
  fi
  tmp="$(mktemp)"
  log "获取官方安装脚本：$SCRIPT_URL"
  curl -fsSL "$SCRIPT_URL" -o "$tmp" || { rm -f "$tmp"; die "获取安装脚本失败（网络问题可设 https_proxy 环境变量）"; }
  log "即将执行官方安装脚本（可能需要 sudo 与交互确认）"
  if ! bash "$tmp"; then
    rm -f "$tmp"
    die "官方安装脚本执行失败"
  fi
  rm -f "$tmp"
  log "$name 安装完成（此后的更新与管理请用工具自身机制）"
}

official_status() {
  local name="$1" b any=0
  echo "应用:    $name —— ${DESC:-}"
  echo "类别:    超级官方应用（官方脚本安装，brook 只管装）"
  echo "脚本:    ${SCRIPT_URL:-}"
  for b in ${BINARIES:-}; do
    if command -v "$b" >/dev/null 2>&1; then
      echo "二进制:  ✓ $(command -v "$b")"
      any=1
    else
      echo "二进制:  ✗ $b 不在 PATH（brook install $name）"
    fi
  done
  if [ "$any" = 1 ]; then
    echo "提示:    更新/卸载请用该工具自身机制，brook 不代办"
  fi
}

run_official() {
  local name="$1" action="$2"
  # shellcheck source=/dev/null
  source "$BROOK_HOME/official/$name.conf"
  case "$action" in
    install) official_install "$name" ;;
    status)  official_status "$name" ;;
    upgrade) die "超级官方应用经官方脚本安装，更新请用工具自身机制" ;;
    remove)  die "超级官方应用经官方脚本安装，卸载请用官方方式（brook 不代拆）" ;;
    config)  die "超级官方应用不提供配置实践（配置由工具自身管理）" ;;
    usage)
      if [ -f "$BROOK_HOME/official/$name.usage.md" ]; then
        cat "$BROOK_HOME/official/$name.usage.md"
      else
        die "$name 暂无用法文档"
      fi
      ;;
    *) die "未知操作 '$action'（超级官方应用支持：install / status / usage）" ;;
  esac
}
