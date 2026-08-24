#!/usr/bin/env bats
# L0 —— 纯函数：资产名渲染 / 压缩类型判定 / 版本占位符
load helpers

@test "render_asset_pattern：替换 {{TAG}} 与 {{TARGET}}" {
  run render_asset_pattern "bat-{{TAG}}-{{TARGET}}.tar.gz" "v0.26.1" "x86_64-unknown-linux-musl"
  [ "$status" -eq 0 ]
  [ "$output" = "bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz" ]
}

@test "render_asset_pattern：多次出现与无占位符" {
  run render_asset_pattern "{{TARGET}}/{{TARGET}}.tar.gz" "v1" "abc"
  [ "$output" = "abc/abc.tar.gz" ]
  run render_asset_pattern "plain-name.bin" "v1" "abc"
  [ "$output" = "plain-name.bin" ]
}

@test "detect_archive_type：后缀识别" {
  run detect_archive_type "a.tar.gz";  [ "$output" = "tar.gz" ]
  run detect_archive_type "a.tgz";     [ "$output" = "tar.gz" ]
  run detect_archive_type "a.tar.xz";  [ "$output" = "tar.xz" ]
  run detect_archive_type "a.txz";     [ "$output" = "tar.xz" ]
  run detect_archive_type "a.zip";     [ "$output" = "zip" ]
  run detect_archive_type "a.zst";     [ "$output" = "zst" ]
}

@test "detect_archive_type：未知后缀回落 ARCHIVE（raw=jq 裸二进制）" {
  ARCHIVE="raw" run detect_archive_type "jq-linux-amd64"
  [ "$output" = "raw" ]
  ARCHIVE="tar.gz" run detect_archive_type "no-suffix"
  [ "$output" = "tar.gz" ]
}

@test "detect_archive_type：ARCHIVE 未设置时默认 tar.gz" {
  unset ARCHIVE
  run detect_archive_type "whatever.bin"
  [ "$output" = "tar.gz" ]
}
