# codex 配置最佳实践：接入阿里云百炼 API（OpenAI 兼容端点）
# 做的事：写 ~/.codex/config.toml + 模型能力目录，key 存入 shell rc
# 换别的 OpenAI 兼容后端：改下面五个变量即可

codex_config() {
  local name="bailian"
  local base_url="https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
  local model="qwen3.8-max-preview"
  local key_env="OPENAI_API_KEY"
  local wire_api="responses"

  _codex_ensure_key "$key_env"
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<CFG
model = "$model"
model_provider = "$name"
model_reasoning_effort = "medium"
model_catalog_json = "~/.codex/model-catalog.local.json"

[model_providers.$name]
name = "$name"
base_url = "$base_url"
env_key = "$key_env"
wire_api = "$wire_api"
CFG
  install -m 0644 "$BROOK_HOME/tools/codex/catalog.json" \
    "$HOME/.codex/model-catalog.local.json"
  log "配置已写入 ~/.codex/config.toml（$name / $model）"
}

_codex_ensure_key() {
  local var="$1" rc k
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
    die "需要 $var（环境变量或在 $rc 中 export）"
  fi
  [ -n "$k" ] || die "key 不能为空"
  printf 'export %s=%q\n' "$var" "$k" >> "$rc"
  export "$var=$k"
  log "$var 已写入 $rc"
}

codex_config_status() {
  if [ -f "$HOME/.codex/config.toml" ]; then
    echo "配置:    ✓ ~/.codex/config.toml（百炼 API）"
  else
    echo "配置:    ✗ 未配置（brook codex config 接入百炼 API）"
  fi
}
