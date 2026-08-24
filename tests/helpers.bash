# helpers.bash —— brook 测试公共环境（由各 .bats 文件顶部 `load helpers` 加载）
# 每个用例独立临时 HOME/BIN/META；fake curl 前置入 PATH（离线跑通全流程）

export BROOK_HOME="$(cd "$(dirname "${BATS_TEST_FILENAME:-.}")/.." && pwd)"

setup() {
  export TEST_ROOT="$(mktemp -d)"
  export HOME="$TEST_ROOT/home"
  export BROOK_BIN_DIR="$TEST_ROOT/bin"
  export BROOK_META_DIR="$TEST_ROOT/meta"
  mkdir -p "$HOME" "$BROOK_BIN_DIR" "$BROOK_META_DIR"

  # 假 GitHub 内容根：URL github.com/<repo>/releases/download/<tag>/<asset>
  # 映射为 $FAKE_GH_ROOT/<repo>/<tag>/<asset>
  export FAKE_GH_ROOT="$BROOK_HOME/tests/fixtures/gh"
  export FAKE_LATEST_URL="https://github.com/sharkdp/bat/releases/tag/v0.26.1"

  # 假 curl 前置（拦截网络，全离线）
  export PATH="$BROOK_HOME/tests/fixtures/bin:$PATH"

  # L0 纯函数：加载库（L1 跑 brook 入口时会自载，互不影响）
  # shellcheck source=/dev/null
  source "$BROOK_HOME/lib/core.sh"
  # shellcheck source=/dev/null
  source "$BROOK_HOME/lib/proxy.sh"
  # shellcheck source=/dev/null
  source "$BROOK_HOME/lib/registry.sh"
}

teardown() {
  rm -rf "${TEST_ROOT:-}"
}

# 断言 stdout+stderr 合并后含目标串（die 走 stderr；bats 1.8+ 提供 $stderr）
assert_any_output_contains() {
  local combined="${output}${stderr:-}"
  if [[ "$combined" != *"$1"* ]]; then
    echo "期望输出包含: $1" >&2
    echo "实际 output: $output" >&2
    [ -z "${stderr:-}" ] || echo "实际 stderr: $stderr" >&2
    return 1
  fi
  return 0
}
