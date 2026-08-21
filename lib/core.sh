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
  brook ripgrep install                 装一个试试
  brook codex install --proxy gh-proxy  国内网络建议加代理
  brook codex config                    部分工具装完需要配置

子命令：
  brook list                          列出全部工具及安装状态
  brook <tool> install [选项]         安装（默认最新版）
  brook <tool> upgrade [--proxy P]    升级到最新版
  brook <tool> status                 查看安装与配置状态
  brook <tool> config                 列出该工具的配置实践及状态
  brook <tool> config <实践>           执行指定配置实践
  brook <tool> usage                  查看常见用法速查
  brook <tool> remove                 移除
  brook upgrade                       更新 brook 自身
  brook proxies                       查看加速代理预设

install 选项：
  --version V    指定版本（默认 latest）
  --proxy P      走代理：预设名（gh-proxy/ghfast）或直接给 URL 前缀
  --force        强制重装

代理（国内强烈建议）：
  brook codex install --proxy gh-proxy      单次使用
  export BROOK_PROXY=gh-proxy               全局生效
  brook proxies                             查看预设与实测速度

支持的格式：tar.gz / tar.xz / zip / zst / 裸二进制；
上游改资产命名时自动降级：预置候选 → 枚举真实资产列表（详见 README）。
USAGE
}

list_tools() {
  local f tool desc tag status cfg
  echo "可安装的工具（brook <工具> install，国内建议加 --proxy gh-proxy）："
  echo
  printf '%-16s %-16s %-6s %s\n' "工具" "状态" "配置" "说明"
  for f in "$BROOK_HOME"/tools/*/tool.conf; do
    [ -e "$f" ] || continue
    tool="$(basename "$(dirname "$f")")"
    desc="$(
      # shellcheck source=/dev/null
      source "$f"
      echo "${DESC:-}"
    )"
    if ls "$BROOK_HOME/tools/$tool/config/"*.sh >/dev/null 2>&1; then cfg="✓"; else cfg="-"; fi
    tag="$(installed_tag_of "$tool")"
    if [ -n "$tag" ] && binaries_present "$tool"; then
      status="✓ $tag"
    elif [ -n "$tag" ]; then
      status="△ $tag(缺二进制)"
    else
      status="✗ 未安装"
    fi
    printf '%-16s %-16s %-6s %s\n' "$tool" "$status" "$cfg" "$desc"
  done
  echo
  echo "标 ✓ 配置的工具装完后记得运行：brook <工具> config"
  echo "不会用某个工具？brook <工具> usage 查看常见用法速查"
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
    upgrade) self_upgrade ;;
    *)
      local conf="$BROOK_HOME/tools/$cmd/tool.conf"
      [ -f "$conf" ] || die "未知工具 '$cmd'（brook list 查看可用工具）"
      shift
      local action="${1:-status}"
      shift || true
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
      run_tool "$cmd" "$action" "$practice"
      ;;
  esac
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
        echo "$tool 的配置实践（brook $tool config <名字> 执行）："
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
