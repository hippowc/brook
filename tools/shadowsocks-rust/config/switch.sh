# 配置实践：安装 sson/ssoff 一键代理开关到 shell rc
#   sson  = 启动 sslocal + 设置代理环境变量（当前 shell 生效）
#   ssoff = 停止 sslocal + 清除环境变量
# 前提：client 配置存在（sson 读 config.json）

config_desc() { echo "安装 sson/ssoff 一键开关到 shell rc（前提：client 配置）"; }

config_run() {
  if [ ! -f "$HOME/.config/shadowsocks-rust/config.json" ]; then
    warn "尚无 client 配置：建议先 brook shadowsocks-rust config client"
  fi
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

config_status() {
  if grep -q "^sson()" "$(rc_file)" 2>/dev/null; then
    echo "配置[switch]: ✓ sson/ssoff 已装（source rc 后可用）"
  else
    echo "配置[switch]: ✗ 未安装（brook shadowsocks-rust config switch）"
  fi
}
