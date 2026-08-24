# docker —— Docker Hub 镜像源（/etc/docker/daemon.json，Linux，需 root）

MIRROR_PROVIDERS="daocloud(默认) / ustc"
NEED_ROOT=1

mirror_desc() { echo "Docker Hub 镜像源（写 daemon.json，改后重启 docker）"; }

mirror_detect() {
  if command -v docker >/dev/null 2>&1 && [ "$(uname -s)" = "Linux" ]; then
    echo "适用（docker 已安装，Linux）"
  else
    echo "inapplicable（需 docker 且 Linux；macOS 用 Docker Desktop 自带镜像设置）"
  fi
}

mirror_status() {
  local f=/etc/docker/daemon.json
  if [ -f "$f" ] && grep -q 'registry-mirrors' "$f" 2>/dev/null; then
    echo "✓ 已配置镜像源（${f}）"
  else
    echo "✗ 未配置（brook mirror docker apply）"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-daocloud}" url f=/etc/docker/daemon.json
  case "$choice" in
    daocloud) url="https://docker.m.daocloud.io" ;;
    ustc)     url="https://docker.mirrors.ustc.edu.cn" ;;
    *) die "未知源：${choice}（可选：daocloud / ustc）" ;;
  esac
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将写入 ${f}：{ \\"registry-mirrors\\": [\\"${url}\\"] }，并提示重启 docker"
    return 0
  fi
  # 用 python3 合并 JSON，保留 daemon.json 里已有的其他配置
  if have python3; then
    python3 - "$f" "$url" <<'PY'
import json, sys
f, url = sys.argv[1], sys.argv[2]
try:
    with open(f, encoding='utf-8') as fp:
        data = json.load(fp)
except (OSError, ValueError):
    data = {}
mirrors = data.setdefault('registry-mirrors', [])
if url not in mirrors:
    mirrors.append(url)
if not mirrors:
    data['registry-mirrors'] = [url]
with open(f, 'w', encoding='utf-8') as fp:
    json.dump(data, fp, indent=2, ensure_ascii=False)
    fp.write('\n')
PY
  else
    [ -f "$f" ] && cp "$f" "$f.brook-bak" && warn "已有 ${f} 已备份为 ${f}.brook-bak"
    cat > "$f" <<JSON
{
  "registry-mirrors": ["$url"]
}
JSON
  fi
  log "已写入 ${f}（重启生效：sudo systemctl restart docker）"
}
