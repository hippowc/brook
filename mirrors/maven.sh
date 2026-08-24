# maven —— Maven 中央仓镜像（~/.m2/settings.xml）

MIRROR_PROVIDERS="aliyun(默认) / tencent / huawei"

mirror_desc() { echo "Maven 中央仓镜像（写 ~/.m2/settings.xml）"; }

mirror_detect() {
  if command -v mvn >/dev/null 2>&1 || [ -d "$HOME/.m2" ]; then
    echo "适用（mvn/~/.m2 存在）"
  else
    echo "inapplicable（无 mvn 且无 ~/.m2：先装 Java 与 maven，如 sdkman）"
  fi
}

mirror_status() {
  local f="$HOME/.m2/settings.xml"
  if [ -f "$f" ] && grep -q 'aliyun\|tencent\|huawei' "$f" 2>/dev/null; then
    echo "✓ 已配置国内镜像"
  else
    echo "✗ 未配置（brook mirror maven apply）"
  fi
}

mirror_apply() {
  local choice="${MIRROR_CHOICE:-aliyun}" id url f="$HOME/.m2/settings.xml"
  case "$choice" in
    aliyun)  id="aliyun";  url="https://maven.aliyun.com/repository/public" ;;
    tencent) id="tencent"; url="https://mirrors.cloud.tencent.com/nexus/repository/maven-public/" ;;
    huawei)  id="huawei";  url="https://repo.huaweicloud.com/repository/maven/" ;;
    *) die "未知源：${choice}（可选：aliyun / tencent / huawei）" ;;
  esac
  if [ "$DRY_RUN" = 1 ]; then
    log "[dry-run] 将写入 ${f} 的 <mirrors> 段：id=${id} url=${url}"
    return 0
  fi
  mkdir -p "$HOME/.m2"
  if [ -f "$f" ]; then
    warn "已有 ${f}，为避免破坏既有配置请手动加入以下 <mirror>："
    printf '    <mirror><id>%s</id><mirrorOf>central</mirrorOf><url>%s</url></mirror>\n' "$id" "$url"
    return 0
  fi
  cat > "$f" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <mirrors>
    <mirror>
      <id>$id</id>
      <mirrorOf>central</mirrorOf>
      <name>CN mirror</name>
      <url>$url</url>
    </mirror>
  </mirrors>
</settings>
XML
  log "已写入 ${f}"
}
