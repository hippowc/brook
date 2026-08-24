# 配置实践：PyPI 国内镜像（清华源）

config_desc() { echo "写清华 PyPI 源进 shell rc（UV_DEFAULT_INDEX）"; }

config_run() {
  append_rc 'export UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"'
  log "已写入 $(rc_file)（source 后生效）；单项目也可用 uv --index-url 覆盖"
}

config_status() {
  if grep -q 'UV_DEFAULT_INDEX' "$(rc_file)" 2>/dev/null; then
    echo "配置[pypi-mirror]: ✓ UV_DEFAULT_INDEX 已写入 $(rc_file)"
  else
    echo "配置[pypi-mirror]: ✗ 未配置（brook config uv pypi-mirror）"
  fi
}
