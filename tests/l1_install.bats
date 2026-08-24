#!/usr/bin/env bats
# L1 -- fake-env full flows: fake curl + fake GitHub assets, fully offline
load helpers

@test "install: latest->download->extract->bin->meta" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  [ -x "$BROOK_BIN_DIR/bat" ]
  grep -q '^tag=v0.26.1$' "$BROOK_META_DIR/bat"
  grep -q '^repo=sharkdp/bat$' "$BROOK_META_DIR/bat"
}

@test "install: idempotent, skips when already installed" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "跳过"
}

@test "install: --version + alias (rg -> ripgrep)" {
  run "$BROOK_HOME/brook" install rg --version v99.0.0
  assert_any_output_contains "已安装 ripgrep（v99.0.0）"
  [ -x "$BROOK_BIN_DIR/rg" ]
  grep -q '^tag=v99.0.0$' "$BROOK_META_DIR/ripgrep"
}

@test "install: primary asset 404 -> fallback candidate (gnu)" {
  local gh2="$TEST_ROOT/gh2"
  mkdir -p "$gh2/sharkdp/bat/v0.26.1"
  cp "$BROOK_HOME/tests/fixtures/gh/sharkdp/bat/v0.26.1/bat-v0.26.1-x86_64-unknown-linux-gnu.tar.gz"      "$gh2/sharkdp/bat/v0.26.1/"
  FAKE_GH_ROOT="$gh2"
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "使用兜底候选"
  assert_any_output_contains "已安装 bat（v0.26.1）"
  [ -x "$BROOK_BIN_DIR/bat" ]
}

@test "status: shows installed version and bin path" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" status bat
  assert_any_output_contains "安装:    ✓ v0.26.1"
  assert_any_output_contains "$BROOK_BIN_DIR/bat"
}

@test "remove: deletes bin and meta" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" remove bat
  [ ! -e "$BROOK_BIN_DIR/bat" ]
  [ ! -e "$BROOK_META_DIR/bat" ]
}

@test "list: categories and status column (offline)" {
  run "$BROOK_HOME/brook" list
  assert_any_output_contains "【二进制工具】"
  assert_any_output_contains "【语言工具】"
  assert_any_output_contains "【安装包工具】"
  assert_any_output_contains "bat"
}

@test "doctor: missing zstd is not fatal" {
  run "$BROOK_HOME/brook" doctor
  [ "$status" -eq 0 ]
}
