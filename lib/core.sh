# core.sh —— 基础工具、帮助与子命令分发

log()  { printf '\033[1;32m[brook]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[brook]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[brook]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

os() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo macos ;;
    *) die "不支持的操作系统: $(uname -s)" ;;
  esac
}

arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo x86_64 ;;
    arm64|aarch64) echo arm64 ;;
    *) die "不支持的架构: $(uname -m)" ;;
  esac
}

# 当前用户的 shell rc（macOS 默认 zsh）
rc_file() {
  case "${SHELL:-/bin/bash}" in
    *zsh) echo "$HOME/.zshrc" ;;
    *)    echo "$HOME/.bashrc" ;;
  esac
}

# 幂等追加一行到 rc
append_rc() {
  local line="$1" rc
  rc="$(rc_file)"
  touch "$rc"
  if ! grep -qF "$line" "$rc"; then
    echo "$line" >> "$rc"
    log "已写入 $(basename "$rc"): $line"
  fi
}

# 确保 BIN_DIR 在 PATH 中
ensure_bin_path() {
  append_rc 'export PATH="$HOME/.local/bin:$PATH"'
}

# 交互读取：ask VAR "提示" [默认值]
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __v=""
  if [ -n "$__default" ]; then
    read -rp "$__prompt [$__default]: " __v || true
    eval "$__var=\"\${__v:-\$__default}\""
  else
    read -rp "$__prompt: " __v || true
    eval "$__var=\"\$__v\""
  fi
}

usage() {
  cat <<'USAGE'
brook —— GitHub release 二进制安装器

用法：
  brook list                          列出可用工具及安装状态
  brook <tool> install [选项]         安装
        选项：--version V  指定版本（默认 latest）
              --proxy P    走代理（brook proxies 查看预设，也可直接给 URL 前缀）
              --force      强制重装
  brook <tool> upgrade [--proxy P]    升级到最新版
  brook <tool> status                 查看安装/配置状态
  brook <tool> config                 运行配置钩子（部分工具支持）
  brook <tool> remove                 移除已安装的二进制
  brook proxies                       查看可用代理预设

示例：
  brook codex install --proxy gh-proxy
  brook codex install --version rust-v0.148.0
  brook codex config

扩展：
  新增工具 = registry/<名字>.conf（release 映射）+ 可选 hooks/<名字>.sh（配置钩子）
USAGE
}

list_tools() {
  local f tool desc tag status
  printf '%-18s %-18s %s\n' "工具" "状态" "说明"
  for f in "$BROOK_HOME"/registry/*.conf; do
    [ -e "$f" ] || continue
    tool="$(basename "$f" .conf)"
    desc="$(
      # shellcheck source=/dev/null
      source "$f"
      echo "${DESC:-}"
    )"
    tag="$(installed_tag_of "$tool")"
    if [ -n "$tag" ] && binaries_present "$tool"; then
      status="✓ $tag"
    elif [ -n "$tag" ]; then
      status="△ $tag(缺二进制)"
    else
      status="✗ 未安装"
    fi
    printf '%-18s %-18s %s\n' "$tool" "$status" "$desc"
  done
}

brook_main() {
  local cmd="${1:-help}"
  case "$cmd" in
    help|-h|--help) usage ;;
    list) list_tools ;;
    proxies) list_proxies ;;
    *)
      local conf="$BROOK_HOME/registry/$cmd.conf"
      [ -f "$conf" ] || die "未知工具 '$cmd'（brook list 查看可用工具）"
      shift
      local action="${1:-status}"
      shift || true
      TOOL_VERSION="latest"
      FORCE=0
      PROXY_NAME="${BROOK_PROXY:-}"
      while [ $# -gt 0 ]; do
        case "$1" in
          --version)   TOOL_VERSION="${2:-}"; shift 2 ;;
          --version=*) TOOL_VERSION="${1#*=}"; shift ;;
          --proxy)     PROXY_NAME="${2:-}"; shift 2 ;;
          --proxy=*)   PROXY_NAME="${1#*=}"; shift ;;
          --force|-f)  FORCE=1; shift ;;
          *) die "未知参数: $1" ;;
        esac
      done
      run_tool "$cmd" "$action"
      ;;
  esac
}

run_tool() {
  local tool="$1" action="$2" fn
  # shellcheck source=/dev/null
  source "$BROOK_HOME/registry/$tool.conf"
  fn="$(printf '%s' "$tool" | tr '-' '_')"
  case "$action" in
    install) do_install "$tool" ;;
    upgrade) do_upgrade "$tool" ;;
    status)  do_status "$tool" ;;
    remove)  do_remove "$tool" ;;
    config)
      if [ -f "$BROOK_HOME/hooks/$tool.sh" ]; then
        # shellcheck source=/dev/null
        source "$BROOK_HOME/hooks/$tool.sh"
        if declare -f "${fn}_config" >/dev/null; then
          "${fn}_config"
        else
          die "$tool 的钩子未定义 ${fn}_config"
        fi
      else
        die "$tool 无配置支持（没有 hooks/$tool.sh）"
      fi
      ;;
    *) die "未知操作 '$action'（可用：install / upgrade / status / config / remove）" ;;
  esac
}
