# codex 适配器 —— OpenAI 开源终端编码 agent（Rust 单二进制）
# 支持 Linux / macOS，x86_64 / arm64。
# 资产命名已实测（2026-08-19）：codex-<triple>.tar.gz，
# linux: codex-x86_64-unknown-linux-musl.tar.gz（92MB）
# macos: codex-aarch64-apple-darwin.tar.gz（81MB）
# 国内网络慢时：设 CODEX_ASSET_URL 指向镜像/代理的完整资产 URL。

CODEX_VERSION="${CODEX_VERSION:-latest}"   # 可 pin：CODEX_VERSION=rust-v0.148.0

codex_desc() { echo "安装并配置 codex（OpenAI 开源终端 agent）"; }

codex_status() {
  if [ -x "$HOME/.local/bin/codex" ]; then
    echo "✓ 已安装（用户级）"
  elif have codex; then
    echo "△ 仅系统级安装（$(command -v codex)）"
  else
    echo "✗ 未安装"
  fi
}

codex_options() {
  ask CODEX_VERSION "codex 版本（latest=最新发布）" "${CODEX_VERSION:-latest}"
  local u=""
  ask u "下载地址（留空=GitHub 官方源；国内慢可填镜像完整 URL）" "${CODEX_ASSET_URL:-}"
  if [ -n "$u" ]; then CODEX_ASSET_URL="$u"; fi
}

_codex_target() {
  case "$(os)-$(arch)" in
    linux-x86_64) echo "x86_64-unknown-linux-musl" ;;
    linux-arm64)  echo "aarch64-unknown-linux-musl" ;;
    macos-x86_64) echo "x86_64-apple-darwin" ;;
    macos-arm64)  echo "aarch64-apple-darwin" ;;
    *) die "codex: 无 $(os)-$(arch) 的发行包" ;;
  esac
}

codex_install() {
  # 幂等只看用户级安装：~/.local/bin/codex 存在才跳过。
  # 系统级 codex 存在也照样装用户级副本——环境自包含。
  if [ -x "$HOME/.local/bin/codex" ]; then
    log "codex 用户级安装已存在：~/.local/bin/codex（跳过）"
    return 0
  fi
  if have codex; then
    log "发现系统级 codex（$(command -v codex)），仍安装用户级副本以保证环境自包含"
  fi
  local target tag url tmp bin
  target="$(_codex_target)"
  if [ "$CODEX_VERSION" = "latest" ]; then
    tag="$(curl -fsSL --connect-timeout 10 https://api.github.com/repos/openai/codex/releases/latest \
          | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
  else
    tag="$CODEX_VERSION"
  fi
  [ -n "$tag" ] || die "codex: 无法解析 release tag（需要网络）"
  url="https://github.com/openai/codex/releases/download/$tag/codex-$target.tar.gz"
  [ -n "${CODEX_ASSET_URL:-}" ] && url="$CODEX_ASSET_URL"
  if ! confirm "即将下载 codex $tag（$target，约 90MB），继续？" y; then
    warn "已取消下载"
    return 1
  fi
  tmp="$(mktemp -d)"
  log "下载 $url"
  curl -fL --progress-bar "$url" -o "$tmp/codex.tar.gz" || die "codex: 下载失败（网络问题可换源重试）"
  tar -xzf "$tmp/codex.tar.gz" -C "$tmp"
  bin="$(find "$tmp" -maxdepth 2 -type f -name 'codex*' ! -name '*.tar.gz' | head -1)"
  [ -n "$bin" ] || die "codex: 压缩包中未找到二进制"
  ensure_user_bin_path
  install -m 0755 "$bin" "$HOME/.local/bin/codex"
  rm -rf "$tmp"
  log "已安装 codex（$tag）→ ~/.local/bin/codex"
}

codex_configure() {
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<CFG
model = "$PROVIDER_MODEL"
model_provider = "$PROVIDER_NAME"
model_reasoning_effort = "medium"
model_catalog_json = "~/.codex/model-catalog.local.json"

[model_providers.$PROVIDER_NAME]
name = "$PROVIDER_NAME"
base_url = "$PROVIDER_BASE_URL"
env_key = "$PROVIDER_KEY_ENV"
wire_api = "$PROVIDER_WIRE_API"
CFG
  install -m 0644 "$BROOK_ROOT/bootstrap/adapters/codex.catalog.json" \
    "$HOME/.codex/model-catalog.local.json"
  log "配置 ~/.codex/config.toml（provider=$PROVIDER_NAME, model=$PROVIDER_MODEL）"
}

codex_verify() {
  PATH="$HOME/.local/bin:$PATH" codex --version || die "codex 验证失败"
}
