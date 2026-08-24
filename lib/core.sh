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
把 GitHub 上发布的命令行工具一键装到 ~/.local/bin（自动加入 PATH）。
支持 Linux / macOS（x86_64 / arm64），内置国内加速代理，自动解析最新版。

快速上手：
  brook list                            看看能装什么（含状态）
  brook install ripgrep                 装一个试试
  brook install codex --proxy gh-proxy  国内网络建议加代理
  brook config codex                    部分工具装完需要配置

子命令：
  brook list                          列出全部工具及安装状态
  brook install <工具> [选项]          安装（默认最新版）
  brook upgrade [工具]                 升级指定工具；不带工具 = 更新 brook 自身
  brook status <工具>                  查看安装与配置状态
  brook config <工具>                  列出该工具的配置实践及状态
  brook config <工具> <实践>            执行指定配置实践
  brook usage <工具>                   查看常见用法速查
  brook remove <工具>                  移除
  brook proxies                       查看加速代理预设

install 选项：
  --version V    指定版本（默认 latest）
  --proxy P      走代理：预设名（gh-proxy/ghfast）或直接给 URL 前缀
  --force        强制重装

代理（国内强烈建议）：
  brook install codex --proxy gh-proxy      单次使用
  export BROOK_PROXY=gh-proxy               全局生效
  brook proxies                             查看预设与实测速度

超级官方应用（官网一行命令安装，brook 只管装）：
  brook install brew                 安装 Homebrew
  brook install rustup               安装 Rust 工具链

支持的格式：tar.gz / tar.xz / zip / zst / 裸二进制；
上游改资产命名时自动降级：预置候选 → 枚举真实资产列表（详见 README）。
USAGE
}

