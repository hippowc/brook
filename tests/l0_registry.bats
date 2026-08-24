#!/usr/bin/env bats
# L0 -- registry: target_of platform mapping / meta IO / bin present / tool resolve
load helpers

@test "target_of: linux x86_64 -> musl triple (bat)" {
  unset TARGET_linux_x86_64 TARGET_linux_arm64 TARGET_macos_x86_64 TARGET_macos_arm64 NOTE_macos
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/bat/tool.conf"
  os()  { echo linux; }
  arch() { echo x86_64; }
  run target_of
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64-unknown-linux-musl" ]
}

@test "target_of: macos arm64 -> apple triple (bat)" {
  unset TARGET_linux_x86_64 TARGET_linux_arm64 TARGET_macos_x86_64 TARGET_macos_arm64 NOTE_macos
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/bat/tool.conf"
  os()  { echo macos; }
  arch() { echo arm64; }
  run target_of
  [ "$status" -eq 0 ]
  [ "$output" = "aarch64-apple-darwin" ]
}

@test "target_of: no package -> uses NOTE and fails (eza@macos)" {
  unset TARGET_linux_x86_64 TARGET_linux_arm64 TARGET_macos_x86_64 TARGET_macos_arm64 NOTE_macos NOTE_linux
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/eza/tool.conf"
  os()  { echo macos; }
  arch() { echo arm64; }
  run target_of
  [ "$status" -ne 0 ]
  assert_any_output_contains "macOS 官方不发布二进制"
}

@test "installed_tag_of: reads meta; empty when missing" {
  printf 'tag=v1.2.3\ndate=2026-08-24\n' > "$BROOK_META_DIR/bat"
  run installed_tag_of bat
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3" ]
  run installed_tag_of not_there
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "save_meta: writes tag/date/repo" {
  REPO="sharkdp/bat"
  run save_meta bat v9.9.9
  [ "$status" -eq 0 ]
  [ -f "$BROOK_META_DIR/bat" ]
  grep -q '^tag=v9.9.9$' "$BROOK_META_DIR/bat"
  grep -q '^repo=sharkdp/bat$' "$BROOK_META_DIR/bat"
}

@test "binaries_present: all present -> 0; missing -> 1 (uv)" {
  # shellcheck source=/dev/null
  source "$BROOK_HOME/tools/uv/tool.conf"
  BINARIES="uv uvx"
  : > "$BROOK_BIN_DIR/uv"; chmod +x "$BROOK_BIN_DIR/uv"
  : > "$BROOK_BIN_DIR/uvx"; chmod +x "$BROOK_BIN_DIR/uvx"
  run binaries_present uv
  [ "$status" -eq 0 ]
  rm -f "$BROOK_BIN_DIR/uvx"
  run binaries_present uv
  [ "$status" -ne 0 ]
}

@test "extract_archive: tar.zst 正确解压（需 zstd）" {
  if ! command -v zstd >/dev/null 2>&1; then skip "本机无 zstd"; fi
  mkdir -p "$TEST_ROOT/pkg"
  printf '#!/usr/bin/env bash\necho hi\n' > "$TEST_ROOT/pkg/zbin"
  chmod +x "$TEST_ROOT/pkg/zbin"
  ( cd "$TEST_ROOT/pkg" && tar -cf - zbin | zstd -q > "$TEST_ROOT/archive" )
  run extract_archive "$TEST_ROOT" "some.tar.zst"
  [ "$status" -eq 0 ]
  [ -x "$TEST_ROOT/zbin" ]
}

@test "_resolve_tool: name/alias/unknown" {
  run _resolve_tool bat
  [ "$output" = "bat" ]
  run _resolve_tool rg
  [ "$output" = "ripgrep" ]
  run _resolve_tool hx
  [ "$output" = "helix" ]
  run _resolve_tool sdkman
  [ "$output" = "sdkman" ]
  run _resolve_tool definitely_not_a_tool
  [ "$status" -ne 0 ]
}
