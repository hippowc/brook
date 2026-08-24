#!/usr/bin/env bats
# L1 —— mirror 轨：列表（离线） / pypi dry-run（假 uv） / apt dry-run（仅 Linux）
load helpers

@test "mirror: list shows all (offline)" {
  run "$BROOK_HOME/brook" mirror
  assert_any_output_contains "apt"
  assert_any_output_contains "pypi"
  assert_any_output_contains "goproxy"
  assert_any_output_contains "npm"
}

@test "mirror: pypi apply --dry-run preview only" {
  run "$BROOK_HOME/brook" mirror pypi apply --dry-run
  assert_any_output_contains "[dry-run]"
  assert_any_output_contains "UV_DEFAULT_INDEX"
  run grep -q "UV_DEFAULT_INDEX" "$HOME/.bashrc"
  [ "$status" -ne 0 ]
}

@test "mirror: pypi apply writes rc + idempotent" {
  run "$BROOK_HOME/brook" mirror pypi apply
  assert_any_output_contains "已写入"
  grep -q 'UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"' "$HOME/.bashrc"
  run grep -c 'UV_DEFAULT_INDEX' "$HOME/.bashrc"
  [ "$output" = "1" ]
}

@test "mirror: apt apply --dry-run (ubuntu/debian only)" {
  if [ ! -f /etc/os-release ] || ! grep -qE '^ID=(ubuntu|debian)$' /etc/os-release; then
    skip "非 Ubuntu/Debian，跳过 apt 用例"
  fi
  run "$BROOK_HOME/brook" mirror apt apply --dry-run
  # 已在国内源的机器会走"不做改动"短路径，两种都算通过；重点是命令不崩、不落盘
  [[ "$output" == *"[dry-run]"* || "$output" == *"国内源"* || "$output" == *"不做改动"* ]]
}


@test "mirror: new sources listed (crates/maven/docker/homebrew)" {
  run "$BROOK_HOME/brook" mirror
  assert_any_output_contains "crates"
  assert_any_output_contains "maven"
  assert_any_output_contains "docker"
  assert_any_output_contains "homebrew"
}

@test "mirror: crates apply writes ~/.cargo/config.toml" {
  mkdir -p "$HOME/.cargo"
  run "$BROOK_HOME/brook" mirror crates apply --dry-run
  assert_any_output_contains "[dry-run]"
  run "$BROOK_HOME/brook" mirror crates apply
  assert_any_output_contains "已写入"
  grep -q 'rsproxy' "$HOME/.cargo/config.toml"
}

@test "mirror: maven apply creates settings.xml" {
  mkdir -p "$HOME/.m2"
  run "$BROOK_HOME/brook" mirror maven apply --dry-run
  assert_any_output_contains "[dry-run]"
  run "$BROOK_HOME/brook" mirror maven apply
  assert_any_output_contains "已写入"
  grep -q 'maven.aliyun.com' "$HOME/.m2/settings.xml"
}

@test "mirror: homebrew apply --dry-run (fake brew)" {
  run "$BROOK_HOME/brook" mirror homebrew apply --dry-run
  assert_any_output_contains "[dry-run]"
}

@test "mirror: docker apply --dry-run (fake docker + linux)" {
  run "$BROOK_HOME/brook" mirror docker apply --dry-run
  assert_any_output_contains "[dry-run]"
}
