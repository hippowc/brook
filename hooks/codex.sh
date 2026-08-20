# codex 配置钩子：写 ~/.codex/config.toml + 模型能力目录
# 模型后端定义在 providers/*.env

_codex_load_provider() {
  local f loaded=0
  for f in "$BROOK_HOME"/providers/*.env; do
    [ -e "$f" ] || continue
    # shellcheck source=/dev/null
    source "$f"
    loaded=1
  done
  [ "$loaded" = 1 ] || die "未找到 providers/*.env（模型后端定义）"
}

_codex_ensure_key() {
  local var="${PROVIDER_KEY_ENV:-OPENAI_API_KEY}" rc k
  rc="$(rc_file)"
  [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  if [ -f "$rc" ] && grep -q "export $var=" "$rc"; then
    # shellcheck source=/dev/null
    source "$rc" 2>/dev/null || true
    [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  fi
  if [ -t 0 ]; then
    read -rsp "请粘贴 $var（不回显）: " k; echo
  else
    die "需要 $var（环境变量或 $rc 中 export）"
  fi
  [ -n "$k" ] || die "key 不能为空"
  printf 'export %s=%q\n' "$var" "$k" >> "$rc"
  export "$var=$k"
  log "$var 已写入 $rc"
}

codex_config() {
  _codex_load_provider
  _codex_ensure_key
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
  install -m 0644 "$BROOK_HOME/hooks/codex.catalog.json" "$HOME/.codex/model-catalog.local.json"
  log "配置已写入 ~/.codex/config.toml（provider=$PROVIDER_NAME, model=$PROVIDER_MODEL）"
}

codex_config_status() {
  if [ -f "$HOME/.codex/config.toml" ]; then
    echo "配置:    ✓ ~/.codex/config.toml"
  else
    echo "配置:    ✗ 未配置（brook codex config）"
  fi
}
