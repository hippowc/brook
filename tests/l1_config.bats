#!/usr/bin/env bats
# L1 —— 配置实践：codex bailian 合并写入，保留 [projects.*] 定制段
load helpers

write_initial_cfg() {
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/config.toml" <<'TOML'
# 用户已有配置
model_catalog_json = "a"
model = "old-model"

[projects."/root/blog"]
trust_level = "trusted"

[tui.whatever]
k = 1
TOML
}

@test "config codex bailian: merge write keeps projects section" {
  export OPENAI_API_KEY="sk-test-123"
  write_initial_cfg
  run "$BROOK_HOME/brook" config codex bailian
  assert_any_output_contains "配置已合并写入"
  local cfg="$HOME/.codex/config.toml"
  # 模型/provider 被更新
  grep -q '^model = "qwen3.8-max-preview"$' "$cfg"
  grep -q '^model_provider = "bailian"$' "$cfg"
  grep -q '^model_catalog_json = "~/.codex/model-catalog.local.json"$' "$cfg"
  grep -q '^\[model_providers.bailian\]$' "$cfg"
  grep -q 'base_url = "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"' "$cfg"
  # 关键：既有段落必须保留（A1 合并写入的回归点）
  grep -q '^\[projects."/root/blog"\]$' "$cfg"
  grep -q '^trust_level = "trusted"$' "$cfg"
  grep -q '^\[tui.whatever\]$' "$cfg"
  # 模型目录被复制
  [ -f "$HOME/.codex/model-catalog.local.json" ]
}

@test "config codex bailian: idempotent, no duplicate keys" {
  export OPENAI_API_KEY="sk-test-456"
  mkdir -p "$HOME/.codex"
  : > "$HOME/.codex/config.toml"
  run "$BROOK_HOME/brook" config codex bailian
  run "$BROOK_HOME/brook" config codex bailian
  local cfg="$HOME/.codex/config.toml"
  [ "$(grep -c '^model = ' "$cfg")" = "1" ]
  [ "$(grep -c '^\[model_providers.bailian\]' "$cfg")" = "1" ]
}
