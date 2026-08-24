# AGENTS.md —— brook 项目维护指南

## 项目定位

brook = 环境引导器（starter）：全新机器上，当没有更好的安装方式时，不用查网页，在 brook 里直接闭环。不替代包管理器：apt/brew/npm 更合适的场景用系统包管理器；brook 把 GitHub 官方二进制与超级官方应用一行命令统一装到用户级（`~/.local/bin`），覆盖常用 CLI 工具与语言工具链（rustup / sdkman / g / uv / fnm）；并提供包源管理（`brook mirror`）：系统源（apt/yum）、语言生态源（goproxy/pypi/npm）与应用源（flatpak）的国内镜像配置。支持 Linux / macOS（x86_64 / arm64），内置国内加速代理与资产兜底链。纯 bash（兼容 macOS bash 3.2），除 git/curl/tar 外零依赖。

**收录判断**：先问"目标平台上它有没有好的系统级安装方式"——有则不收（如 mpv/ffmpeg 走 brew/apt）；brook 只补"裸机无网页可查也能闭环"的位。

**收录标准（双轨，代码与数据完全独立）**：

- `tools/` 轨：只收"GitHub 仓库官方发布、有简单二进制资产"的工具，走完整流水线（install/upgrade/status/remove）。命名不规则（按 OS 版本命名、.app 包、仅源码 release）、非官方构建、需要编译的，一律不收（如 mpv、ffmpeg）。
- `official/` 轨：超级官方应用——只收官网首屏一行安装命令（URL 冻结级稳定），brook 只管装，装后由工具自身管理。准入从严：必须是 canonical 命令；有 release 二进制的优先走 tools/ 轨；清单宁短勿长。

两轨互不引用：tools/ 只由 lib/registry.sh 处理，official/ 只由 lib/official.sh 处理。

**机制分轨，功能分类，两个维度正交**：轨（目录）决定安装机制；类（conf 的 `CATEGORY` 字段）决定功能定位，只影响 `brook list` 的分组展示：

- `binary`：二进制工具（常用 CLI，默认值）
- `language`：语言工具（工具链管理器：rustup / sdkman / g / uv / fnm）
- `installer`：安装包工具（包管理器：brew）

新增条目时必须想清楚它属于哪一轨、哪一类。

## 架构

```
brook               # 入口与子命令分发（经符号链接调用时先解析真实路径）
install.sh          # 一行安装器：克隆 ~/.brook + 软链命令 + PATH
lib/core.sh         # 基础：help / list / 分发 / ask / log / os / arch / rc
lib/proxy.sh        # 代理：预设查找与 URL 改写（prefix / replace 两种模式）
lib/registry.sh     # tools/ 轨引擎：版本解析、候选链、下载、解压、安装、元数据
lib/official.sh     # official/ 轨：取官方脚本并执行（只管装；预检前置依赖、检测安装状态）
lib/mirror.sh       # 包源管理运行器（总览、适用性检测、sudo 重入、--dry-run）
proxies.conf        # 代理预设（含实测日期与速度注释）
official/<应用>.conf # 超级官方应用（官网一行命令）；同名 .usage.md 为用法文档
mirrors/<镜像>.sh    # 包源/镜像（系统源 + 语言生态源 + 应用源，brook mirror 管理）
tools/<工具>/        # 一个目录 = 一个工具的一切
├── tool.conf       # release 映射（必须）
├── config/         # 配置实践（可选）：一个文件一个具名实践
├── usage.md        # 常见用法速查（可选）
└── *.json 等        # 配置实践用到的资源（可选）
```

## 核心机制（安装链路）

