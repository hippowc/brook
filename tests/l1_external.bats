#!/usr/bin/env bats
# L1 —— 外部工具轨（EXTERNAL_INSTALL）：系统级工具只做配置不代装
load helpers

@test "external: git shown in list as system-bundled" {
  run "$BROOK_HOME/brook" list
  assert_any_output_contains "git"
  assert_any_output_contains "系统自带"
}

@test "external: brook install git only prints hint" {
  run "$BROOK_HOME/brook" install git
  assert_any_output_contains "brook 不代装"
}

@test "external: brook config git github-ssh creates key" {
  if ! command -v ssh-keygen >/dev/null 2>&1; then skip "本机无 ssh-keygen"; fi
  run "$BROOK_HOME/brook" config git github-ssh
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519" ]
  grep -q '^ssh-ed25519 ' "$HOME/.ssh/id_ed25519.pub"
}

@test "external: brook status git detects system binary" {
  run "$BROOK_HOME/brook" status git
  assert_any_output_contains "git"
  assert_any_output_contains "系统自带"
}
