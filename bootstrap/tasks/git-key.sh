# 任务：git-key —— 初始化 git 身份与 SSH 密钥
# 用途：让本用户能访问 GitHub（克隆私有仓库、推送等）。

git_key_desc() { echo "初始化 git 身份 + SSH 密钥（为访问 GitHub 做准备）"; }

git_key_status() {
  local s
  if [ -f "$HOME/.ssh/id_ed25519" ]; then s="✓ SSH 密钥已生成"; else s="✗ 无 SSH 密钥"; fi
  if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
    s="$s；✗ git 身份未配置"
  fi
  echo "$s"
}

git_key_run() {
  have git || die "未找到 git"

  # 1) git 身份
  local name email
  name="$(git config --global user.name || true)"
  if [ -z "$name" ]; then
    ask name "git user.name（如你的 GitHub 用户名）" ""
    [ -n "$name" ] || die "user.name 不能为空"
    git config --global user.name "$name"
  fi
  log "git user.name = $(git config --global user.name)"
  email="$(git config --global user.email || true)"
  if [ -z "$email" ]; then
    ask email "git user.email" ""
    [ -n "$email" ] || die "user.email 不能为空"
    git config --global user.email "$email"
  fi
  log "git user.email = $(git config --global user.email)"

  # 2) SSH 密钥
  local key="$HOME/.ssh/id_ed25519"
  if [ -f "$key" ]; then
    log "SSH 密钥已存在：$key（跳过生成）"
  else
    have ssh-keygen || die "未找到 ssh-keygen"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$name (brook)" -f "$key" -N ""
    log "已生成 SSH 密钥：$key"
  fi

  # 3) 公钥与后续步骤
  echo
  log "公钥内容（复制并添加到 GitHub → Settings → SSH and GPG keys）："
  echo "────────────────────────────────────────"
  cat "$key.pub"
  echo "────────────────────────────────────────"
  cat <<'HINT'
后续步骤：
  1. 把上面的公钥加到 GitHub → Settings → SSH and GPG keys
     （或目标仓库的 deploy key，按需勾选写权限）
  2. 添加后验证：ssh -T git@github.com
HINT
}
