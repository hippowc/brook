# 配置实践：Go 模块国内镜像（goproxy.cn）

config_desc() { echo "设置 GOPROXY=goproxy.cn（国内模块下载加速，需 go 已激活）"; }

config_run() {
  if ! command -v go >/dev/null 2>&1; then
    die "go 命令不可用：先 brook config g shell-init，source rc，再 g install <版本> && g use <版本>"
  fi
  go env -w GOPROXY=https://goproxy.cn,direct
  log "已设置：GOPROXY=https://goproxy.cn,direct"
}

config_status() {
  if command -v go >/dev/null 2>&1; then
    echo "配置[goproxy]: ✓ GOPROXY=$(go env GOPROXY)"
  else
    echo "配置[goproxy]: ✗ go 未激活（先装并切换工具链）"
  fi
}
