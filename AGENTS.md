# AGENTS.md —— brook 项目维护指南

## 项目定位

brook = GitHub release 二进制安装器：把 GitHub Releases 发布的命令行工具一键装到 `~/.local/bin`（自动加入 PATH）。支持 Linux / macOS（x86_64 / arm64），内置国内加速代理与资产兜底链。纯 bash（兼容 macOS bash 3.2），除 git/curl/tar 外零依赖。

**收录标准**：只收"GitHub 仓库官方发布、有简单二进制资产"的工具。命名不规则（按 OS 版本命名、.app 包、仅源码 release）、非官方构建、需要编译的，一律不收（如 mpv、ffmpeg）。

## 架构

```
brook               # 入口与子命令分发（经符号链接调用时先解析真实路径）
install.sh          # 一行安装器：克隆 ~/.brook + 软链命令 + PATH
lib/core.sh         # 基础：help / list / 分发 / ask / log / os / arch / rc
lib/proxy.sh        # 代理：预设查找与 URL 改写（prefix / replace 两种模式）
lib/registry.sh     # 安装引擎：版本解析、候选链、下载、解压、安装、元数据
proxies.conf        # 代理预设（含实测日期与速度注释）
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
2. 建 `tools/<名字>/tool.conf`，写实测过的映射（字段说明见 README）
3. 可选：`config/<实践>.sh`（配置实践）、`usage.md`（用法速查）
4. 实测：隔离 HOME 跑一遍 install（见下节）

**红线：资产命名必须实测，不许猜。**

### 新增配置实践

`tools/<工具>/config/<名字>.sh`，定义 `config_desc` / `config_run` / `config_status`（可选）。实践 = 脚本或配置文件的增删改，保持简单；粒度按用户视角切分（用户眼中"不同的事"就是不同的实践）。

### 更新代理预设

先实测速度与可达性，改 `proxies.conf` 并注明实测日期；失效的剔除。

## 测试方法

```bash
export HOME=/tmp/brook-test-home && mkdir -p $HOME   # 隔离环境
./brook list / status / usage                          # 基础冒烟
./brook <小工具> install --proxy gh-proxy               # 真实安装实测
./brook <工具> config <实践>                            # 配置实践实测
bash -n brook lib/*.sh tools/*/config/*.sh             # 语法检查
```

## 约定与红线

- commit message：中文，`brook: xxx` 前缀
- **README 不罗列全部工具，不点名展示任何具体工具的敏感用途**；工具清单以 `brook list` 输出为准
- 兜底链触发 = 上游改名信号，事后必须更新 tool.conf 主映射
- 不引入 bash 4+ 语法（无关联数组、无 ${var,,}，占位符替换用 sed）
- 本仓库经历过两次推翻重建（向导式 → 安装器 → 按工具内聚），旧历史内容不代表当前设计
