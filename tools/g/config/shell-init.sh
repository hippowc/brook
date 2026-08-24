# 配置实践：写入 ~/.g/env 并挂进 shell rc（g 装完必做，否则工具链不生效）
# ~/.g/env 内容来自官方 README 的手动安装说明；G_MIRROR 用官方中国镜像，
# 之后 g install 下载工具链自动加速。

config_desc() { echo "写 ~/.g/env 并挂进 shell rc（g 装完必做一次）"; }

config_run() {
  mkdir -p "$HOME/.g"
  cat > "$HOME/.g/env" <<'ENV'
#!/bin/sh
# g shell setup（brook 生成）
export GOROOT="${HOME}/.g/go"
[ -z "$GOPATH" ] && export GOPATH="${HOME}/go"
export PATH="${HOME}/.g/bin:${GOROOT}/bin:${GOPATH}/bin:$PATH"
export G_MIRROR=https://golang.google.cn/dl/
ENV
  local rc line
  rc="$(rc_file)"
  line='[ -s "${HOME}/.g/env" ] && \. "${HOME}/.g/env"  # g shell setup'
  if ! grep -qF '.g/env' "$rc" 2>/dev/null; then
    echo "$line" >> "$rc"
    log "已写入 $rc"
  else
    log "$rc 已有 ~/.g/env 引入，跳过"
  fi
  log "完成：source $rc 后，g install <版本> && g use <版本>"
}

config_status() {
  if [ -f "$HOME/.g/env" ] && grep -qF '.g/env' "$(rc_file)" 2>/dev/null; then
    echo "配置[shell-init]: ✓ ~/.g/env 已挂进 $(rc_file)"
  else
    echo "配置[shell-init]: ✗ 未初始化（brook config g shell-init）"
  fi
}
