# 任务：shadowsocks —— 安装 shadowsocks-rust（ssserver/sslocal）并交互式生成配置
# 资产命名已实测（2026-08-19）：shadowsocks-<tag>.<triple>.tar.xz（附 .sha256），
# 如 shadowsocks-v1.24.0.x86_64-unknown-linux-musl.tar.xz。
# 配置含密码，只写 ~/.config，绝不进仓库。

SHADOWSOCKS_VERSION="${SHADOWSOCKS_VERSION:-latest}"

shadowsocks_desc() { echo "安装 shadowsocks-rust 并生成配置（server/client）"; }

shadowsocks_status() {
  if [ -x "$HOME/.local/bin/ssserver" ]; then
    echo "✓ 已安装"
  else
    echo "✗ 未安装"
  fi
}

shadowsocks_options() {
  ask SHADOWSOCKS_VERSION "shadowsocks-rust 版本（latest=最新发布）" "${SHADOWSOCKS_VERSION:-latest}"
}

_ss_target() {
  case "$(os)-$(arch)" in
    linux-x86_64) echo "x86_64-unknown-linux-musl" ;;
    linux-arm64)  echo "aarch64-unknown-linux-musl" ;;
    macos-x86_64) echo "x86_64-apple-darwin" ;;
    macos-arm64)  echo "aarch64-apple-darwin" ;;
    *) die "shadowsocks: 无 $(os)-$(arch) 的发行包" ;;
  esac
}

_ss_install() {
  if [ -x "$HOME/.local/bin/ssserver" ] && [ -x "$HOME/.local/bin/sslocal" ]; then
    log "shadowsocks-rust 已安装：~/.local/bin（跳过）"
    return 0
  fi
  local tag url tmp
  if [ "$SHADOWSOCKS_VERSION" = "latest" ]; then
    tag="$(curl -fsSL --connect-timeout 10 https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
          | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
  else
    tag="$SHADOWSOCKS_VERSION"
  fi
  [ -n "$tag" ] || die "shadowsocks: 无法解析 release tag（需要网络）"
  url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/$tag/shadowsocks-$tag.$(_ss_target).tar.xz"
  if ! confirm "即将下载 shadowsocks-rust $tag（$(_ss_target)），继续？" y; then
    warn "已取消下载"
    return 1
  fi
  tmp="$(mktemp -d)"
  log "下载 $url"
  curl -fL --progress-bar "$url" -o "$tmp/ss.tar.xz" || die "shadowsocks: 下载失败"
  # sha256 校验（官方提供 .sha256 旁路文件）
  if curl -fsSL "$url.sha256" -o "$tmp/ss.sha256" 2>/dev/null; then
    local expect actual
    expect="$(awk '{print $1}' "$tmp/ss.sha256")"
    if have sha256sum; then
      actual="$(sha256sum "$tmp/ss.tar.xz" | awk '{print $1}')"
    else
      actual="$(shasum -a 256 "$tmp/ss.tar.xz" | awk '{print $1}')"
    fi
    [ "$expect" = "$actual" ] || die "shadowsocks: sha256 校验失败（expect=$expect actual=$actual）"
    log "sha256 校验通过"
  else
    warn "无法获取 .sha256，跳过校验"
  fi
  tar -xJf "$tmp/ss.tar.xz" -C "$tmp"
  local s bin
  ensure_user_bin_path
  for s in ssserver sslocal; do
    bin="$(find "$tmp" -maxdepth 2 -type f -name "$s" | head -1)"
    [ -n "$bin" ] || die "shadowsocks: 压缩包中未找到 $s"
    install -m 0755 "$bin" "$HOME/.local/bin/$s"
  done
  rm -rf "$tmp"
  log "已安装 ssserver/sslocal（$tag）→ ~/.local/bin"
}

_ss_configure() {
  local cfg="$HOME/.config/shadowsocks-rust/config.json"
  if [ -f "$cfg" ]; then
    log "配置已存在：$cfg（跳过生成；如需修改请手动编辑）"
    return 0
  fi
  echo
  log "生成配置（含密码，只写入 ~/.config，不进仓库）"
  local role port method pw srv
  ask role "角色：server(s) 还是 client(c)？" "s"
  case "$role" in s|c) ;; *) die "角色只能是 s 或 c" ;; esac
  ask port "端口" "8388"
  ask method "加密方式" "aes-256-gcm"
  if is_interactive; then
    read -rsp "密码（不回显）: " pw; echo
  else
    die "非交互模式无法输入密码，请先交互运行一次生成配置"
  fi
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
    log "启动：sslocal -c $cfg"
    log "本地 SOCKS5 代理：127.0.0.1:1080（如 curl --socks5-hostname 127.0.0.1:1080 ...）"
  else
    log "启动：ssserver -c $cfg"
    log "服务端注意：记得放行防火墙端口 $port（如 ufw allow $port/tcp）；常驻请自行配 systemd（Linux）或 launchd（macOS）"
  fi
}

shadowsocks_run() {
  _ss_install
  _ss_configure
}
