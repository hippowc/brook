# shadowsocks-rust 配置最佳实践：
#   1. 交互式生成配置（server/client）→ ~/.config/shadowsocks-rust/config.json
#   2. 安装 sson/ssoff 一键开关到 shell rc：
#      sson  = 启动 sslocal + 设置代理环境变量（当前 shell 生效）
#      ssoff = 停止 sslocal + 清除环境变量
# 注意：环境变量只在当前 shell 生效，新终端需再跑一次 sson（这是 shell 的本质，非缺陷）

shadowsocks_rust_config() {
  _ss_gen_config
  _ss_install_switch
}

_ss_gen_config() {
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
}

_ss_install_switch() {
  local rc
  rc="$(rc_file)"
  if grep -q "^sson()" "$rc" 2>/dev/null; then
    log "sson/ssoff 已安装于 $(basename "$rc")"
    return 0
  fi
  cat >> "$rc" <<'FUNCS'

# ── shadowsocks-rust 一键开关（brook 生成）──
sson() {
  pgrep -x sslocal >/dev/null || nohup sslocal -c ~/.config/shadowsocks-rust/config.json >/tmp/sslocal.log 2>&1 &
  local p=socks5://127.0.0.1:1080 n=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8
  export ALL_PROXY=$p all_proxy=$p http_proxy=$p https_proxy=$p HTTP_PROXY=$p HTTPS_PROXY=$p no_proxy=$n NO_PROXY=$n
  echo "proxy on. 日志: tail -f /tmp/sslocal.log"
}
ssoff() {
  pkill -x sslocal 2>/dev/null
  unset ALL_PROXY all_proxy http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
  echo "proxy off."
}
FUNCS
  log "sson/ssoff 已写入 $rc（source 后生效）"
  log "  sson = 起 sslocal + 设代理环境变量；ssoff = 停 + 清环境变量"
}

shadowsocks_rust_config_status() {
  if [ -f "$HOME/.config/shadowsocks-rust/config.json" ]; then
    echo "配置:    ✓ ~/.config/shadowsocks-rust/config.json"
  else
    echo "配置:    ✗ 未生成（brook shadowsocks-rust config）"
  fi
  if grep -q "^sson()" "$(rc_file)" 2>/dev/null; then
    echo "开关:    ✓ sson/ssoff 已装（source $(rc_file) 后可用）"
  else
    echo "开关:    ✗ sson/ssoff 未安装（brook shadowsocks-rust config）"
  fi
}
