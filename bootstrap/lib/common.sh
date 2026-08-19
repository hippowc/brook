# common.sh —— 分发逻辑、交互式向导与共享工具
#
# bootstrap 管两类条目：
#   adapters/<agent>.sh   agent 适配器，必须实现三件套：<agent>_install/_configure/_verify
#   tasks/<task>.sh       可选初始化任务，必须实现：<task 名连字符转下划线>_run
# 每个条目可选实现（交互式向导用）：
#   <name>_desc     一句话描述（菜单展示）
#   <name>_status   当前状态（✓/△/✗ 开头）
#   <name>_options  运行前的定制化提问（如版本、下载地址）
# 新增 agent = 加一个适配器；新增初始化功能 = 加一个任务；核心代码零改动。

log()  { printf '\033[1;32m[brook]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[brook]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[brook]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

DEFAULT_AGENT="${DEFAULT_AGENT:-codex}"

# ── 平台检测（Linux / macOS）──
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

# 幂等追加一行到 rc（已存在则跳过）
append_rc() {
  local line="$1" rc
  rc="$(rc_file)"
  touch "$rc"
  if ! grep -qF "$line" "$rc"; then
    echo "$line" >> "$rc"
    log "已写入 $(basename "$rc"): $line"
  fi
}

# 确保 ~/.local/bin 存在且在 PATH 中
ensure_user_bin_path() {
  mkdir -p "$HOME/.local/bin"
  append_rc 'export PATH="$HOME/.local/bin:$PATH"'
}

# ── 交互工具 ──
is_interactive() { [ -t 0 ]; }

# ask VAR "提示" [默认值] —— 结果写入变量 VAR；非交互时自动取默认值
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __v=""
  if ! is_interactive; then
    eval "$__var=\"\$__default\""
    return 0
  fi
  if [ -n "$__default" ]; then
    read -rp "$__prompt [$__default]: " __v || true
    eval "$__var=\"\${__v:-\$__default}\""
  else
    read -rp "$__prompt: " __v || true
    eval "$__var=\"\$__v\""
  fi
}

