# 配置实践：生成服务端配置（本机做出口服务器时用）
# 写 ~/.config/shadowsocks-rust/server.json（与 client 配置互不覆盖）

config_desc() { echo "生成服务端配置：端口/密码 → server.json（本机当服务器时用）"; }

config_run() {
  local cfg="$HOME/.config/shadowsocks-rust/server.json"
  if [ -f "$cfg" ]; then
    log "配置已存在：${cfg}（如需修改请手动编辑）"
    return 0
  fi
  [ -t 0 ] || die "生成配置需要交互终端"
  local port method pw
  ask port "端口" "8388"
  ask method "加密方式" "aes-256-gcm"
  read -rsp "密码（不回显）: " pw; echo
  [ -n "$pw" ] || die "密码不能为空"
  mkdir -p "$(dirname "$cfg")"
  cat > "$cfg" <<CFG
{
  "server": "0.0.0.0",
  "server_port": $port,
  "password": "$pw",
  "method": "$method",
  "mode": "tcp_and_udp",
  "timeout": 7200
}
CFG
  chmod 600 "$cfg"
  log "服务端配置已写入：${cfg}（权限 600）"
  log "启动：ssserver -c $cfg"
  log "记得：防火墙放行端口（ufw allow $port/tcp && ufw allow $port/tcp）；常驻请用 systemd 托管"
}

config_status() {
  if [ -f "$HOME/.config/shadowsocks-rust/server.json" ]; then
    echo "配置[server]: ✓ ~/.config/shadowsocks-rust/server.json"
  else
    echo "配置[server]: ✗ 未生成（brook shadowsocks-rust config server）"
  fi
}
