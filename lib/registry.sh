# registry.sh —— 工具映射解析、版本解析、下载、解压、安装
#
# registry/<tool>.conf 字段：
#   DESC      一句话说明
#   REPO      owner/repo
#   ASSET     资产名模板，支持占位符 {{TAG}} {{TARGET}}
#   TARGET_<os>_<arch>   该平台的 target 三元组（os: linux/macos；arch: x86_64/arm64）
#   ARCHIVE   tar.gz | tar.xz | zip
#   BINARIES  要从压缩包安装的二进制名（空格分隔）
#   CHECKSUM  none | sha256-sidecar（官方提供 <资产>.sha256 旁路文件）

# 解析最新版 tag：优先 releases/latest 重定向（可走代理），失败回落 GitHub API
resolve_latest_tag() {
  local url loc tag api
  url="$(proxy_apply "https://github.com/$REPO/releases/latest")"
  loc="$(curl -fsSL -o /dev/null --max-redirs 5 -w '%{url_effective}' "$url" 2>/dev/null || true)"
  tag="$(printf '%s' "$loc" | sed -n 's#.*/releases/tag/\(.*\)$#\1#p')"
  if [ -z "$tag" ]; then
    api="$(curl -fsSL --connect-timeout 10 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
    tag="$api"
  fi
  echo "$tag"
}

target_of() {
  local var t
  var="TARGET_$(os)_$(arch)"
  t="$(eval "printf '%s' \"\${$var:-}\"")"
  [ -n "$t" ] || die "该工具没有 $(os)-$(arch) 的发行包映射（补 registry 里的 $var）"
  echo "$t"
}

render_asset() {
  # 占位符替换用 sed 实现（bash ${var//pat/} 对花括号模式解析不可靠）
  printf '%s' "$ASSET" | sed -e "s/{{TAG}}/$1/g" -e "s/{{TARGET}}/$2/g"
}

installed_tag_of() {
  local tool="$1"
  [ -f "$BROOK_META_DIR/$tool" ] || return 0
  sed -n 's/^tag=//p' "$BROOK_META_DIR/$tool"
}

binaries_present() {
  local tool="$1" b
  # shellcheck source=/dev/null
  source "$BROOK_HOME/registry/$tool.conf"
  for b in $BINARIES; do
    [ -x "$BROOK_BIN_DIR/$b" ] || return 1
  done
  return 0
}

verify_checksum() {
  local tmp="$1" url="$2" expect actual
  [ "${CHECKSUM:-none}" = "sha256-sidecar" ] || return 0
  if curl -fsSL "$url.sha256" -o "$tmp/asset.sha256" 2>/dev/null; then
    expect="$(awk '{print $1}' "$tmp/asset.sha256")"
    if have sha256sum; then
      actual="$(sha256sum "$tmp/archive" | awk '{print $1}')"
    else
      actual="$(shasum -a 256 "$tmp/archive" | awk '{print $1}')"
    fi
    [ "$expect" = "$actual" ] || die "sha256 校验失败（expect=$expect actual=$actual）"
    log "sha256 校验通过"
  else
    warn "无法获取 .sha256 旁路文件，跳过校验"
  fi
}

extract_archive() {
  local tmp="$1"
  case "${ARCHIVE:-tar.gz}" in
    tar.gz|tgz) tar -xzf "$tmp/archive" -C "$tmp" ;;
    tar.xz|txz) tar -xJf "$tmp/archive" -C "$tmp" ;;
    zip) have unzip || die "解压 zip 需要 unzip，请先安装"; unzip -q "$tmp/archive" -d "$tmp" ;;
    *) die "不支持的压缩类型: $ARCHIVE" ;;
  esac
}

install_binaries() {
  local tmp="$1" b bin
  mkdir -p "$BROOK_BIN_DIR"
  for b in $BINARIES; do
    bin="$(find "$tmp" -maxdepth 3 -type f -name "$b" | head -1)"
    # 有的 release 二进制带 target 后缀（如 codex-x86_64-unknown-linux-musl），前缀回退
    if [ -z "$bin" ]; then
      bin="$(find "$tmp" -maxdepth 3 -type f -name "$b-*" | head -1)"
    fi
    [ -n "$bin" ] || die "压缩包中未找到二进制: $b"
    install -m 0755 "$bin" "$BROOK_BIN_DIR/$b"
  done
}

