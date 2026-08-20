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
ASSET_FALLBACKS="备用模板1 备用模板2"       # 可选：主资产 404 时按序尝试（写实测存在的格式）
```

### 上游改名了怎么办

资产选择是注册时确定的映射，上游改命名时按三级兜底降级：

1. **预置候选**：`ASSET_FALLBACKS` 里的实测备用格式，按序尝试；
2. **运行时枚举**：全部 miss 时拉取该 release 的真实资产列表，按平台三元组筛选——唯一候选自动选用并警告，多个候选交互选择；
3. 都失败：展示真实资产列表，提示更新映射。

正常路径始终零猜测、零额外请求；启发式只在映射失效后兜底，且每次触发都大声警告。

2. 如需配置，加 `hooks/<名字>.sh`，定义 `<名字连字符转下划线>_config`（可选 `_config_status` 显示配置状态）。

## 代理

预设在 `proxies.conf`（实测见文件内注释）。两种模式：`prefix`（URL 前拼接，gh-proxy 系）与 `replace`（域名替换）。加新代理 = 加一行。
