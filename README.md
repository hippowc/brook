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
brook fd usage                              # 常见用法速查
brook codex status                          # 状态
brook codex upgrade                         # 升级
brook codex remove                          # 移除
brook proxies                               # 代理预设
```

常用选项：`--version V`（pin 版本）、`--proxy P`（代理，也可直接给 URL 前缀）、`--force`（强制重装）。`BROOK_PROXY=P` 可全局指定代理。

## 内置工具

| 工具 | 说明 | 配置 |
|---|---|---|
| codex | OpenAI 开源终端编码 agent | ✓ |
| shadowsocks-rust | SOCKS5 代理（ssserver/sslocal） | ✓ |
| ripgrep | 极速文本搜索（rg） | — |
| fd | 现代 find：按正则快速找文件 | — |
| bat | 现代 cat：语法高亮 + 行号 | — |
| eza | 现代 ls：图标/Git 状态/树形（仅 Linux） | — |
| zoxide | 智能 cd：按访问频率跳转（z） | — |
| fzf | 模糊搜索：文件/历史/管道 | — |
| helix | 后现代终端编辑器（hx） | — |
| neovim | Vim 的现代演进（nvim） | — |
| jq | 命令行 JSON 处理器 | — |
| yt-dlp | 通用视频下载器 | — |
| gocryptfs | 加密目录挂载（仅 Linux） | — |

## 新增一个工具

加一个目录 `tools/<名字>/`，一个目录 = 这个工具的一切：

```
tools/<名字>/
├── tool.conf      # release 映射（必须）
├── config/        # 配置最佳实践（可选）：一个文件一个具名实践
├── catalog.json   # 配置实践用到的资源（可选）
└── usage.md       # 常见用法速查（可选）
```

### tool.conf 字段

```
DESC="一句话说明"
REPO="owner/repo"
ASSET="模板-{{TAG}}-{{TARGET}}.tar.gz"   # 占位符：{{TAG}} 版本、{{TARGET}} 平台
TARGET_linux_x86_64="x86_64-unknown-linux-musl"
TARGET_linux_arm64="aarch64-unknown-linux-musl"
TARGET_macos_x86_64="x86_64-apple-darwin"
TARGET_macos_arm64="aarch64-apple-darwin"
ARCHIVE="tar.gz"                          # tar.gz | tar.xz | zip | zst | raw
BINARIES="二进制名"                        # 空格分隔多个
CHECKSUM="sha256-sidecar"                 # 可选：校验官方 .sha256 旁路文件
ASSET_FALLBACKS="备用模板1 备用模板2"       # 可选：主资产 404 时按序尝试（写实测存在的格式）
ASSET_STRIP_V=1                            # 可选：tag 带 v 前缀但资产名不带时（zoxide/fzf）
```

两个实用技巧：资产名完全不含占位符规律时（如 neovim 的 `nvim-linux-x86_64.tar.gz`、jq 的裸二进制），把 `TARGET_*` 直接写成完整资产名、`ASSET="{{TARGET}}"` 即可；资产是裸二进制（无压缩包）时设 `ARCHIVE="raw"`。

### config/（配置最佳实践）

每个工具可以提供**一组具名的配置实践**——本质就是脚本或配置文件的增删改，保持简单：

```
tools/<名字>/config/
├── <实践1>.sh
└── <实践2>.sh        # 加实践 = 加文件
```

```bash
brook <tool> config            # 列出该工具全部实践及状态
brook <tool> config <实践>      # 执行指定实践
```

实践文件约定三个函数：`config_desc`（一句话说明）、`config_run`（执行）、`config_status`（可选，状态展示）。粒度按用户视角切分，例如 shadowsocks-rust：

- `client`：生成客户端配置（服务器地址/端口/密码）
- `server`：生成服务端配置
- `switch`：安装 sson/ssoff 一键代理开关

codex 目前是 `bailian`（接入百炼 API），加 openrouter/ollama 就是加文件。


## 代理

预设在 `proxies.conf`（实测见文件内注释）。两种模式：`prefix`（URL 前拼接，gh-proxy 系）与 `replace`（域名替换）。加新代理 = 加一行。
