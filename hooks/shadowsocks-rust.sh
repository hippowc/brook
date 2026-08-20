# shadowsocks-rust 配置钩子：交互式生成 ~/.config/shadowsocks-rust/config.json
# 配置含密码，只写 ~/.config，不进任何仓库。

shadowsocks_rust_config() {
  local cfg="$HOME/.config/shadowsocks-rust/config.json"
  if [ -f "$cfg" ]; then
    log "配置已存在：$cfg（如需修改请手动编辑）"
    return 0
  fi
  [ -t 0 ] || die "生成配置需要交互终端"
  local role port method pw srv
  ask role "角色：server(s) 还是 client(c)？" "s"
  case "$role" in s|c) ;; *) die "角色只能是 s 或 c" ;; esac
  ask port "端口" "8388"
  ask method "加密方式" "aes-256-gcm"
  read -rsp "密码（不回显）: " pw; echo
  [ -n "$pw" ] || die "密码不能为空"
  mkdir -p "$(dirname "$cfg")"
  if [ "$role" = c ]; then
    ask srv "远程服务器地址（IP 或域名）" ""
    [ -n "$srv" ] || die "服务器地址不能为空"
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
  else
    cat > "$cfg" <<CFG
{
  "server": "0.0.0.0",
  "server_port": $port,
  "password": "$pw",
  "method": "$method"
}
CFG
  fi
  chmod 600 "$cfg"
  log "配置已写入：$cfg（权限 600）"
  if [ "$role" = c ]; then
    log "启动：sslocal -c $cfg（本地 SOCKS5 127.0.0.1:1080）"
  else
    log "启动：ssserver -c $cfg（记得放行防火墙端口 $port；常驻请自行配 systemd/launchd）"
  fi
}

shadowsocks_rust_config_status() {
  if [ -f "$HOME/.config/shadowsocks-rust/config.json" ]; then
    echo "配置:    ✓ ~/.config/shadowsocks-rust/config.json"
  else
    echo "配置:    ✗ 未配置（brook shadowsocks-rust config）"
  fi
}