save_meta() {
  local tool="$1" tag="$2"
  mkdir -p "$BROOK_META_DIR"
  printf 'tag=%s\ndate=%s\nrepo=%s\n' "$tag" "$(date '+%Y-%m-%d %H:%M:%S')" "$REPO" > "$BROOK_META_DIR/$tool"
}

do_install() {
  local tool="$1" tag target asset url tmp installed
  if [ "$TOOL_VERSION" = "latest" ]; then
    log "解析 $tool 最新版本..."
    tag="$(resolve_latest_tag)"
  else
    tag="$TOOL_VERSION"
  fi
  [ -n "$tag" ] || die "无法解析版本（网络问题可加 --proxy）"
  installed="$(installed_tag_of "$tool")"
  if [ "$installed" = "$tag" ] && [ "$FORCE" != 1 ] && binaries_present "$tool"; then
    log "$tool 已安装（$tag），跳过（--force 可强制重装）"
    return 0
  fi
  target="$(target_of)"
  asset="$(render_asset "$tag" "$target")"
  url="$(proxy_apply "https://github.com/$REPO/releases/download/$tag/$asset")"
  tmp="$(mktemp -d)"
  log "下载 $url"
  curl -fL --retry 2 --progress-bar "$url" -o "$tmp/archive" \
    || { rm -rf "$tmp"; die "下载失败（国内网络可加 --proxy，brook proxies 查看预设）"; }
  verify_checksum "$tmp" "$url"
  extract_archive "$tmp"
  install_binaries "$tmp"
  rm -rf "$tmp"
  save_meta "$tool" "$tag"
  ensure_bin_path
  log "已安装 $tool（$tag）→ $BROOK_BIN_DIR"
  if [ -f "$BROOK_HOME/hooks/$tool.sh" ]; then
    log "下一步：brook $tool config"
  fi
}

do_upgrade() {
  local tool="$1" latest current
  log "解析最新版本..."
  latest="$(resolve_latest_tag)"
  [ -n "$latest" ] || die "无法解析最新版本（网络问题可加 --proxy）"
  current="$(installed_tag_of "$tool")"
  if [ "$latest" = "$current" ] && binaries_present "$tool"; then
    log "已是最新版（$current）"
    return 0
  fi
  TOOL_VERSION="$latest"
  FORCE=1
  do_install "$tool"
}

do_status() {
  local tool="$1" tag b fn
  echo "工具:    $tool —— ${DESC:-}"
  echo "仓库:    ${REPO:-}"
  tag="$(installed_tag_of "$tool")"
  if [ -n "$tag" ]; then
    echo "安装:    ✓ $tag（$(sed -n 's/^date=//p' "$BROOK_META_DIR/$tool")）"
  else
    echo "安装:    ✗ 未安装（brook $tool install）"
  fi
  for b in ${BINARIES:-}; do
    if [ -x "$BROOK_BIN_DIR/$b" ]; then
      echo "二进制:  ✓ $BROOK_BIN_DIR/$b"
    else
      echo "二进制:  ✗ $b 不在 $BROOK_BIN_DIR"
    fi
  done
  fn="$(printf '%s' "$tool" | tr '-' '_')"
  if [ -f "$BROOK_HOME/hooks/$tool.sh" ]; then
    # shellcheck source=/dev/null
    source "$BROOK_HOME/hooks/$tool.sh"
    if declare -f "${fn}_config_status" >/dev/null; then "${fn}_config_status"; fi
  fi
}

do_remove() {
  local tool="$1" b
  for b in ${BINARIES:-}; do
    rm -f "$BROOK_BIN_DIR/$b"
  done
  rm -f "$BROOK_META_DIR/$tool"
  log "已移除 $tool 的二进制（配置文件未动，如需清理请手动）"
}
