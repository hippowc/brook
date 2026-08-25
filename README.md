# brook

环境引导器（starter）：全新机器上，当没有更好的安装方式时，不用查网页，在 brook 里直接闭环。

不是包管理器替代品——apt / brew / npm 擅长的场景请用它们；brook 是引导层：把常用 CLI 工具与语言工具链（rustup / sdkman / g / uv / fnm）统一装到 `~/.local/bin` 并加入 PATH。支持 Linux / macOS（x86_64 / arm64），内置国内加速代理。

维护与扩展本项目请先读 [AGENTS.md](AGENTS.md)。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

国内网络 raw.githubusercontent.com 不稳时，走镜像：

```bash
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

## 使用

```bash
brook doctor                                # 基线自检（缺什么、怎么补）
brook list                                  # 可用工具及状态
brook install codex --proxy gh-proxy        # 安装（国内建议加代理）
brook config codex bailian                  # 配置（支持的工具，配置实践名）
brook usage fd                              # 常见用法速查
brook status codex                          # 状态
brook upgrade codex                         # 升级
brook remove codex                          # 移除
brook upgrade                               # 更新 brook 自身
brook proxies                               # 代理预设
```

常用选项：`--version V`（pin 版本）、`--proxy P`（代理，也可直接给 URL 前缀）、`--force`（强制重装）。`BROOK_PROXY=P` 可全局指定代理。

## 支持哪些工具

以 `brook list` 输出为准（含安装状态与配置支持标记）。分两类：

- **GitHub release 二进制工具**：完整流水线（install / upgrade / status / remove），见 `tools/`
- **超级官方应用**：官网一行命令安装（brew、rustup、sdkman），brook 只管装，见 `official/`

## 包源管理（国内镜像）

引导一台机器不只是装工具——系统自带的包管理器往往源没配好，语言生态的包源同理。`brook mirror` 统一管理：

```bash
brook mirror                              # 总览：适用性 / 当前状态 / 可用源
brook mirror apt apply --dry-run          # 预览：会改什么（不动手）
brook mirror apt apply                    # 应用（自动 sudo，改前备份，改后验证）
brook mirror apt apply --mirror tsinghua  # 选源
brook mirror goproxy apply                # Go 模块代理（goproxy.cn）
brook mirror pypi apply                   # PyPI（uv 的 UV_DEFAULT_INDEX）
brook mirror npm apply                    # npm registry（npmmirror）
brook mirror flatpak apply                 # Flathub 应用源（flatpak，国内缓存）
```

系统源（apt：Ubuntu/Debian 含 deb822；yum：CentOS/Rocky/Alma/Fedora）改前必备份、改后必验证、已是国内源则不动。注意区分：`brook proxies` 管 brook 自身下载加速，`sson/ssoff` 流量代理属于 shadowsocks-rust 工具。

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
CATEGORY="binary"                        # binary | language | installer（list 分组用）
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
brook config <tool>            # 列出该工具全部实践及状态
brook config <tool> <实践>      # 执行指定实践
```

实践文件约定三个函数：`config_desc`（一句话说明）、`config_run`（执行）、`config_status`（可选，状态展示）。粒度按用户视角切分——用户眼中"不同的事"就是不同的实践，一个工具可以有多个实践。例如 codex 的 `bailian` 实践（接入百炼 API：写 config.toml + 模型目录 + key 管理），以后加 openrouter/ollama 就是加文件。


## 代理

预设在 `proxies.conf`（实测见文件内注释）。两种模式：`prefix`（URL 前拼接，gh-proxy 系）与 `replace`（域名替换）。加新代理 = 加一行。
