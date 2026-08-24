#!/usr/bin/env bats
# L0 -- proxy_apply: direct / URL prefix / preset prefix / replace / unknown
load helpers

@test "proxy_apply: direct when unset; none=direct" {
  PROXY_NAME=""
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://github.com/a/b/releases/download/v1/x" ]
  PROXY_NAME="none"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply: raw URL prefix (strips trailing slash)" {
  PROXY_NAME="https://ghfast.top/"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://ghfast.top/https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply: preset gh-proxy (prefix mode)" {
  PROXY_NAME="gh-proxy"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://gh-proxy.com/https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply: replace mode (temp proxies.conf)" {
  mkdir -p "$TEST_ROOT/fakehome"
  printf 'gh-mirror|replace|github.com|github.mirror.example\n' > "$TEST_ROOT/fakehome/proxies.conf"
  local saved_home="$BROOK_HOME"
  BROOK_HOME="$TEST_ROOT/fakehome"
  PROXY_NAME="gh-mirror"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  local got="$output"
  BROOK_HOME="$saved_home"
  [ "$got" = "https://github.mirror.example/a/b/releases/download/v1/x" ]
}

@test "proxy_apply: unknown preset dies" {
  PROXY_NAME="no-such-proxy"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$status" -ne 0 ]
  assert_any_output_contains "未知代理"
}
