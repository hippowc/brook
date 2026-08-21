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
  local var t note
  var="TARGET_$(os)_$(arch)"
  t="$(eval "printf '%s' \"\${$var:-}\"")"
  if [ -z "$t" ]; then
    note="$(eval "printf '%s' \"\${NOTE_$(os)_$(arch):-\${NOTE_$(os):-}}\"")"
    if [ -n "$note" ]; then
      die "上游未提供 $(os)-$(arch) 的发行包：$note"
    fi
    die "上游未提供 $(os)-$(arch) 的发行包（该工具可能不支持此平台；如确属映射遗漏，补 tools/$tool/tool.conf 的 $var）"
  fi
  echo "$t"
}

render_asset_pattern() {
  # 占位符替换用 sed 实现（bash ${var//pat/} 对花括号模式解析不可靠）
  printf '%s' "$1" | sed -e "s/{{TAG}}/$2/g" -e "s/{{TARGET}}/$3/g"
}

render_asset() {
  render_asset_pattern "$ASSET" "$1" "$2"
}

installed_tag_of() {
  local tool="$1"
  [ -f "$BROOK_META_DIR/$tool" ] || return 0
  sed -n 's/^tag=//p' "$BROOK_META_DIR/$tool"
}

binaries_present() {
  local tool="$1" b
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/$tool/tool.conf"
  for b in ${BINARIES:-}; do
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
    [ "$expect" = "$actual" ] || die "sha256 校验失败（expect=$expect actual=${actual}）"
    log "sha256 校验通过"
  else
    warn "无法获取 .sha256 旁路文件，跳过校验"
  fi
}

# 压缩类型按资产名后缀判定（兜底候选可能与主映射格式不同）
detect_archive_type() {
  case "$1" in
    *.tar.gz|*.tgz) echo tar.gz ;;
    *.tar.xz|*.txz) echo tar.xz ;;
    *.zip)          echo zip ;;
    *.zst)          echo zst ;;
    *)              echo "${ARCHIVE:-tar.gz}" ;;
  esac
}

extract_archive() {
  local tmp="$1" asset="$2" atype first b
  atype="$(detect_archive_type "$asset")"
  case "$atype" in
    tar.gz) tar -xzf "$tmp/archive" -C "$tmp" ;;
    tar.xz) tar -xJf "$tmp/archive" -C "$tmp" ;;
    zip) have unzip || die "解压 zip 需要 unzip，请先安装"; unzip -q "$tmp/archive" -d "$tmp" ;;
    zst)
      # 实测（2026-08-20）：codex 的 .zst 资产是 zstd 压缩的裸二进制，不是 tar
      have zstd || die "解压 .zst 需要 zstd 工具"
      first=""
      for b in $BINARIES; do first="$b"; break; done
      zstd -dc "$tmp/archive" > "$tmp/$first"
      chmod +x "$tmp/$first"
      ;;
    raw)
      # 资产本身就是裸二进制（如 jq、yt-dlp），无需解压
      first=""
      for b in $BINARIES; do first="$b"; break; done
      cp "$tmp/archive" "$tmp/$first"
      chmod +x "$tmp/$first"
      ;;
    *) die "不支持的压缩类型: $atype" ;;
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
  printf 'tag=%s\ndate=%s\nrepo=%s\n' "$tag" "$(date '+%Y-%m-%d %H:%M:%S')" "${REPO:-}" > "$BROOK_META_DIR/$tool"
}

