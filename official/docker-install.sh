#!/usr/bin/env bash
# brook 内置 Docker CE 安装脚本（国内镜像仓库直装）。
# 背景：get.docker.com 在国内不可达，这里用 TUNA/USTC/阿里云 docker-ce 仓库 apt/yum 直装。
# 换源：DOCKER_MIRROR=tuna|ustc|aliyun（默认 tuna）
# 预览：bash official/docker-install.sh --dry-run（无需 root）
set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

mirror="${DOCKER_MIRROR:-tuna}"
case "$mirror" in
  tuna)   base="https://mirrors.tuna.tsinghua.edu.cn" ;;
  ustc)   base="https://mirrors.ustc.edu.cn" ;;
  aliyun) base="https://mirrors.aliyun.com" ;;
  *) echo "未知源：${mirror}（可用 tuna / ustc / aliyun）" >&2; exit 1 ;;
esac

os_id=""; codename=""
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  codename="${VERSION_CODENAME:-}"
fi

require_root() {
  [ "$(id -u)" = 0 ] || { echo "需要 root（brook 会经 sudo 执行）" >&2; exit 1; }
}

if command -v apt-get >/dev/null 2>&1; then
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  gpg_url="$base/docker-ce/linux/$os_id/gpg"
  repo="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] $base/docker-ce/linux/$os_id $codename stable"
  if [ "$DRY" = 1 ]; then
    echo "平台: apt（${os_id} ${codename} ${arch}）"
    echo "源:   ${base}"
    echo "将执行："
    echo "  install -d -m 0755 /etc/apt/keyrings"
    echo "  curl -fsSL ${gpg_url} | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg"
    echo "  echo '${repo}' > /etc/apt/sources.list.d/docker.list"
    echo "  apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    exit 0
  fi
  require_root
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  command -v gpg  >/dev/null 2>&1 || { apt-get update -qq; apt-get install -y gnupg ca-certificates; }
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "$gpg_url" | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "$repo" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
  repo_file=/etc/yum.repos.d/docker-ce.repo
  if [ "$DRY" = 1 ]; then
    echo "平台: dnf/yum"
    echo "源:   ${base}"
    echo "将执行："
    echo "  写入 ${repo_file}（baseurl=${base}/docker-ce/linux/centos/.../stable）"
    echo "  yum/dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    exit 0
  fi
  require_root
  cat > "$repo_file" <<REPO
[docker-ce-stable]
name=Docker CE Stable
baseurl=${base}/docker-ce/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=${base}/docker-ce/linux/centos/gpg
REPO
  if command -v dnf >/dev/null 2>&1; then
    dnf makecache && dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    yum makecache && yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

else
  echo "不支持当前系统：未检测到 apt-get/dnf/yum（macOS 请用 Docker Desktop：brew install --cask docker）" >&2
  exit 1
fi

echo "Docker 安装完成。把当前用户加入 docker 组后重登生效：sudo usermod -aG docker \$USER"
