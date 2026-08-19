#!/usr/bin/env bash
# brook —— agent 环境配置器
#
# 用法（全新机器，一行）：
#   curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh -o /tmp/brook-install.sh && bash /tmp/brook-install.sh
#
# 做的事：克隆本框架到 ~/.brook，然后进入交互式初始化向导。
# 可覆盖环境变量：BROOK_REPO（框架仓库地址）、BROOK_DIR（安装位置，默认 ~/.brook）
set -euo pipefail

BROOK_REPO="${BROOK_REPO:-https://github.com/hippowc/brook.git}"
BROOK_DIR="${BROOK_DIR:-$HOME/.brook}"

echo "brook —— agent 环境配置器"
echo "  框架仓库: $BROOK_REPO"
echo "  安装位置: $BROOK_DIR"
echo
command -v git >/dev/null 2>&1 || { echo "请先安装 git"; exit 1; }

if [ -d "$BROOK_DIR/.git" ]; then
  echo "已安装，更新..."
  git -C "$BROOK_DIR" pull --ff-only || echo "（更新失败，先用本地版本）"
else
  if [ -e "$BROOK_DIR" ]; then
    echo "$BROOK_DIR 已存在且不是 git 仓库，为避免覆盖已中止"
    exit 1
  fi
  git clone "$BROOK_REPO" "$BROOK_DIR"
fi

echo
echo "进入初始化向导（以后随时可运行 $BROOK_DIR/bootstrap.sh 重新进入）..."
exec bash "$BROOK_DIR/bootstrap.sh"
