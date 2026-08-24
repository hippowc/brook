# yum —— yum/dnf 源（CentOS/Rocky/Alma/Fedora）
# 策略：备份 /etc/yum.repos.d/ → 注释 mirrorlist → baseurl 指向镜像 → makecache 验证
# 注意：按主流发行版通用配方实现，尚未经全量真机验证，首跑请 --dry-run 预览。

MIRROR_PROVIDERS="aliyun(默认) / tsinghua"
NEED_ROOT=1

mirror_desc() { echo "yum/dnf 源（CentOS/Rocky/Alma/Fedora，待真机验证）"; }

mirror_detect() {
  if [ -d /etc/yum.repos.d ] && { command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; }; then
    echo "适用"
  else
    echo "inapplicable（非 yum/dnf 系）"
  fi
}

mirror_status() {
  # 粗略判断：repo 文件中是否已指向国内镜像
  if grep -rqE 'baseurl=https?://mirrors\.(aliyun|tuna\.tsinghua|ustc)' /etc/yum.repos.d/ 2>/dev/null; then
    echo "✓ 已指向国内镜像"
  else
    echo "✗ 未配置国内镜像"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-aliyun}" base
  case "$choice" in
    aliyun)   base="https://mirrors.aliyun.com" ;;
    tsinghua) base="https://mirrors.tuna.tsinghua.edu.cn" ;;
    *) die "未知源：$choice（可选：aliyun / tsinghua）" ;;
  esac

  local bakdir="/etc/yum.repos.d.brook-bak"
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将备份 /etc/yum.repos.d/ → $bakdir/，并对所有 .repo："
    echo "    1) 注释 mirrorlist= 行"
    echo "    2) baseurl 改为 $base/<centos|rockylinux|almalinux|fedora>"
    return 0
  fi

  if [ ! -d "$bakdir" ]; then
    mkdir -p "$bakdir"
    cp -a /etc/yum.repos.d/. "$bakdir/"
    log "已备份 /etc/yum.repos.d/ → $bakdir/"
  else
    log "备份已存在：$bakdir（保留首次备份）"
  fi

  local f
  for f in /etc/yum.repos.d/*.repo; do
    [ -e "$f" ] || continue
    sed -i \
      -e 's|^mirrorlist=|#mirrorlist=|g' \
      -e 's|^#\?baseurl=http://mirror\.centos\.org|baseurl='"$base"'/centos|g' \
      -e 's|^#\?baseurl=https\?://vault\.centos\.org|baseurl='"$base"'/centos-vault|g' \
      -e 's|^#\?baseurl=https\?://dl\.rockylinux\.org/\$contentdir|baseurl='"$base"'/rockylinux|g' \
      -e 's|^#\?baseurl=https\?://dl\.almalinux\.org/\$contentdir|baseurl='"$base"'/almalinux|g' \
      -e 's|^#\?baseurl=https\?://download\.fedoraproject\.org/pub/fedora|baseurl='"$base"'/fedora|g' \
      "$f"
  done
  log "替换完成，验证缓存..."
  local pm
  pm="$(command -v dnf >/dev/null 2>&1 && echo dnf || echo yum)"
  if "$pm" makecache >/dev/null 2>&1; then
    log "完成，$pm makecache 通过"
  else
    warn "$pm makecache 有错误！回退：cp $bakdir/*.repo /etc/yum.repos.d/"
  fi
}
