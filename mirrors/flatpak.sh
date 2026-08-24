# flatpak.sh —— Flathub 应用源（flatpak）国内缓存
# flatpak 本体不归 brook 管（apt/dnf 等系统包管理器安装）；本条只管 flathub 远程源的切换。
# 国内镜像均为缓存：元数据定时同步、extra-data 文件仍回源站下载，需要与 flathub 有基本连通。
# root：system 远程的操作需要 root（脚本内部自动加 sudo）；user 远程不需要。

MIRROR_PROVIDERS="sjtug(默认) / ustc / official(恢复官方 dl.flathub.org)"

_FLATHUB_OFFICIAL="https://dl.flathub.org/repo"
_FLATHUB_FLATPAKREPO="https://dl.flathub.org/repo/flathub.flatpakrepo"

mirror_desc() { echo "Flathub 应用源（flatpak，国内缓存）"; }

# 找 flathub 远程：先 system 后 user；输出 "<scope> <url>"，无则空
_flathub_remote() {
  local url
  url="$(flatpak --system remotes --columns=name,url 2>/dev/null | awk '$1=="flathub"{print $2; exit}' || true)"
  if [ -n "$url" ]; then echo "system $url"; return 0; fi
  url="$(flatpak --user remotes --columns=name,url 2>/dev/null | awk '$1=="flathub"{print $2; exit}' || true)"
  if [ -n "$url" ]; then echo "user $url"; return 0; fi
  return 0
}

mirror_detect() {
  if [ "$(os)" = "macos" ]; then
    echo "inapplicable（flatpak 是 Linux 桌面技术，macOS 不适用）"
    return 0
  fi
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "inapplicable（flatpak 未安装：先用 apt/dnf 等系统包管理器安装）"
    return 0
  fi
  local r
  r="$(_flathub_remote)"
  if [ -n "$r" ]; then
    echo "适用（flathub 远程已存在）"
  else
    echo "适用（flathub 远程未添加）"
  fi
}

mirror_status() {
  command -v flatpak >/dev/null 2>&1 || { echo "-"; return 0; }
  local r url
  r="$(_flathub_remote)"
  if [ -z "$r" ]; then
    echo "✗ flathub 远程未添加"
    return 0
  fi
  url="${r#* }"
  case "$url" in
    *sjtug.sjtu.edu.cn*|*ustc.edu.cn*) echo "✓ 国内缓存（${r%% *}：${url}）" ;;
    *flathub.org*) echo "✗ 官方源（${r%% *}：${url}），建议切换国内缓存" ;;
    *) echo "✗ 自定义源（${r%% *}：${url}）" ;;
  esac
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-sjtug}" url
  case "$choice" in
    sjtug)    url="https://mirrors.sjtug.sjtu.edu.cn/flathub" ;;
    ustc)     url="https://mirrors.ustc.edu.cn/flathub" ;;
    official) url="$_FLATHUB_OFFICIAL" ;;
    *) die "未知源：${choice}（可选：sjtug / ustc / official）" ;;
  esac

  local r scope sudo_cmd=""
  r="$(_flathub_remote)"
  if [ -z "$r" ]; then
    # 无远程：先经官方 .flatpakrepo 添加（含 GPG 校验键），再改 URL
    if [ "$DRY_RUN" = 1 ]; then
      log "[dry-run] 将执行: flatpak remote-add --if-not-exists flathub $_FLATHUB_FLATPAKREPO"
      if [ "$choice" != "official" ]; then
        log "[dry-run] 将执行: flatpak remote-modify flathub --url=$url"
      fi
      return 0
    fi
    log "flathub 远程未添加，先添加（经官方 .flatpakrepo，含 GPG 校验键）"
    if ! flatpak remote-add --if-not-exists flathub "$_FLATHUB_FLATPAKREPO"; then
      die "添加 flathub 远程失败（非 root 可加 sudo 重试，或自行加 --user 按用户安装）"
    fi
    r="$(_flathub_remote)"
  fi
  scope="${r%% *}"
  if [ "$scope" = "system" ] && [ "$(id -u)" != 0 ]; then sudo_cmd="sudo"; fi

  local cur="${r#* }"
  if [ "$cur" = "$url" ]; then
    log "flathub（${scope}）已指向 ${url}，不做改动"
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将执行: ${sudo_cmd:+$sudo_cmd }flatpak --$scope remote-modify flathub --url=$url"
    return 0
  fi
  # shellcheck disable=SC2086
  ${sudo_cmd:+$sudo_cmd} flatpak --"$scope" remote-modify flathub --url="$url" || die "切换失败"
  log "flathub（${scope}）已切换 → $url"
  if [ "$choice" != "official" ]; then
    log "注意：国内镜像为缓存（extra-data 仍回源站下载），需与 flathub 有基本连通"
  fi
  return 0
}
