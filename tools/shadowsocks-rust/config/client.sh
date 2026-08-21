# 配置实践：生成客户端配置（服务器地址 / 端口 / 密码）
# 写 ~/.config/shadowsocks-rust/config.json（sson 开关用的就是这份）

config_desc() { echo "生成客户端配置：服务器地址/端口/密码 → config.json"; }

config_run() {
  local cfg="$HOME/.config/shadowsocks-rust/config.json"
  if [ -f "$cfg" ]; then
    log "配置已存在：${cfg}（如需修改请手动编辑）"
    return 0
  fi
  [ -t 0 ] || die "生成配置需要交互终端"
  local srv port method pw
  ask srv "服务器地址（IP 或域名）" ""
  [ -n "$srv" ] || die "服务器地址不能为空"
  ask port "端口" "8388"
  ask method "加密方式" "aes-256-gcm"
  read -rsp "密码（不回显）: " pw; echo
  [ -n "$pw" ] || die "密码不能为空"
  mkdir -p "$(dirname "$cfg")"
  cat > "$cfg" <<CFG
{
  "server": "$srv",
  "server_port": $port,
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "password": "$pw",
  "method": "$method"
}
CFG
  chmod 600 "$cfg"
  log "客户端配置已写入：${cfg}（权限 600）"
  log "下一步：brook shadowsocks-rust config switch（装 sson/ssoff 开关）"
}

config_status() {
  if [ -f "$HOME/.config/shadowsocks-rust/config.json" ]; then
    echo "配置[client]: ✓ ~/.config/shadowsocks-rust/config.json"
  else
    echo "配置[client]: ✗ 未生成（brook shadowsocks-rust config client）"
  fi
}
