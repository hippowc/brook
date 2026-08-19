# brook

agent 环境配置器：**agent 的安装与配置**、模型后端切换、常用初始化任务。支持 Linux 和 macOS。

## 安装（全新机器，一行）

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/install.sh -o /tmp/brook-install.sh && bash /tmp/brook-install.sh
```

克隆框架到 `~/.brook` 后进入**交互式初始化向导**：菜单驱动，先显示当前缺什么，逐步选择执行，每一步可定制（版本、下载源等）。已装过？随时运行 `~/.brook/bootstrap.sh` 重新进入向导。

## 进阶用法（跳过向导）

```bash
~/.brook/bootstrap.sh --list                     # 查看可用条目
~/.brook/bootstrap.sh codex git-key              # 直接执行指定条目
CODEX_VERSION=rust-v0.148.0 ~/.brook/bootstrap.sh codex   # pin 版本
CODEX_ASSET_URL=https://... ~/.brook/bootstrap.sh codex   # 换下载源（国内加速）
```

## 可用条目

| 条目 | 类型 | 作用 |
|---|---|---|
| codex | agent | 安装并配置 codex（OpenAI 开源终端 agent） |
| git-key | task | 初始化 git 身份 + SSH 密钥 |
| shadowsocks | task | 安装 shadowsocks-rust 并交互式生成配置 |

## 扩展

- **新增 agent**：复制 `bootstrap/adapters/_template.sh` 为 `adapters/<名字>.sh`，实现 install/configure/verify 三件套（可选加 _desc/_status/_options 获得向导展示与定制能力），核心代码零改动。
- **新增初始化功能**：复制 `bootstrap/tasks/_template.sh` 为 `tasks/<名字>.sh`，实现 `<名字>_run`（幂等、可交互、机密只写 $HOME）。
- **新增模型后端**：在 `bootstrap/providers/` 增加一个 `.env`（OpenAI 兼容端点是最大公约数）。
