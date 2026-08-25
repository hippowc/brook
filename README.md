# brook

一个在新机器上「不用查网页、直接闭环」的环境引导层（starter）：把 GitHub 官方发布的 CLI 工具与语言工具链，一条命令统一安装到 `~/.local/bin` 并加入 PATH。

[![CI](https://github.com/hippowc/brook/actions/workflows/test.yml/badge.svg)](https://github.com/hippowc/brook/actions/workflows/test.yml)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-blue)
![Shell](https://img.shields.io/badge/shell-Pure%20Bash%20(3.2%2B)-4EAA25)
![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey)

## 它是做什么的

brook **不是包管理器，也不替代 apt / brew / npm** —— 系统包管理器擅长的场景请继续用它们。brook 解决的是另一种场景：

> 拿到一台全新的机器，裸机环境，没有图形界面可查网页，`apt` 里没有、也不想逐个去官网翻安装命令。

这时 brook 负责「引导」：把两类东西装到用户级目录、自动接入 PATH，让你从零开始也能快速搭出顺手的环境：

- **GitHub release 二进制工具**（`tools/` 轨）—— 完整生命周期：install / upgrade / status / remove；
- **超级官方应用**（`official/` 轨）—— 官网首屏那一行命令（brew / rustup / sdkman / docker），brook 只负责装，装后由工具自身管理。

两句原则：**有好的系统级安装方式的不收**（如 mpv / ffmpeg 走 brew / apt）；**资产命名必须实测，不许猜**。

## 特性

- **用户级安装**：默认装到 `~/.local/bin`，不污染系统、无需 sudo（除官方轨中明确标注的应用）
- **零依赖**：纯 Bash（兼容 macOS Bash 3.2），除 `git` / `curl` / `tar` 外无任何运行时依赖
- **全平台覆盖**：Linux / macOS × x86_64 / arm64
- **国内可用**：内置下载加速代理与包源镜像（apt / yum / goproxy / pypi / npm / flatpak 等）
- **容错兜底**：上游突然改资产命名时自动降级 —— 主映射 → 预置候选 → 枚举真实资产列表，而不是直接报错
- **不只装，也管配置**：每个工具可附带「配置实践」，一键接入 API、shell 初始化、SSH key 等

## 目录

- [快速开始](#快速开始)
- [命令参考](#命令参考)
- [支持哪些工具](#支持哪些工具)
- [工作原理](#工作原理)
- [配置实践](#配置实践)
- [代理加速](#代理加速)
- [包源镜像](#包源镜像)
- [扩展与维护](#扩展与维护)
- [开发与测试](#开发与测试)
- [目录结构](#目录结构)
- [常见问题](#常见问题)

## 快速开始

### 环境要求

- `git`（克隆与自更新依赖）
- `curl`（下载通道）
- `tar`（解压基线）

macOS 需 Xcode Command Line Tools（自带 git，安装时脚本会提示）。可用 `brook doctor` 一键自检缺什么、怎么补。

### 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

国内网络访问 raw.githubusercontent.com 不稳定时走镜像：

```bash
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

安装器会：克隆仓库到 `~/.brook` → 软链 `brook` 到 `~/.local/bin` → 把 `~/.local/bin` 写入 shell rc。

### 上手三步

```bash
brook doctor                            # 基线自检
brook list                              # 看看能装什么、已装什么
brook install ripgrep --proxy gh-proxy  # 装一个试试
```

## 命令参考

### 子命令

| 命令 | 作用 |
| --- | --- |
| `brook list` | 列出全部条目（按 binary / language / installer 分组，含状态与配置支持） |
| `brook install <工具>...` | 安装，可一次多个；支持二进制别名（`rg` / `hx` / `nvim`） |
| `brook upgrade [工具]...` | 升级工具，可一次多个；**不带参数 = 更新 brook 自身** |
| `brook status <工具>...` | 查看安装与配置状态 |
| `brook config <工具>` | 列出该工具的配置实践及状态 |
| `brook config <工具> <实践>` | 执行指定配置实践 |
| `brook usage <工具>` | 查看常见用法速查 |
| `brook remove <工具>...` | 移除 |
| `brook proxies` / `brook proxies test` | 查看加速代理预设 / 实测各预设当前速度 |
| `brook mirror` | 包源/镜像管理总览 |
| `brook doctor` | 基线自检（下载 / 解压 / 安装目录 / 网络） |
| `brook --version` | 显示版本 |

### install 选项

| 选项 | 说明 |
| --- | --- |
| `--version V` | 指定版本（默认 latest） |
| `--proxy P` | 走代理：预设名（`gh-proxy` / `ghfast`）或直接给 URL 前缀 |
| `--force` | 强制重装 |

### 环境变量

| 变量 | 说明 |
| --- | --- |
| `BROOK_PROXY` | 全局默认代理（等价于给每次 install 加 `--proxy`） |
| `BROOK_BIN_DIR` | 安装目录，默认 `~/.local/bin` |

## 支持哪些工具

brook 的条目有**两条轨、三种类**，两个维度正交：

- **轨**决定安装机制：`tools/`（GitHub release 二进制）与 `official/`（官网一行命令）互不引用；
- **类**决定功能定位，只影响 `brook list` 的分组：`binary`（常用 CLI）、`language`（语言工具链）、`installer`（包管理器）。

实际支持清单以 `brook list` 输出为准，下文为当前收录情况。

### tools/ 轨 —— GitHub release 二进制

| 工具 | 说明 | 类 |
| --- | --- | --- |
| `bat` | 现代 cat：语法高亮 + 行号 + Git 标记 | binary |
| `codex` | OpenAI 开源终端编码 agent | binary |
| `eza` | 现代 ls：图标 / Git 状态 / 树形（仅 Linux） | binary |
| `fd` | 现代 find：按正则快速找文件 | binary |
| `fzf` | 模糊搜索（Ctrl-R / Ctrl-T） | binary |
| `git` | 版本控制（系统自带，brook 只管配置） | binary |
| `gocryptfs` | 加密目录挂载（仅 Linux） | binary |
| `helix` | 后现代终端编辑器（`hx`） | binary |
| `jq` | 命令行 JSON 处理器 | binary |
| `neovim` | Vim 的现代演进（`nvim`） | binary |
| `ripgrep` | 极速文本搜索（`rg`） | binary |
| `shadowsocks-rust` | 高性能 SOCKS5 代理（`ssserver` / `sslocal`） | binary |
| `yt-dlp` | 通用视频下载器 | binary |
| `zoxide` | 智能 cd（`z`） | binary |
| `fnm` | Node 版本管理器 | language |
| `g` | Go 版本管理器 | language |
| `uv` | Python 管理器（装 python / venv / 包） | language |

### official/ 轨 —— 超级官方应用

| 应用 | 说明 | 类 | 备注 |
| --- | --- | --- | --- |
| `brew` | Homebrew 包管理器 | installer | 需 sudo，装后由 brew 自身管理 |
| `docker` | 容器引擎 | installer | 内置国内仓库直装，需 root；macOS 用 Docker Desktop |
| `rustup` | Rust 工具链安装器 | language | 装后由 rustup 自身管理 |
| `sdkman` | Java 工具链管理器 | language | `sdk` 是 shell 函数，装后需开新终端或 source init 脚本 |

平台差异以各 `tool.conf` 的 `NOTE_*` 为准，例如 eza / gocryptfs 官方不给 macOS 二进制（提示走 brew）、fnm 上游无 Linux arm64 资产。

## 工作原理

`tools/` 轨的安装链路如下：

```
版本解析 ──► 资产候选 ──► 下载 ──► 校验(可选) ──► 解压 ──► 落地 ──► 元数据
   │            │                      │
latest 重定向  主映射 ASSET         tar.gz / tar.xz
   │          ├─ 失败 → ASSET_FALLBACKS   / zip / zst / raw
GitHub API    └─ 全 miss → 枚举该 release 的真实资产列表(按平台
  回落                        三元组过滤，唯一候选自动选用)
```

拆开看：

1. **版本解析**：优先走 `/releases/latest` 重定向取 tag（可走代理），失败回落到 GitHub API
2. **候选链**：先试 `ASSET` 主映射；404/403 视为「资产不存在」，按序尝试 `ASSET_FALLBACKS`；全部 miss 则拉取真实资产列表按 TARGET 枚举，唯一候选自动选用、多个交互选择
3. **失败判定**：404/403 = 资产不存在（继续兜底）；其他错误 = 网络问题（提示加 `--proxy`）
4. **解压**：按资产后缀判定 `tar.gz` / `tar.xz` / `zip` / `zst`（裸二进制）/ `raw`（直接就是二进制）
5. **落地**：装到 `$BROOK_BIN_DIR`（默认 `~/.local/bin`），元数据写到 `.brook-meta/<工具>`，供 `upgrade` 使用

## 配置实践

除了安装，brook 还能帮工具完成「装好之后那点配置」。每个工具可提供一组**具名配置实践**，本质是脚本或配置文件的增删改：

```bash
brook config codex            # 列出 codex 的全部实践
brook config codex bailian    # 接入百炼 API：写 config.toml + 模型目录 + key 管理
brook config git github-ssh   # 生成/配置 GitHub SSH key
brook config fnm shell-init   # 写入 shell 初始化
```

当前实践一览：`codex/bailian`、`git/github-ssh`、`fnm/shell-init`、`g/shell-init`、`shadowsocks-rust/client|server|switch`。装完如果 `brook list` 里状态带 `配置:有`，记得补一句 `brook config <工具>`。

## 代理加速

brook 在下载 GitHub 资产时支持代理，国内网络强烈建议启用：

```bash
brook install codex --proxy gh-proxy   # 单次使用
export BROOK_PROXY=gh-proxy            # 全局生效
brook proxies                          # 查看预设与实测速度
brook proxies test                     # 实测各预设当前速度
```

预设在 `proxies.conf`，两种模式：

| 模式 | 行为 | 典型预设 |
| --- | --- | --- |
| `prefix` | 在完整 URL 前拼接代理前缀 | gh-proxy / ghfast |
| `replace` | 替换域名 | 自定义 |

## 包源镜像

引导一台机器不只是装工具——系统包管理器与语言生态的源往往也需要国内镜像。`brook mirror` 统一管理（系统源需 root，自动 sudo 提权）：

```bash
brook mirror                              # 总览：适用性 / 当前状态 / 可用源
brook mirror apt apply --dry-run          # 预览会改什么（不动手）
brook mirror apt apply                    # 应用（默认源）
brook mirror apt apply --mirror tsinghua  # 选源
brook mirror goproxy apply                # Go 模块代理（goproxy.cn）
brook mirror pypi apply                   # PyPI（uv 的 UV_DEFAULT_INDEX）
brook mirror npm apply                    # npm registry（npmmirror）
brook mirror flatpak apply                # Flathub（国内缓存）
```

| 镜像 | 说明 | 可用源（* 为默认） | 需 root |
| --- | --- | --- | --- |
| `apt` | apt 源（Ubuntu/Debian，含 deb822） | aliyun* / tsinghua / ustc | ✓ |
| `yum` | yum/dnf 源（CentOS/Rocky/Alma/Fedora） | aliyun* / tsinghua | ✓ |
| `goproxy` | Go 模块代理 | goproxy.cn（固定） | — |
| `pypi` | PyPI 源 | tsinghua* / aliyun / ustc | — |
| `npm` | npm registry | npmmirror（固定） | — |
| `crates` | Rust 包源 | rsproxy* / ustc / tuna | — |
| `maven` | Maven 中央仓 | aliyun* / tencent / huawei | — |
| `homebrew` | Homebrew 源 | tuna* / ustc / aliyun | — |
| `flatpak` | Flathub 应用源 | sjtug* / ustc / official | — |
| `docker` | Docker Hub 镜像源 | daocloud* / 1ms / 1panel | ✓ |

约定：改系统文件前必备份（备份名带 `.brook` 标识，且只备份首次）、改后必验证（如 `apt update` / `makecache`）、已是国内源则不动；未全量真机验证的会在文件头注明（如 yum）。

三种「代理」请分清边界：

- `brook mirror` —— 管理**包源**
- `brook proxies` —— 加速 **brook 自身**的下载
- `sson / ssoff` —— **流量代理**，属于 shadowsocks-rust 工具的配置实践

## 扩展与维护

想新增条目、配置实践或镜像，**请先读 [AGENTS.md](AGENTS.md)**。简要规则：

- **新增工具**：GitHub API 查最新 release 的完整资产列表 → 建 `tools/<名字>/tool.conf` 并实测映射 → 定好 `CATEGORY`；可选 `config/`（配置实践）、`usage.md`；不支持的平台写 `NOTE_<os>`
- **新增配置实践**：`tools/<工具>/config/<名字>.sh`，定义 `config_desc` / `config_run` / `config_status`
- **新增超级官方应用**：`official/<名字>.conf`，填 `DESC` / `CATEGORY` / `SCRIPT_URL` / `BINARIES`（或文件标志 `CHECK_FILES`）
- **新增镜像**：`mirrors/<名字>.sh`，定义 `mirror_detect` / `mirror_status` / `mirror_apply` 等

两条硬约束：**资产命名必须实测，不许猜**；**收录先问「目标平台上有没有好的系统级安装方式」**，有就不收。

## 开发与测试

```bash
# 语法检查
bash -n brook lib/*.sh tools/*/config/*.sh

# 分层测试（L0 单测 + L1 假环境流程 + L2 schema 校验）
bash tests/run_tests.sh

# 隔离 HOME 的真实安装实测
export HOME=/tmp/brook-test-home && mkdir -p "$HOME"
./brook install <小工具> --proxy gh-proxy
```

CI 在 ubuntu-latest 与 macos-latest 双平台跑单测（macOS 自带 Bash 3.2，顺带做兼容性验证），并在 ubuntu 上做一次真实网络安装冒烟。

## 目录结构

```
brook               # 入口与子命令分发（符号链接调用时先解析真实路径）
install.sh          # 一行安装器：克隆 + 软链 + PATH
lib/core.sh         # 基础：help / list / doctor / 分发 / os / arch / rc
lib/proxy.sh        # 代理：预设查找与 URL 改写
lib/registry.sh     # tools/ 轨引擎：版本解析、候选链、下载、解压、安装、元数据
lib/official.sh     # official/ 轨：官方脚本/内置安装（只管装，预检前置依赖）
lib/mirror.sh       # 包源管理运行器
proxies.conf        # 代理预设
official/*.conf     # 超级官方应用；同名 .usage.md 为用法文档
mirrors/*.sh        # 包源/镜像（brook mirror 管理）
tools/<工具>/       # 一个目录 = 一个工具的一切
├── tool.conf       # release 映射（必须）
├── config/         # 配置实践（可选）
└── usage.md        # 常见用法速查（可选）
```

## 常见问题

**和 apt / brew / npm 是什么关系？**
不替代。brook 是引导层：系统包管理器能装的（如 mpv / ffmpeg）、需要编译的、资产命名不规则的，都不收。brook 只补「裸机无网页可查也能闭环」的位。

**为什么有的工具 `brook list` 里显示「系统自带」？**
这些是外部工具（如 git）：检测到 PATH 上已有即视为可用，brook 不代装，只提供配置实践。

**国内网络下载失败？**
先 `brook doctor` 确认 curl / git 可用，再给 install 加 `--proxy gh-proxy`，或 `export BROOK_PROXY=gh-proxy`。`brook proxies test` 可实测当前最快的预设。

**怎么更新 brook 自己？**
`brook upgrade`（不带工具名）。也可以重新跑一次 install.sh。

**想换安装目录？**
设 `BROOK_BIN_DIR`（默认 `~/.local/bin`）。注意确保它在 PATH 里。

**装完 `sdk` 命令找不到？**
sdkman 的 `sdk` 是 shell 函数，不在 PATH 上：开新终端，或 `source ~/.sdkman/bin/sdkman-init.sh`。

---

维护与扩展本项目请先阅读 [AGENTS.md](AGENTS.md)。
