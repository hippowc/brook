# 配置实践：使用百炼托管的 DeepSeek 模型（deepseek-v4 系列）
# 与 bailian 实践同后端：百炼 OpenAI 兼容端点 + 百炼 key（OPENAI_API_KEY），仅模型不同。
# 实测（2026-08-24）：百炼 /responses 端点对这两个模型可用，故 wire_api=responses。
# 双模型：默认 pro，profile deepseek-flash 切 flash。
# 注意：会覆盖 ~/.codex/config.toml（后端切换语义）；切回 qwen 跑 brook config codex bailian

config_desc() { echo "使用百炼托管的 DeepSeek 模型（复用百炼 key，pro/flash 双模型）"; }

config_run() {
  local name="deepseek"
  local base_url="https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
  local model="deepseek-v4-pro-0813"         # 默认模型
  local model_alt="deepseek-v4-flash-0731"   # 备选模型（--profile deepseek-flash）
  local key_env="OPENAI_API_KEY"             # 百炼 key（与 bailian 实践同源，已配过则免粘贴）
  local wire_api="responses"                 # 实测：百炼 responses 端点支持这两个模型

  _deepseek_ensure_key "$key_env"
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<CFG
model = "$model"
model_provider = "$name"

[model_providers.$name]
name = "DeepSeek（百炼托管）"
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
    # 非交互 shell 常被 rc 头部交互守卫拦截（Ubuntu 默认 .bashrc），直接取 export 行求值
    local line
    line="$(grep "^export $var=" "$rc" | head -1)"
    if [ -n "$line" ]; then
      eval "$line"
      [ -n "$(printenv "$var" 2>/dev/null || true)" ] && return 0
    fi
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
