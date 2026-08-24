# pypi —— PyPI 源（uv 的 UV_DEFAULT_INDEX，写入 shell rc）

MIRROR_PROVIDERS="tsinghua(默认) / aliyun / ustc"

mirror_desc() { echo "PyPI 源（uv 的 UV_DEFAULT_INDEX）"; }

mirror_detect() {
  if command -v uv >/dev/null 2>&1; then
    echo "适用（uv 已安装）"
  else
    echo "inapplicable（uv 未安装：brook install uv）"
  fi
}

mirror_status() {
  local rc line
  rc="$(rc_file)"
  line="$(grep -h 'UV_DEFAULT_INDEX' "$rc" 2>/dev/null | tail -1 || true)"
  if [ -n "$line" ]; then
    echo "✓ ${line#export }"
  else
    echo "✗ 未配置"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-tsinghua}" url rc
  case "$choice" in
    tsinghua) url="https://pypi.tuna.tsinghua.edu.cn/simple" ;;
    aliyun)   url="https://mirrors.aliyun.com/pypi/simple" ;;
    ustc)     url="https://mirrors.ustc.edu.cn/pypi/simple" ;;
    *) die "未知源：$choice（可选：tsinghua / aliyun / ustc）" ;;
  esac
  rc="$(rc_file)"
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将写入 $rc：export UV_DEFAULT_INDEX=\"$url\"（已有旧行则替换）"
    return 0
  fi
  if grep -q 'UV_DEFAULT_INDEX' "$rc" 2>/dev/null; then
    # 跨平台删行（GNU/BSD sed 的 -i 行为不一致，用 grep -v 临时文件法）
    grep -v 'UV_DEFAULT_INDEX' "$rc" > "$rc.brook-tmp" && mv "$rc.brook-tmp" "$rc"
  fi
  append_rc "export UV_DEFAULT_INDEX=\"$url\""
  log "已写入 $rc（source 后生效）"
}
