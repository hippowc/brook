#!/usr/bin/env bats
# L0 -- pure functions: asset pattern render / archive type detect
load helpers

@test "render_asset_pattern: replaces TAG and TARGET" {
  run render_asset_pattern "bat-{{TAG}}-{{TARGET}}.tar.gz" "v0.26.1" "x86_64-unknown-linux-musl"
  [ "$status" -eq 0 ]
  [ "$output" = "bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz" ]
}

@test "render_asset_pattern: repeated placeholders and plain name" {
  run render_asset_pattern "{{TARGET}}/{{TARGET}}.tar.gz" "v1" "abc"
  [ "$output" = "abc/abc.tar.gz" ]
  run render_asset_pattern "plain-name.bin" "v1" "abc"
  [ "$output" = "plain-name.bin" ]
}

@test "detect_archive_type: suffix mapping" {
  run detect_archive_type "a.tar.gz";  [ "$output" = "tar.gz" ]
  run detect_archive_type "a.tgz";     [ "$output" = "tar.gz" ]
  run detect_archive_type "a.tar.xz";  [ "$output" = "tar.xz" ]
  run detect_archive_type "a.txz";     [ "$output" = "tar.xz" ]
  run detect_archive_type "a.zip";     [ "$output" = "zip" ]
  run detect_archive_type "a.zst";     [ "$output" = "zst" ]
  run detect_archive_type "a.tar.zst"; [ "$output" = "tar.zst" ]
}

@test "detect_archive_type: fallback to ARCHIVE (raw=jq)" {
  ARCHIVE="raw" run detect_archive_type "jq-linux-amd64"
  [ "$output" = "raw" ]
  ARCHIVE="tar.gz" run detect_archive_type "no-suffix"
  [ "$output" = "tar.gz" ]
}

@test "detect_archive_type: defaults to tar.gz when unset" {
  unset ARCHIVE
  run detect_archive_type "whatever.bin"
  [ "$output" = "tar.gz" ]
}