# confirm "提示" [y|n 默认] —— 返回 0/1；非交互时按默认值
confirm() {
  local __prompt="$1" __default="${2:-y}" __v=""
  if ! is_interactive; then
    [ "$__default" = "y" ]
    return
  fi
  if [ "$__default" = "y" ]; then
    read -rp "$__prompt [Y/n]: " __v || true
    __v="${__v:-y}"
  else
    read -rp "$__prompt [y/N]: " __v || true
    __v="${__v:-n}"
  fi
  case "$__v" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ── provider（模型后端）──
_PROVIDER_LOADED=0
_ensure_provider() {
  [ "$_PROVIDER_LOADED" = 1 ] && return 0
  local f loaded=0
  for f in "$BROOK_ROOT"/bootstrap/providers/*.env; do
    [ -e "$f" ] || continue
    # shellcheck source=/dev/null
    source "$f"
    loaded=1
  done
  [ "$loaded" = 1 ] || die "未找到 provider 定义（bootstrap/providers/*.env）"
  log "provider: ${PROVIDER_NAME:-?}  model: ${PROVIDER_MODEL:-?}"
  ensure_key
  _PROVIDER_LOADED=1
}

# 确保 API key 可用：环境/rc 已有 → 直接用；否则提示输入并写入 shell rc
ensure_key() {
  local var="${PROVIDER_KEY_ENV:-OPENAI_API_KEY}" rc
  rc="$(rc_file)"
  [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  if [ -f "$rc" ] && grep -q "export $var=" "$rc"; then
    # shellcheck source=/dev/null
    source "$rc" 2>/dev/null || true
    [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  fi
  local k
  if is_interactive; then
    read -rsp "请粘贴 $var（不回显）: " k; echo
  else
    die "需要 $var（交互模式下会提示输入）"
  fi
  [ -n "$k" ] || die "需要 API key 才能继续"
  printf 'export %s=%q\n' "$var" "$k" >> "$rc"
  export "$var=$k"
  log "$var 已写入 $rc"
}

# ── 条目发现与执行 ──
list_agents() {
  local f b
  for f in "$BROOK_ROOT"/bootstrap/adapters/*.sh; do
    b="$(basename "$f" .sh)"
    case "$b" in _*) continue ;; esac
    echo "$b"
  done
}

list_tasks() {
  local f b
  for f in "$BROOK_ROOT"/bootstrap/tasks/*.sh; do
    b="$(basename "$f" .sh)"
    case "$b" in _*) continue ;; esac
    echo "$b"
  done
}

_item_file() {
  local i="$1"
  if [ -f "$BROOK_ROOT/bootstrap/adapters/$i.sh" ]; then
    echo "$BROOK_ROOT/bootstrap/adapters/$i.sh"
  elif [ -f "$BROOK_ROOT/bootstrap/tasks/$i.sh" ]; then
    echo "$BROOK_ROOT/bootstrap/tasks/$i.sh"
  else
    return 1
  fi
}

_item_fn() { printf '%s' "$1" | tr '-' '_'; }

# 执行一个条目（agent 或 task）。交互模式下先问定制化选项。
run_item() {
  local i="$1" f fn
  f="$(_item_file "$i")" || die "未知条目 '$i'（./bootstrap.sh --list 查看可用条目）"
  # shellcheck source=/dev/null
  source "$f"
  fn="$(_item_fn "$i")"
  if [ -f "$BROOK_ROOT/bootstrap/adapters/$i.sh" ]; then
    log "=== agent: $i ==="
    _ensure_provider
    if is_interactive && declare -f "${fn}_options" >/dev/null; then "${fn}_options"; fi
    "${fn}_install"
    "${fn}_configure"
    "${fn}_verify"
  else
    log "=== task: $i ==="
    if is_interactive && declare -f "${fn}_options" >/dev/null; then "${fn}_options"; fi
    "${fn}_run"
  fi
}

# ── 交互式向导 ──
_print_status() {
  local i fn st
  echo "当前环境状态："
  for i in $(list_agents) $(list_tasks); do
    st="$(
      # shellcheck source=/dev/null
      source "$(_item_file "$i")"
      fn="$(_item_fn "$i")"
      if declare -f "${fn}_status" >/dev/null; then "${fn}_status"; else echo "? 未知"; fi
    )"
    printf '  %-13s %s\n' "$i" "$st"
  done
}

_item_desc() {
  local i="$1" fn
  (
    # shellcheck source=/dev/null
    source "$(_item_file "$i")"
    fn="$(_item_fn "$i")"
    if declare -f "${fn}_desc" >/dev/null; then "${fn}_desc"; fi
  )
}

interactive_menu() {
  local items=() line choice i n d
  while IFS= read -r line; do items+=("$line"); done < <(list_agents; list_tasks)
  while true; do
    echo
    echo "════════════════════════════════════════"
    echo "        brook 环境初始化向导"
    echo "════════════════════════════════════════"
    _print_status
    echo
    echo "请选择操作："
    n=1
    for i in "${items[@]}"; do
      d="$(_item_desc "$i")"
      printf '  %d) %-13s %s\n' "$n" "$i" "$d"
      n=$((n+1))
    done
    echo "  a) 首次推荐：安装全部 agent + git-key"
    echo "  q) 退出"
    ask choice "你的选择" "a"
    case "$choice" in
      q|Q) log "再见"; exit 0 ;;
      a|A)
        for i in "${items[@]}"; do
          if [ -f "$BROOK_ROOT/bootstrap/adapters/$i.sh" ] || [ "$i" = "git-key" ]; then
            if confirm "执行：$i（$(_item_desc "$i")）？" y; then
              run_item "$i" || warn "$i 未完成，可稍后重试"
            fi
          fi
        done
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#items[@]}" ]; then
          i="${items[$((choice-1))]}"
          run_item "$i" || warn "$i 未完成，可稍后重试"
        else
          warn "无效选择：$choice"
        fi
        ;;
    esac
    if is_interactive; then
      echo
      read -rp "按回车返回菜单..." _ || true
    fi
  done
}

_usage() {
  cat <<USAGE
brook —— agent 环境配置器

用法：
  ./bootstrap.sh                 交互式向导（菜单）；非交互环境自动执行 $DEFAULT_AGENT
  ./bootstrap.sh <条目>...       直接执行指定条目
  ./bootstrap.sh --list          列出可用条目
  ./bootstrap.sh --help          显示本帮助

可用条目：
  agents: $(list_agents | tr '\n' ' ')
  tasks:  $(list_tasks | tr '\n' ' ')

定制示例：
  CODEX_VERSION=rust-v0.148.0 ./bootstrap.sh codex    # pin 版本
  CODEX_ASSET_URL=https://... ./bootstrap.sh codex    # 换下载源

详见 README.md。
USAGE
}

brook_main() {
  case "${1:-}" in
    --list)
      echo "agents:"; list_agents | sed 's/^/  /'
      echo "tasks:";  list_tasks  | sed 's/^/  /'
      exit 0
      ;;
    --help|-h)
      _usage
      exit 0
      ;;
  esac
  if [ $# -eq 0 ]; then
    if is_interactive; then
      interactive_menu
      exit 0
    fi
    log "非交互模式：执行默认条目 $DEFAULT_AGENT"
    set -- "$DEFAULT_AGENT"
  fi
  local i
  for i in "$@"; do
    run_item "$i"
  done
  log "完成。"
}
