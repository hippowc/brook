# 配置实践：npm 国内镜像（npmmirror）

config_desc() { echo "设置 npm registry 为 npmmirror（需 node 已激活）"; }

config_run() {
  if ! command -v npm >/dev/null 2>&1; then
    die "npm 不可用：先 brook config fnm shell-init，source rc，再 fnm install <版本> && fnm use <版本>"
  fi
  npm config set registry https://registry.npmmirror.com
  log "已设置：npm registry=https://registry.npmmirror.com"
}

config_status() {
  if command -v npm >/dev/null 2>&1; then
    echo "配置[npm-mirror]: ✓ registry=$(npm config get registry)"
  else
    echo "配置[npm-mirror]: ✗ npm 未激活（先装并切换 node）"
  fi
}
