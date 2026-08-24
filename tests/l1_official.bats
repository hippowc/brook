#!/usr/bin/env bats
# L1 —— official 轨：安装检测 / 前置依赖检查 / 官方脚本安装全流程（离线）
load helpers

@test "official: _official_installed 按 BINARIES 查 PATH" {
  cat > "$TEST_ROOT/of-bin.conf" <<CONF
BINARIES="fakeagent"
CONF
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _official_installed' -- "$TEST_ROOT/of-bin.conf"
  [ "$status" -ne 0 ]
  mkdir -p "$TEST_ROOT/binx"
  printf '#!/usr/bin/env bash\ntrue\n' > "$TEST_ROOT/binx/fakeagent"
  chmod +x "$TEST_ROOT/binx/fakeagent"
  PATH="$TEST_ROOT/binx:$PATH" run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _official_installed' -- "$TEST_ROOT/of-bin.conf"
  [ "$status" -eq 0 ]
}

@test "official: _official_installed 支持 CHECK_FILES 标志（sdkman 型）" {
  cat > "$TEST_ROOT/of-file.conf" <<CONF
CHECK_FILES="$TEST_ROOT/.fake-init.sh"
CONF
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _official_installed' -- "$TEST_ROOT/of-file.conf"
  [ "$status" -ne 0 ]
  touch "$TEST_ROOT/.fake-init.sh"
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _official_installed' -- "$TEST_ROOT/of-file.conf"
  [ "$status" -eq 0 ]
}

@test "official: _check_prereqs 缺失时列出并失败" {
  cat > "$TEST_ROOT/of-prereq.conf" <<CONF
PREREQS="brook_zz_no_such_cmd"
CONF
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _check_prereqs demo' -- "$TEST_ROOT/of-prereq.conf"
  [ "$status" -ne 0 ]
  assert_any_output_contains "本机缺失"
}

@test "official: _check_prereqs 满足时通过" {
  cat > "$TEST_ROOT/of-prereq-ok.conf" <<CONF
PREREQS="bash"
CONF
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; _check_prereqs demo' -- "$TEST_ROOT/of-prereq-ok.conf"
  [ "$status" -eq 0 ]
}

@test "official: install 全流程（file:// 官方脚本）" {
  printf '#!/usr/bin/env bash\ntouch "%s/.installed.marker"\n' "$TEST_ROOT" > "$TEST_ROOT/install.sh"
  cat > "$TEST_ROOT/of-install.conf" <<CONF
DESC="fake official app"
SCRIPT_URL="file://$TEST_ROOT/install.sh"
BINARIES="fakeagent"
CONF
  run bash -c 'source "$BROOK_HOME/lib/core.sh"; source "$BROOK_HOME/lib/official.sh"; source "$1"; official_install fakeapp' -- "$TEST_ROOT/of-install.conf"
  assert_any_output_contains "安装完成"
  [ -e "$TEST_ROOT/.installed.marker" ]
}
