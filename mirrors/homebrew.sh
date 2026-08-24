# homebrew —— Homebrew 国内镜像（写 rc 环境变量；安装/瓶子/仓库三条都要换）

MIRROR_PROVIDERS="tuna(默认) / ustc / aliyun"

mirror_desc() { echo "Homebrew 源（brew 安装/瓶子/仓库走国内镜像，写 rc）"; }

mirror_detect() {
  if command -v brew >/dev/null 2>&1; then
    echo "适用（brew 已安装）"
  else
    echo "inapplicable（brew 未安装：brook install brew）"
  fi
}

mirror_status() {
  local rc
  rc="$(rc_file)"
  if grep -q 'HOMEBREW_BOTTLE_DOMAIN' "$rc" 2>/dev/null; then
    echo "✓ 已配置（${rc}）"
  else
    echo "✗ 未配置（brook mirror homebrew apply）"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-tuna}" api bottle brew core
  case "$choice" in
    tuna)
      api="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
      bottle="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
      brew="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
      core="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
      ;;
    ustc)
      api="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
      bottle="https://mirrors.ustc.edu.cn/homebrew-bottles"
      brew="https://mirrors.ustc.edu.cn/brew.git"
      core="https://mirrors.ustc.edu.cn/homebrew-core.git"
      ;;
    aliyun)
      bottle="https://mirrors.aliyun.com/homebrew/homebrew-bottles"
      api="$bottle/api"
      brew="https://mirrors.aliyun.com/homebrew/brew.git"
      core="https://mirrors.aliyun.com/homebrew/homebrew-core.git"
      ;;
    *) die "未知源：${choice}（可选：tuna / ustc / aliyun）" ;;
  esac
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将写入 $(rc_file)：HOMEBREW_API_DOMAIN / BOTTLE / BREW_GIT_REMOTE / CORE_GIT_REMOTE"
    return 0
  fi
  append_rc "export HOMEBREW_API_DOMAIN=$api"
  append_rc "export HOMEBREW_BOTTLE_DOMAIN=$bottle"
  append_rc "export HOMEBREW_BREW_GIT_REMOTE=$brew"
  append_rc "export HOMEBREW_CORE_GIT_REMOTE=$core"
  log "已写入 $(rc_file)（新终端生效）"
}
