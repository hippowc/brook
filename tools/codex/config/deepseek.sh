# 配置实践：接入 DeepSeek 官方 API（OpenAI 兼容，chat completions）
# 与 bailian 实践同构（换后端 = 换这组变量）；差异点：
#   - wire_api = chat（DeepSeek 无 responses API）
#   - 双模型：默认 pro，profile deepseek-flash 切 flash
# 注意：会覆盖 ~/.codex/config.toml（后端切换语义）；切回百炼跑 brook config codex bailian

config_desc() { echo "接入 DeepSeek 官方 API（config.toml + key，pro/flash 双模型）"; }

config_run() {
  local name="deepseek"
  local base_url="https://api.deepseek.com/v1"
  local model="deepseek-v4-pro-0813"         # 默认模型
  local model_alt="deepseek-v4-flash-0731"   # 备选模型（--profile deepseek-flash）
  local key_env="DEEPSEEK_API_KEY"
  local wire_api="chat"

  _deepseek_ensure_key "$key_env"
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<CFG
model = "$model"
model_provider = "$name"

[model_providers.$name]
name = "DeepSeek"
base_url = "$base_url"
env_key = "$key_env"
wire_api = "$wire_api"

[profiles.deepseek-flash]
model = "$model_alt"
model_provider = "$name"
CFG
  log "配置已写入 ~/.codex/config.toml（$name / $model）"
  log "切备选模型：codex --profile deepseek-flash（$model_alt）"
}

_deepseek_ensure_key() {
  local var="$1" rc k
  rc="$(rc_file)"
  [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  if [ -f "$rc" ] && grep -q "export $var=" "$rc"; then
    # shellcheck source=/dev/null
    source "$rc" 2>/dev/null || true
    [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
  fi
  if [ -t 0 ]; then
    read -rsp "请粘贴 ${var}（不回显）: " k; echo
  else
    die "需要 ${var}（环境变量或在 $rc 中 export）"
  fi
  [ -n "$k" ] || die "key 不能为空"
  printf 'export %s=%q\n' "$var" "$k" >> "$rc"
  export "$var=$k"
  log "$var 已写入 $rc"
}

config_status() {
  if [ -f "$HOME/.codex/config.toml" ] && grep -q 'model_providers.deepseek' "$HOME/.codex/config.toml"; then
    echo "配置[DeepSeek]: ✓ ~/.codex/config.toml"
  else
    echo "配置[DeepSeek]: ✗ 未配置（brook config codex deepseek）"
  fi
}