# 读一个条目（工具或官方应用）的展示信息：类别/说明/配置支持/状态
_entry_row() {
  local f="$1" tool category desc cfg status
  case "$f" in
    */tools/*) tool="$(basename "$(dirname "$f")")" ;;
    *)         tool="$(basename "$f" .conf)" ;;
  esac
  category="$(
    # shellcheck source=/dev/null
    source "$f"
    echo "${CATEGORY:-binary}"
  )"
  desc="$(
    # shellcheck source=/dev/null
    source "$f"
    echo "${DESC:-}"
  )"
  if [ -d "$BROOK_HOME/tools/$tool/config" ] && ls "$BROOK_HOME/tools/$tool/config/"*.sh >/dev/null 2>&1; then
    cfg="✓"
  else
    cfg="-"
  fi
  case "$f" in
    */tools/*)
      if [ -n "$(installed_tag_of "$tool")" ] && binaries_present "$tool"; then
        status="✓ $(installed_tag_of "$tool")"
      elif [ -n "$(installed_tag_of "$tool")" ]; then
        status="△ $(installed_tag_of "$tool")(缺二进制)"
      else
        status="✗ 未安装"
      fi
      ;;
    *)
      if (
        # shellcheck source=/dev/null
        source "$f"
        _official_installed
      ); then
        status="✓ 已安装"
      else
        status="✗ 未安装"
      fi
      ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$category" "$tool" "$status" "$cfg" "$desc"
}

_list_category() {
  local cat="$1" title="$2" note="$3" f row rows="" found=0
  for f in "$BROOK_HOME"/tools/*/tool.conf "$BROOK_HOME"/official/*.conf; do
    [ -e "$f" ] || continue
    row="$(_entry_row "$f")"
    [ "${row%%	*}" = "$cat" ] || continue
    found=1
    rows="$rows$row
"
  done
  [ "$found" = 1 ] || return 0
  echo "$title"
  [ -n "$note" ] && echo "$note"
  printf '%-16s %-18s %-6s %s\n' "名称" "状态" "配置" "说明"
  printf '%s' "$rows" | while IFS=$'\t' read -r _c tool status cfg desc; do
    [ -n "$tool" ] || continue
    printf '%-16s %-18s %-6s %s\n' "$tool" "$status" "$cfg" "$desc"
  done
  echo
}

list_tools() {
  echo "可安装的条目（brook install <名称>，国内建议加 --proxy gh-proxy）："
  echo
  _list_category binary "【二进制工具】常用 CLI" ""
  _list_category language "【语言工具】工具链管理器" "先装管理器，再用它装具体版本（如 g install 1.24 / uv python install 3.12）"
  _list_category installer "【安装包工具】包管理器" "装它，是为了用它装 brook 覆盖不到的东西"
  echo "标 ✓ 配置的工具装完后记得运行：brook config <工具>"
  echo "不会用某个工具？brook usage <工具> 查看常见用法速查"
}

self_upgrade() {
  if [ ! -d "$BROOK_HOME/.git" ]; then
    die "$BROOK_HOME 不是 git 克隆，无法自更新（请用 install.sh 重装）"
  fi
  local before after
  before="$(git -C "$BROOK_HOME" rev-parse --short HEAD 2>/dev/null)"
  log "更新 brook..."
  if git -C "$BROOK_HOME" pull --ff-only; then
    after="$(git -C "$BROOK_HOME" rev-parse --short HEAD 2>/dev/null)"
    if [ "$before" = "$after" ]; then
      log "已是最新版（$after）"
    else
      log "已更新：$before → $after"
      log "查看变化：git -C $BROOK_HOME log --oneline ${before}..HEAD"
    fi
  else
    die "更新失败（可能有本地改动或网络问题：git -C $BROOK_HOME status 检查）"
  fi
}

brook_main() {
  local cmd="${1:-help}"
  case "$cmd" in
    help|-h|--help) usage ;;
    list) list_tools ;;
    proxies) list_proxies ;;
    upgrade)
      if [ $# -ge 2 ]; then
        shift
        _dispatch_tool upgrade "$@"
      else
        self_upgrade
      fi
      ;;
    install|status|config|usage|remove)
      shift
      [ $# -ge 1 ] || die "用法：brook $cmd <工具>（brook help 查看帮助）"
      _dispatch_tool "$cmd" "$@"
      ;;
    *)
      if [ -f "$BROOK_HOME/tools/$cmd/tool.conf" ] || [ -f "$BROOK_HOME/official/$cmd.conf" ]; then
        die "命令格式为 'brook <动作> <工具>'，如：brook install $cmd"
      fi
      die "未知命令 '$cmd'（brook help 查看用法）"
      ;;
  esac
}

# 按工具分发：official/ 优先判定（独立轨），其余走 tools/ 流水线
_dispatch_tool() {
  local action="$1" tool="$2"
  shift 2
  if [ -f "$BROOK_HOME/official/$tool.conf" ]; then
    run_official "$tool" "$action"
    return 0
  fi
  [ -f "$BROOK_HOME/tools/$tool/tool.conf" ] || die "未知工具 '$tool'（brook list 查看可用工具）"
  TOOL_VERSION="latest"
  FORCE=0
  PROXY_NAME="${BROOK_PROXY:-}"
  local practice=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --version)   TOOL_VERSION="${2:-}"; shift 2 ;;
      --version=*) TOOL_VERSION="${1#*=}"; shift ;;
      --proxy)     PROXY_NAME="${2:-}"; shift 2 ;;
      --proxy=*)   PROXY_NAME="${1#*=}"; shift ;;
      --force|-f)  FORCE=1; shift ;;
      -*) die "未知参数: $1" ;;
      *)
        if [ -n "$practice" ]; then die "多余参数: $1"; fi
        practice="$1"; shift ;;
    esac
  done
  run_tool "$tool" "$action" "$practice"
}

# 展示一个工具全部配置实践的状态（各实践可选定义 config_status）
_show_config_status() {
  local cfgdir="$BROOK_HOME/tools/$1/config" cf
  [ -d "$cfgdir" ] || return 0
  for cf in "$cfgdir"/*.sh; do
    [ -e "$cf" ] || continue
    # shellcheck source=/dev/null
    source "$cf"
    if declare -f config_status >/dev/null; then config_status; fi
    unset -f config_run config_desc config_status 2>/dev/null || true
  done
  return 0
}

run_tool() {
  local tool="$1" action="$2" practice="${3:-}" fn
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/$tool/tool.conf"
  fn="$(printf '%s' "$tool" | tr '-' '_')"
  case "$action" in
    install) do_install "$tool" ;;
    upgrade) do_upgrade "$tool" ;;
    status)  do_status "$tool" ;;
    remove)  do_remove "$tool" ;;
    usage)
      if [ -f "$BROOK_HOME/tools/$tool/usage.md" ]; then
        cat "$BROOK_HOME/tools/$tool/usage.md"
      else
        die "$tool 暂无用法文档（欢迎补充 tools/$tool/usage.md）"
      fi
      ;;
    config)
      local cfgdir="$BROOK_HOME/tools/$tool/config"
      if [ ! -d "$cfgdir" ] || [ -z "$(ls "$cfgdir"/*.sh 2>/dev/null)" ]; then
        die "$tool 暂无配置实践（在 tools/$tool/config/ 下加 <名字>.sh 即可扩展）"
      fi
      if [ -z "$practice" ]; then
        echo "$tool 的配置实践（brook config $tool <名字> 执行）："
        local cf cn
        for cf in "$cfgdir"/*.sh; do
          cn="$(basename "$cf" .sh)"
          printf '  %-10s %s
' "$cn" "$(
            # shellcheck source=/dev/null
            source "$cf"
            if declare -f config_desc >/dev/null; then config_desc; fi
          )"
        done
        echo
        _show_config_status "$tool"
      else
        local cf="$cfgdir/$practice.sh"
        [ -f "$cf" ] || die "没有 '$practice' 配置实践（brook $tool config 查看可用）"
        # shellcheck source=/dev/null
        source "$cf"
        declare -f config_run >/dev/null || die "$practice.sh 未定义 config_run"
        config_run
      fi
      ;;
    *) die "未知操作 '$action'（可用：install / upgrade / status / config / usage / remove）" ;;
  esac
}
