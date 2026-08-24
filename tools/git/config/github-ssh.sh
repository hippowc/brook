# 配置实践：生成 SSH key（ed25519）并引导把公钥加到 GitHub
# 用法：brook config git github-ssh（防"忘记怎么配 GitHub 公钥"）

config_desc() { echo "生成 SSH key（ed25519）并引导添加公钥到 GitHub"; }

config_run() {
  local dir="$HOME/.ssh" key="$HOME/.ssh/id_ed25519"
  mkdir -p "$dir"
  chmod 700 "$dir"
  if [ -f "$key" ]; then
    log "已有 ${key}，跳过生成"
  else
    have ssh-keygen || die "缺 ssh-keygen（Linux: sudo apt-get install -y openssh-client；macOS: CLT 自带）"
    ssh-keygen -t ed25519 -N "" -f "$key" -C "github-$(hostname 2>/dev/null || echo localhost)" >/dev/null
    log "已生成 ${key}"
  fi
  echo
  echo "1) 把下面的公钥复制到 GitHub：Settings → SSH and GPG keys → New SSH key"
  cat "$key.pub"
  echo
  echo "2) 添加后验证（输出 Hi <用户名>! 即成功）："
  echo "   ssh -T git@github.com"
  echo
  if have pbcopy; then
    if pbcopy < "$key.pub" 2>/dev/null; then
      echo "（公钥已复制到剪贴板）"
    else
      echo "（未能复制到剪贴板，请手动复制上面的公钥）"
    fi
  elif have xclip; then
    if xclip -selection clipboard < "$key.pub" 2>/dev/null; then
      echo "（公钥已复制到剪贴板）"
    else
      echo "（xclip 无图形环境可用，请手动复制上面的公钥）"
    fi
  else
    echo "（未检测到 pbcopy/xclip，请手动复制上面这一行）"
  fi
}

config_status() {
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "配置[github-ssh]: ✓ key 已生成（$HOME/.ssh/id_ed25519）"
    echo "  公钥前缀: $(cut -c1-50 "$HOME/.ssh/id_ed25519.pub" 2>/dev/null)..."
  else
    echo "配置[github-ssh]: ✗ 未生成（brook config git github-ssh）"
  fi
}