1. **版本解析**：`/releases/latest` 重定向取 tag（可走代理）→ 失败回落 GitHub API；`ASSET_STRIP_V=1` 处理 tag 带 v 但资产名不带的情况
2. **候选链**：ASSET 主映射 404 → 按序尝试 ASSET_FALLBACKS 预置候选
3. **运行时枚举**：候选全 miss → 拉该 release 真实资产列表，按 TARGET 三元组过滤；唯一候选自动选用并警告，多个交互选择
4. **失败判定**：404/403 = 资产不存在（走兜底）；其他 = 网络错误（提示 --proxy）
5. **解压**：按资产后缀判定 tar.gz / tar.xz / zip / zst（裸二进制）/ raw（直接就是二进制）
6. **落地**：装到 `$BROOK_BIN_DIR`（默认 ~/.local/bin）；元数据写 `.brook-meta/<工具>`（upgrade 依据）

## 维护操作

### 新增工具

1. 用 GitHub API 查该仓库最新 release 的**完整资产列表**，确认命名格式与平台覆盖
2. 建 `tools/<名字>/tool.conf`，写实测过的映射（字段说明见 README），并定好 `CATEGORY`（binary/language/installer）
3. 可选：`config/<实践>.sh`（配置实践）、`usage.md`（用法速查）；不支持的平台可在 tool.conf 写 `NOTE_<os>="替代方案提示"`（如 macOS 引导用户走 brew）
4. 实测：隔离 HOME 跑一遍 install（见下节）

资产命名必须实测，不许猜。

### 新增配置实践

`tools/<工具>/config/<名字>.sh`，定义 `config_desc` / `config_run` / `config_status`（可选）。实践 = 脚本或配置文件的增删改，保持简单；粒度按用户视角切分（用户眼中"不同的事"就是不同的实践）。

### 新增超级官方应用

`official/<名字>.conf`：`DESC`（明示需要 sudo/自管理等差异）、`CATEGORY`（language/installer）、`SCRIPT_URL`（官网首屏那一行的脚本地址）、`BINARIES`（状态检测：PATH 上的二进制）。可选：`CHECK_FILES`（文件标志检测，用于命令是 shell 函数而非二进制的场景，如 sdkman；conf 被 source 时展开 `$HOME`）、`PREREQS`（安装前置命令，缺失时按平台给安装参考并中止）、`<名字>.usage.md`。准入标准见文首收录标准。

### 新增镜像

`mirrors/<名字>.sh`，定义 `MIRROR_PROVIDERS`（可用源说明）、`NEED_ROOT`（1=需 root）、`mirror_desc` / `mirror_detect`（输出以 inapplicable 开头 = 不适用）/ `mirror_status` / `mirror_apply`（尊重 `$DRY_RUN` 与 `$MIRROR_CHOICE`）。约定：

- 运行器自动处理：需 root 时经 sudo 重入；`--dry-run` 免 root 只预览
- 改系统文件前必备份（备份名带 .brook 标识，且只备份首次）
- 改后必须验证（如 apt update / makecache），失败给出回退指引
- 已是国内源则不动；未全量真机验证的要在文件头注明

注意三种"代理"的边界：`brook mirror` 管包源；`brook proxies` 管 brook 自身下载加速；流量代理（如 sson/ssoff）属于对应工具的配置实践，不进 mirrors/。

### 更新代理预设

`brook proxies test` 可实测各预设当前速度（代理质量动态波动，注释里的实测数据只是快照）。调整预设时改 `proxies.conf` 并注明实测日期；失效的剔除。

## 测试方法

```bash
export HOME=/tmp/brook-test-home && mkdir -p $HOME   # 隔离环境
./brook list / status / usage                          # 基础冒烟
./brook install <小工具> --proxy gh-proxy               # 真实安装实测
./brook config <工具> <实践>                            # 配置实践实测
bash -n brook lib/*.sh tools/*/config/*.sh             # 语法检查
```

## 约定

- commit message：中文，`brook: xxx` 前缀
- 兜底链触发 = 上游改名信号，事后必须更新 tool.conf 主映射
- 不引入 bash 4+ 语法（无关联数组、无 ${var,,}，占位符替换用 sed）
- 变量引用后紧跟中文/全角字符时必须写 `${var}` 花括号形式（macOS bash 3.2 会把多字节字符并入变量名，触发 unbound variable）
- 本仓库经历过两次推翻重建（向导式 → 安装器 → 按工具内聚），旧历史内容不代表当前设计
