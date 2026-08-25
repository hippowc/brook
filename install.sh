#!/usr/bin/env bash
# brook 安装器：克隆到 ~/.brook，把 brook 命令链接到 ~/.local/bin
# curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
# 国内：curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
set -euo pipefail

BROOK_REPO="${BROOK_REPO:-https://github.com/hippowc/brook.git}"
BROOK_DIR="${BROOK_DIR:-$HOME/.brook}"
BIN_DIR="${BROOK_BIN_DIR:-$HOME/.local/bin}"

echo "brook 安装器（GitHub release 二进制安装器）"
command -v git >/dev/null 2>&1 || { echo "请先安装 git"; exit 1; }
if [ "$(uname -s)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
  echo "提示：macOS 未检测到 Command Line Tools（含 git）"
  echo "      接下来如弹出系统安装对话框，点安装，完成后重新运行本脚本"
fi

if [ -d "$BROOK_DIR/.git" ]; then
  git -C "$BROOK_DIR" pull --ff-only || echo "（更新失败，先用本地版本）"
else
  if [ -e "$BROOK_DIR" ]; then
    echo "$BROOK_DIR 已存在且不是 git 仓库，为避免覆盖已中止"
    exit 1
  fi
  git clone "$BROOK_REPO" "$BROOK_DIR"
fi

mkdir -p "$BIN_DIR"
ln -sf "$BROOK_DIR/brook" "$BIN_DIR/brook"

rc="$HOME/.bashrc"
case "${SHELL:-/bin/bash}" in *zsh) rc="$HOME/.zshrc" ;; esac
touch "$rc"
if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$rc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
  echo "PATH 已写入 $rc"
fi

echo
echo "完成。开始使用："
echo "  source $rc    （或重新登录）"
echo "  brook list    （查看可安装的工具）"
echo "  brook install codex --proxy gh-proxy && brook config codex bailian"
if [ "$(uname -s)" = "Darwin" ]; then
  echo "提示：GitHub 不发二进制的工具（eza/mpv 等）可先 brook install brew，再用 brew 安装"
fi
