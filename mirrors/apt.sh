# apt —— apt 源（Ubuntu/Debian）
# 支持传统格式（/etc/apt/sources.list）与 deb822（Ubuntu 24.04+ 的 *.sources）；
# 改前备份（*.brook-bak，只备份首次）；已是国内源则不动；切换后 apt update 验证。

MIRROR_PROVIDERS="aliyun(默认) / tsinghua / ustc"
NEED_ROOT=1

mirror_desc() { echo "apt 源（Ubuntu/Debian，含 24.04+ deb822 格式）"; }

_apt_current_host() {
  # *.sources 在 24.04 之前不存在，通配无匹配不能让 pipefail 杀掉调用者
  local line
  line="$(grep -hE '^(deb |URIs:)' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null | head -1 || true)"
  printf '%s' "$line" | sed -E 's#.*https?://([^/ ]+).*#\1#'
}

_apt_is_cn() {
  case "$1" in
    *aliyun*|*tsinghua*|*ustc*|*huawei*|*tencent*|*163.com) return 0 ;;
    *) return 1 ;;
  esac
}

mirror_detect() {
  if [ ! -f /etc/os-release ] || ! grep -qE '^ID=(ubuntu|debian)$' /etc/os-release; then
    echo "inapplicable（非 Ubuntu/Debian）"
    return 0
  fi
  local host
  host="$(_apt_current_host)"
  if _apt_is_cn "$host"; then
    echo "已是国内源（$host）"
  else
    echo "当前：${host:-官方源}（建议切换）"
  fi
}

mirror_status() {
  local host
  host="$(_apt_current_host)"
  if _apt_is_cn "$host"; then
    echo "✓ 国内源（$host）"
  else
    echo "✗ 当前：${host:-官方源}（建议切换）"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-aliyun}" base
  case "$choice" in
    aliyun)   base="https://mirrors.aliyun.com" ;;
    tsinghua) base="https://mirrors.tuna.tsinghua.edu.cn" ;;
    ustc)     base="https://mirrors.ustc.edu.cn" ;;
    *) die "未知源：$choice（可选：aliyun / tsinghua / ustc）" ;;
  esac

  local host
  host="$(_apt_current_host)"
  if _apt_is_cn "$host"; then
    log "已使用国内源（$host），不做改动"
    return 0
  fi

  # shellcheck source=/dev/null
  . /etc/os-release
  local distro="$ID" codename="${VERSION_CODENAME:-}"
  [ -n "$codename" ] || die "无法确定系统代号（VERSION_CODENAME 为空）"

  local deb822="/etc/apt/sources.list.d/${distro}.sources"
  if [ "$distro" = "ubuntu" ] && [ -f "$deb822" ]; then
    _apt_write_deb822 "$deb822" "$base" "$codename"
  else
    _apt_write_classic "$base" "$distro" "$codename"
  fi

  if [ "$DRY_RUN" = 1 ]; then
    return 0
  fi
  log "验证：apt update"
  if apt-get update >/dev/null 2>&1; then
    log "完成，apt update 通过"
  else
    warn "apt update 有错误！如需回退：把 *.brook-bak 备份还原到原文件"
  fi
}

_apt_write_classic() {
  local base="$1" distro="$2" codename="$3"
  local target="/etc/apt/sources.list" content
  if [ "$distro" = "ubuntu" ]; then
    content="deb $base/ubuntu/ $codename main restricted universe multiverse
deb $base/ubuntu/ $codename-updates main restricted universe multiverse
deb $base/ubuntu/ $codename-backports main restricted universe multiverse
deb $base/ubuntu/ $codename-security main restricted universe multiverse"
  else
    content="deb $base/debian/ $codename main contrib non-free non-free-firmware
deb $base/debian/ $codename-updates main contrib non-free non-free-firmware
deb $base/debian-security/ $codename-security main contrib non-free non-free-firmware"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将备份 $target → $target.brook-bak，并写入："
    printf '%s\n' "$content" | sed 's/^/    /'
    return 0
  fi
  [ -f "$target.brook-bak" ] || cp "$target" "$target.brook-bak"
  printf '%s\n' "$content" > "$target"
  log "已写入 $target（备份：$target.brook-bak）"
}

_apt_write_deb822() {
  local target="$1" base="$2" codename="$3"
  local content="Types: deb
URIs: $base/ubuntu/
Suites: $codename $codename-updates $codename-backports $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将备份 $target → $target.brook-bak，并写入："
    printf '%s\n' "$content" | sed 's/^/    /'
    return 0
  fi
  [ -f "$target.brook-bak" ] || cp "$target" "$target.brook-bak"
  printf '%s\n' "$content" > "$target"
  log "已写入 $target（备份：$target.brook-bak）"
}
