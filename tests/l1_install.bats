#!/usr/bin/env bats
# L1 —— 假环境全流程：fake curl + 假 GitHub 资产，离线跑通 install/status/remove
load helpers

@test "install：解析 latest → 下载 → 解压 → 安装 → 写 meta" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  [ -x "$BROOK_BIN_DIR/bat" ]
  grep -q '^tag=v0.26.1$' "$BROOK_META_DIR/bat"
  grep -q '^repo=sharkdp/bat$' "$BROOK_META_DIR/bat"
}

@test "install：二次安装幂等，跳过不重复下载" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "跳过"
}

@test "install：--version 指定版本 + 别名（rg→ripgrep）" {
  run "$BROOK_HOME/brook" install rg --version v99.0.0
  assert_any_output_contains "已安装 ripgrep（v99.0.0）"
  [ -x "$BROOK_BIN_DIR/rg" ]
  grep -q '^tag=v99.0.0$' "$BROOK_META_DIR/ripgrep"
}

@test "install：主资产 404 时走兜底候选（gnu）" {
  # 独立假仓库：只有 gnu 资产，musl 主资产缺失 → 触发兜底并成功
  local gh2="$TEST_ROOT/gh2"
  mkdir -p "$gh2/sharkdp/bat/v0.26.1"
  cp "$BROOK_HOME/tests/fixtures/gh/sharkdp/bat/v0.26.1/bat-v0.26.1-x86_64-unknown-linux-gnu.tar.gz"      "$gh2/sharkdp/bat/v0.26.1/"
  FAKE_GH_ROOT="$gh2"
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "使用兜底候选"
  assert_any_output_contains "已安装 bat（v0.26.1）"
  [ -x "$BROOK_BIN_DIR/bat" ]
}

@test "status：展示已安装版本与二进制位置" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" status bat
  assert_any_output_contains "安装:    ✓ v0.26.1"
  assert_any_output_contains "$BROOK_BIN_DIR/bat"
}

@test "remove：删二进制与 meta" {
  run "$BROOK_HOME/brook" install bat
  assert_any_output_contains "已安装 bat（v0.26.1）"
  run "$BROOK_HOME/brook" remove bat
  [ ! -e "$BROOK_BIN_DIR/bat" ]
  [ ! -e "$BROOK_META_DIR/bat" ]
}

@test "list：展示分类与状态列语义（不联网）" {
  run "$BROOK_HOME/brook" list
  assert_any_output_contains "【二进制工具】"
  assert_any_output_contains "【语言工具】"
  assert_any_output_contains "【安装包工具】"
  assert_any_output_contains "bat"
}

@test "doctor：基线自检在缺 zstd 时不算失败" {
  run "$BROOK_HOME/brook" doctor
  # doctor 中 git/curl/tar 真实存在；unzip 缺则走 python3 降级；GitHub 连通性探到假 curl 返回 200
  [ "$status" -eq 0 ]
}