# 候选链全部 miss 时：枚举 release 真实资产，按 target 三元组筛选
_fallback_from_release_list() {
  local tag="$1" target="$2" names cands n i c pick
  warn "映射的资产均不存在，枚举该 release 的真实资产列表..."
  names="$(curl -fsSL --connect-timeout 10 "https://api.github.com/repos/$REPO/releases/tags/$tag" 2>/dev/null \
    | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' || true)"
  if [ -z "$names" ]; then
    warn "无法获取资产列表（GitHub API 不可达）"
    return 1
  fi
  cands="$(printf '%s\n' "$names" | grep -F "$target" \
    | grep -E '\.(tar\.gz|tgz|tar\.xz|txz|zip|zst)$' || true)"
  n="$(printf '%s\n' "$cands" | grep -c . || true)"
  if [ "$n" = 0 ]; then
    warn "该 release 没有 $target 平台的资产，完整列表："
    printf '%s\n' "$names" | sed 's/^/    /'
    return 1
  elif [ "$n" = 1 ]; then
    chosen="$cands"
    warn "上游命名疑似变化：自动选用 '$chosen'（建议更新 registry 映射）"
    return 0
  fi
  echo "存在多个候选资产，请选择：" >&2
  i=1
  while IFS= read -r c; do
    printf '  %d) %s\n' "$i" "$c" >&2
    i=$((i+1))
  done <<EOF_CANDS
$cands
EOF_CANDS
  if [ -t 0 ]; then
    ask pick "输入编号" "1"
    chosen="$(printf '%s\n' "$cands" | sed -n "${pick}p")"
    [ -n "$chosen" ] || return 1
    warn "已选用 '$chosen'（建议更新 registry 映射）"
    return 0
  fi
  warn "非交互模式无法选择，请用 --version 指定版本或更新 registry 映射"
  return 1
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
    log "$tool 已安装（${tag}），跳过（--force 可强制重装）"
    return 0
  fi
  target="$(target_of)"
  # 有的项目 tag 带 v 前缀但资产名不带（如 zoxide v0.10.0 → zoxide-0.10.0-*）
  local tag_use="$tag"
  if [ "${ASSET_STRIP_V:-0}" = 1 ]; then tag_use="${tag#v}"; fi
  # 候选链：主映射 + 预置兜底候选（ASSET_FALLBACKS，均为实测存在的资产格式）
  local candidates="$ASSET ${ASSET_FALLBACKS:-}"
  local pat code chosen=""
  tmp="$(mktemp -d)"
  for pat in $candidates; do
    asset="$(render_asset_pattern "$pat" "$tag_use" "$target")"
    url="$(proxy_apply "https://github.com/$REPO/releases/download/$tag/$asset")"
    log "下载 $url"
    code="$(curl -fL --retry 1 --progress-bar -o "$tmp/archive" -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [ "$code" = "200" ] && [ -s "$tmp/archive" ]; then
      chosen="$asset"
      if [ "$pat" != "$ASSET" ]; then
        warn "主映射资产缺失，使用兜底候选：${asset}（建议更新 registry 映射）"
      fi
      break
    fi
    rm -f "$tmp/archive"
    if [ "$code" = "404" ] || [ "$code" = "403" ]; then
      warn "资产不存在：$asset"
      continue
    fi
    rm -rf "$tmp"
    die "下载失败（HTTP ${code}；国内网络可加 --proxy，brook proxies 查看预设）"
  done
  # 所有候选均缺失：枚举该 release 的真实资产列表，按平台筛选
  if [ -z "$chosen" ]; then
    _fallback_from_release_list "$tag" "$target" || { rm -rf "$tmp"; return 1; }
    url="$(proxy_apply "https://github.com/$REPO/releases/download/$tag/$chosen")"
    log "下载 $url"
    code="$(curl -fL --retry 1 --progress-bar -o "$tmp/archive" -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [ "$code" != "200" ] || [ ! -s "$tmp/archive" ]; then
      rm -rf "$tmp"
      die "下载失败（HTTP ${code}）"
    fi
  fi
  verify_checksum "$tmp" "$url"
  extract_archive "$tmp" "$chosen"
  install_binaries "$tmp"
  rm -rf "$tmp"
  save_meta "$tool" "$tag"
  ensure_bin_path
  log "已安装 ${tool}（${tag}）→ $BROOK_BIN_DIR"
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
    log "已是最新版（${current}）"
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
    echo "安装:    ✓ ${tag}（$(sed -n 's/^date=//p' "$BROOK_META_DIR/$tool")）"
  else
    echo "安装:    ✗ 未安装（brook install $tool）"
  fi
  for b in ${BINARIES:-}; do
    if [ -x "$BROOK_BIN_DIR/$b" ]; then
      echo "二进制:  ✓ $BROOK_BIN_DIR/$b"
    else
      echo "二进制:  ✗ $b 不在 $BROOK_BIN_DIR"
    fi
  done
  _show_config_status "$tool"
  if [ -f "$BROOK_HOME/tools/$tool/usage.md" ]; then
    echo "用法:    brook usage $tool（常见用法速查）"
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
