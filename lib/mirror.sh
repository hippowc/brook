# mirror.sh —— 包管理器源/镜像管理
# mirrors/<名字>.sh 约定：
#   MIRROR_PROVIDERS   可用源说明（展示用字符串）
#   NEED_ROOT          1 = apply 需要 root（运行器自动 sudo 重入；--dry-run 免 root）
#   mirror_desc        一句话说明
#   mirror_detect      适用性：输出以 inapplicable 开头 = 不适用
#   mirror_status      当前状态（✓/✗ 开头）
#   mirror_apply       应用配置（尊重 $DRY_RUN 与 $MIRROR_CHOICE）

mirror_list() {
  local f name
  echo "包源/镜像（brook mirror <名字> 看状态；brook mirror <名字> apply 配置）："
  echo
  printf '%-10s %-26s %-32s %s\n' "名字" "适用性" "当前状态" "可用源"
  for f in "$BROOK_HOME"/mirrors/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .sh)"
    (
      # shellcheck source=/dev/null
      source "$f"
      applies="$(mirror_detect 2>/dev/null || echo '?')"
      case "$applies" in
        inapplicable*) status="-" ;;
        *) status="$(mirror_status 2>/dev/null || echo '?')" ;;
      esac
      printf '%-10s %-26s %-32s %s\n' "$name" "$applies" "$status" "${MIRROR_PROVIDERS:-固定}"
    )
  done
  echo
  echo "分清三种代理：brook mirror 管包源；brook proxies 管 brook 自身下载加速；"
  echo "sson/ssoff（流量代理）属于 shadowsocks-rust 工具的配置实践。"
}

mirror_run() {
  local name="$1"
  shift
  local f="$BROOK_HOME/mirrors/$name.sh"
  [ -f "$f" ] || die "没有 '$name' 镜像（brook mirror 查看可用）"
  # shellcheck source=/dev/null
  source "$f"
  local action="${1:-status}"
  [ $# -ge 1 ] && shift
  case "$action" in
    status)
      echo "镜像:    $name —— $(mirror_desc)"
      echo "适用:    $(mirror_detect 2>/dev/null || echo '?')"
      echo "状态:    $(mirror_status 2>/dev/null || echo '?')"
      echo "可用源:  ${MIRROR_PROVIDERS:-固定}"
      ;;
    apply)
      DRY_RUN=0
      MIRROR_CHOICE=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --dry-run)  DRY_RUN=1; shift ;;
          --mirror)   MIRROR_CHOICE="${2:-}"; shift 2 ;;
          --mirror=*) MIRROR_CHOICE="${1#*=}"; shift ;;
          *) die "未知参数: $1" ;;
        esac
      done
      export DRY_RUN MIRROR_CHOICE
      local applies
      applies="$(mirror_detect 2>/dev/null || echo '?')"
      case "$applies" in
        inapplicable*) die "该镜像不适用当前系统：${applies#inapplicable}" ;;
      esac
      if [ "${NEED_ROOT:-0}" = 1 ] && [ "$DRY_RUN" != 1 ] && [ "$(id -u)" != 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
          log "系统源配置需要 root 权限，通过 sudo 提权（会要求输入密码）"
          exec sudo bash "$BROOK_HOME/brook" mirror "$name" apply ${MIRROR_CHOICE:+--mirror "$MIRROR_CHOICE"}
        fi
        die "当前非 root 且无 sudo：请用 root 运行"
      fi
      mirror_apply
      ;;
    *) die "未知操作 '$action'（可用：status / apply）" ;;
  esac
}
