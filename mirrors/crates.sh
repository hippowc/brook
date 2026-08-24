# crates —— Rust 包源（cargo），写 ~/.cargo/config.toml

MIRROR_PROVIDERS="rsproxy(默认) / ustc / tuna"

mirror_desc() { echo "Rust 包源（cargo，写 ~/.cargo/config.toml）"; }

mirror_detect() {
  if command -v cargo >/dev/null 2>&1 || [ -d "$HOME/.cargo" ]; then
    echo "适用（cargo/~/.cargo 存在）"
  else
    echo "inapplicable（无 cargo 且无 ~/.cargo：brook install rustup）"
  fi
}

mirror_status() {
  local cfg="$HOME/.cargo/config.toml"
  if [ -f "$cfg" ] && grep -q 'crates-io' "$cfg" 2>/dev/null; then
    echo "✓ 已配置国内源（${cfg}）"
  else
    echo "✗ 未配置（brook mirror crates apply）"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-rsproxy}" name url
  case "$choice" in
    rsproxy) name="rsproxy-sparse"; url="https://rsproxy.cn/index/" ;;
    ustc)    name="ustc-sparse";    url="sparse+https://mirrors.ustc.edu.cn/crates.io-index/" ;;
    tuna)    name="tuna-sparse";    url="sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/" ;;
    *) die "未知源：${choice}（可选：rsproxy / ustc / tuna）" ;;
  esac
  local cfg="$HOME/.cargo/config.toml"
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将写入 ${cfg}："
    printf '  [source.crates-io] replace-with = "%s"\n  [source.%s] registry = "%s"\n' "$name" "$name" "$url"
    return 0
  fi
  mkdir -p "$HOME/.cargo"
  cat > "$cfg" <<CRATES
[source.crates-io]
replace-with = "$name"

[source.$name]
registry = "$url"
CRATES
  log "已写入 ${cfg}（cargo 下一次自动生效）"
}
