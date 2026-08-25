# brook

新机器的引导脚手架（starter）：一条命令，把新系统需要的**源**、**基础工具**和**常用配置**都办好。

brook **不替代** apt / brew / npm —— 系统包管理器擅长的场景用它。brook 补的是「新机器到手 → 配源 → 装基础工具 → 做好常用配置」这段引导流程：

- **安装**：GitHub 官方发布的 CLI 工具，装到用户级 `~/.local/bin`，自动进 PATH
- **配置**：装好之后的初始化（SSH key / API key / shell 初始化），同样一条命令搞定
- **源**：新系统第一步 —— 系统源与语言生态源的国内镜像统一维护（`brook mirror`）

## 特点

- **简洁**：纯 Bash，除 git / curl / tar 外零依赖，不引入新运行时
- **干净**：只写 `~/.local/bin`，不碰系统目录，默认无需 sudo
- **即装即配**：安装与配置一体化，`brook config` 一条命令完成常用初始化
- **按需收录**：有好的系统级安装方式的不收（如 mpv / ffmpeg 走 brew / apt）

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

国内网络访问 GitHub 不稳时走镜像：

```bash
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/hippowc/brook/main/install.sh | bash
```

装完重新登录（bash 用户 `source ~/.bashrc`，zsh 用户 `source ~/.zshrc`），先自检一下：

```bash
brook doctor    # 看看环境还缺什么、怎么补
```

## 使用

新机器到手，常见流程是「配源 → 装工具 → 做配置」：

```bash
# ① 配源（国内机器第一步）
brook mirror                      # 总览：哪些源可用、当前状态
brook mirror apt apply --dry-run  # 预览会改什么（不动手）
brook mirror apt apply            # 应用系统源（自动 sudo，改前备份、改后验证）
brook mirror goproxy apply        # 语言生态源示例：Go 模块代理

# ② 装基础工具（可一次多个）
brook install git ripgrep fzf fd bat jq

# ③ 配置（和安装同样重要）
brook config git github-ssh       # GitHub SSH key
brook config fnm shell-init       # shell 初始化
brook config codex bailian        # 接入 API：写 config + 模型目录 + key
```

`brook mirror` 覆盖系统源（apt / yum）、语言生态源（goproxy / pypi / npm 等）与应用源（flatpak 等），约定改前备份、改后验证、已是国内源则不动。

日常使用：

```bash
brook list                        # 能装什么、现在什么状态
brook usage rg                    # 某个工具的常见用法速查
brook status codex                # 查看状态
brook upgrade                     # 更新 brook 自身
brook remove codex                # 移除
```

国内下载 GitHub 资产慢时，加 `--proxy`（或 `export BROOK_PROXY=gh-proxy` 全局启用）：

```bash
brook install codex --proxy gh-proxy
brook proxies test                # 实测各下载加速预设当前速度
```

## 能装什么

brook 分两条轨、三类，具体清单以 `brook list` 为准。示例：

| 类型 | 例子 |
| --- | --- |
| 常用 CLI（GitHub release 二进制） | ripgrep、fd、bat、fzf、eza、jq、zoxide、neovim、codex、yt-dlp… |
| 语言工具链 | fnm（Node）、g（Go）、uv（Python）、rustup、sdkman |
| 超级官方应用 | brew、docker（官网一行命令，brook 只管装） |

不支持的平台会在条目里给出替代提示（如 eza 在 macOS 走 `brew install eza`）。

## 维护

新增工具、配置实践或镜像，请先读 [AGENTS.md](AGENTS.md)。
