# 配置实践：把 fnm 挂进 shell rc（装完必做，否则 fnm 切换的版本不进 PATH）

config_desc() { echo "写 fnm env 进 shell rc（装完必做一次）"; }

config_run() {
  local rc line
  rc="$(rc_file)"
  line='eval "$(fnm env --use-on-cd)"  # fnm shell setup'
  if ! grep -qF 'fnm env' "$rc" 2>/dev/null; then
    echo "$line" >> "$rc"
    log "已写入 $rc（source 后生效）"
  else
    log "$rc 已有 fnm env，跳过"
  fi
  log "--use-on-cd：进入含 .node-version/.nvmrc 的目录自动切版本"
}

config_status() {
  if grep -qF 'fnm env' "$(rc_file)" 2>/dev/null; then
    echo "配置[shell-init]: ✓ fnm env 已挂进 $(rc_file)"
  else
    echo "配置[shell-init]: ✗ 未初始化（brook config fnm shell-init）"
  fi
}
