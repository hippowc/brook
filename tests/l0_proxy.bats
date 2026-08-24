#!/usr/bin/env bats
# L0 —— proxy_apply：直连 / URL 前缀 / 预设 prefix / replace / 未知预设
load helpers

@test "proxy_apply：未设置 PROXY_NAME 直连；none 直连" {
  PROXY_NAME=""
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://github.com/a/b/releases/download/v1/x" ]
  PROXY_NAME="none"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply：直接给 URL 前缀（去尾部斜杠）" {
  PROXY_NAME="https://ghfast.top/"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://ghfast.top/https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply：读取预设 gh-proxy（prefix）" {
  PROXY_NAME="gh-proxy"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$output" = "https://gh-proxy.com/https://github.com/a/b/releases/download/v1/x" ]
}

@test "proxy_apply：replace 模式（临时 proxies.conf）" {
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

@test "proxy_apply：未知预设 die" {
  PROXY_NAME="no-such-proxy"
  run proxy_apply "https://github.com/a/b/releases/download/v1/x"
  [ "$status" -ne 0 ]
  assert_any_output_contains "未知代理"
}
