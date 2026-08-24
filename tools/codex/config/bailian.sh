# 配置实践：接入阿里云百炼 API（OpenAI 兼容端点）
# 换别的 OpenAI 兼容后端：复制本文件改名，改下面五个变量即可

config_desc() { echo "接入阿里云百炼 API（config.toml + 模型目录 + key）"; }

config_run() {
  local name="bailian"
  local base_url="https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
  local model="qwen3.8-max-preview"
  local key_env="OPENAI_API_KEY"
  local wire_api="responses"

  _bailian_ensure_key "$key_env"
  mkdir -p "$HOME/.codex"
  local cfg="$HOME/.codex/config.toml"
  touch "$cfg"
  # 合并式写入：只更新模型/provider 相关键，保留 [projects.*] 等既有段落
  # （整文件覆盖会洗掉用户定制的信任段，此问题已知，2026-08 修复为合并）
  if have python3; then
    python3 "$BROOK_HOME/lib/toml.py" set-top "$cfg" \
      model="$model" \
      model_provider="$name" \
      model_reasoning_effort="medium" \
      model_catalog_json="~/.codex/model-catalog.local.json"
    python3 "$BROOK_HOME/lib/toml.py" set-table "$cfg" "model_providers.$name" \
      name="$name" base_url="$base_url" env_key="$key_env" wire_api="$wire_api"
  else
    die "合并写入 config.toml 需要 python3（macOS 装 Command Line Tools，Linux 用 apt install python3）"
  fi
  install -m 0644 "$BROOK_HOME/tools/codex/catalog.json" \
    "$HOME/.codex/model-catalog.local.json"
  log "配置已合并写入 ~/.codex/config.toml（$name / ${model}，既有段落已保留）"
}

_bailian_ensure_key() {
  local var="$1" rc k
  rc="$(rc_file)"
  if [ -n "$(printenv "$var" 2>/dev/null || true)" ]; then
    # key 在环境但不在 rc：落盘持久化，避免换 shell/重登后失效
    touch "$rc"
    if ! grep -q "^export $var=" "$rc"; then
      printf 'export %s=%q
' "$var" "$(printenv "$var")" >> "$rc"
      log "$var 已在环境中，已写入 $rc 持久化"
    fi
    return 0
  fi
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
  if [ -f "$HOME/.codex/config.toml" ] && grep -q 'model_providers.bailian' "$HOME/.codex/config.toml"; then
    echo "配置[百炼]: ✓ ~/.codex/config.toml"
  else
    echo "配置[百炼]: ✗ 未配置（brook config codex bailian）"
  fi
}
