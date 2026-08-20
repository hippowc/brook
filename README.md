# brook

GitHub release 二进制安装器：把 GitHub 上发布的二进制工具统一装到本地（`~/.local/bin`）并加入 PATH。支持 Linux / macOS（x86_64 / arm64），支持国内加速代理。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh -o /tmp/brook-install.sh && bash /tmp/brook-install.sh
```

## 使用

```bash
brook list                                  # 可用工具及状态
brook codex install --proxy gh-proxy        # 安装（国内建议加代理）
brook codex config                          # 配置（支持的工具）
brook codex status                          # 状态
brook codex upgrade                         # 升级
brook codex remove                          # 移除
brook proxies                               # 代理预设
```

常用选项：`--version V`（pin 版本）、`--proxy P`（代理，也可直接给 URL 前缀）、`--force`（强制重装）。`BROOK_PROXY=P` 可全局指定代理。

## 内置工具

| 工具 | 说明 | 配置钩子 |
|---|---|---|
| codex | OpenAI 开源终端编码 agent | ✓（config.toml + 模型后端） |
| shadowsocks-rust | SOCKS5 代理（ssserver/sslocal） | ✓（交互式生成配置） |
| ripgrep | 极速搜索（rg） | — |

## 新增一个工具

1. 加 `registry/<名字>.conf`（工具与 release 文件的映射）：

```
DESC="一句话说明"
REPO="owner/repo"
ASSET="模板-{{TAG}}-{{TARGET}}.tar.gz"   # 占位符：{{TAG}} 版本、{{TARGET}} 平台
TARGET_linux_x86_64="x86_64-unknown-linux-musl"
TARGET_linux_arm64="aarch64-unknown-linux-musl"
TARGET_macos_x86_64="x86_64-apple-darwin"
TARGET_macos_arm64="aarch64-apple-darwin"
ARCHIVE="tar.gz"                          # tar.gz | tar.xz | zip
BINARIES="二进制名"                        # 空格分隔多个
CHECKSUM="sha256-sidecar"                 # 可选：校验官方 .sha256 旁路文件
```

2. 如需配置，加 `hooks/<名字>.sh`，定义 `<名字连字符转下划线>_config`（可选 `_config_status` 显示配置状态）。

## 代理

预设在 `proxies.conf`（实测见文件内注释）。两种模式：`prefix`（URL 前拼接，gh-proxy 系）与 `replace`（域名替换）。加新代理 = 加一行。
