# setup.sh —— 系统级配置实践（机器级，区别于工具级配置）
# system/<名字>.sh 约定：
#   setup_desc     一句话说明
#   setup_detect   本机适用性/现状（输出短语；以 inapplicable 开头 = 不适用）
#   setup_run      执行（实际执行需 root，运行器自动 sudo 重入；--dry-run 免 root）

setup_list() {
  local f name desc det
  echo "系统实践（机器级配置；执行：brook setup <名字> [--dry-run] [--mirror M]）："
  echo
  printf '%-14s %-36s %s\n' "名字" "说明" "本机"
  for f in "$BROOK_HOME"/system/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .sh)"
    # shellcheck source=/dev/null
    source "$f"
    desc="$(setup_desc 2>/dev/null || true)"
    if declare -f setup_detect >/dev/null; then
      det="$(setup_detect 2>/dev/null || echo '?')"
    else
      det="?"
    fi
    printf '%-14s %-36s %s\n' "$name" "$desc" "$det"
    unset -f setup_desc setup_detect setup_run 2>/dev/null || true
  done
  echo
  echo "--mirror 可选：aliyun（默认）/ tsinghua / ustc（yum 仅 aliyun/tsinghua）"
}

run_setup() {
  local name="$1"
  shift
  local f="$BROOK_HOME/system/$name.sh"
  [ -f "$f" ] || die "没有 '$name' 系统实践（brook setup 查看可用）"
  # shellcheck source=/dev/null
  source "$f"
  SETUP_MIRROR=""
  DRY_RUN=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --mirror)   SETUP_MIRROR="${2:-}"; shift 2 ;;
      --mirror=*) SETUP_MIRROR="${1#*=}"; shift ;;
      --dry-run)  DRY_RUN=1; shift ;;
      *) die "未知参数: $1" ;;
    esac
  done
  export SETUP_MIRROR DRY_RUN
  if declare -f setup_detect >/dev/null; then
    case "$(setup_detect 2>/dev/null || echo '?')" in
      inapplicable*) die "该实践不适用当前系统" ;;
    esac
  fi
  # dry-run 免 root；实际执行需 root，自动经 sudo 重入
  if [ "$DRY_RUN" != 1 ] && [ "$(id -u)" != 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      log "系统配置需要 root 权限，通过 sudo 提权（会要求输入密码）"
      exec sudo bash "$BROOK_HOME/brook" setup "$name" ${SETUP_MIRROR:+--mirror "$SETUP_MIRROR"}
    fi
    die "当前非 root 且无 sudo：请用 root 运行"
  fi
  setup_run
}
